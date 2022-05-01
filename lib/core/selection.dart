import 'dart:math' as math;

import 'package:rope/rope.dart';

import 'index_set.dart';
import 'util.dart';

/// A type representing horizontal measurements. This is currently in units
/// that are not very well defined except that ASCII characters count as
/// 1 each. It will change.
typedef HorizPos = int;

/// The "affinity" of a cursor which is sitting exactly on a line break.
///
/// We say "cursor" here rather than "caret" because (depending on presentation)
/// the front-end may draw a cursor even when the region is not a caret.
enum Affinity {
  /// The cursor should be displayed downstream of the line break. For
  /// example, if the buffer is "abcd", and the cursor is on a line break
  /// after "ab", it should be displayed on the second line before "cd".
  downstream,

  /// The cursor should be displayed upstream of the line break. For
  /// example, if the buffer is "abcd", and the cursor is on a line break
  /// after "ab", it should be displayed on the previous line after "ab".
  upstream,
}

/// A type representing a single contiguous region of a selection. We use the
/// term "caret" (sometimes also "cursor", more loosely) to refer to a selection
/// region with an empty interior. A "non-caret region" is one with a non-empty
/// interior (i.e. `start != end`).
class SelRegion with Clone<SelRegion> {
  /// The inactive edge of a selection, as a byte offset. When
  /// equal to end, the selection range acts as a caret.
  int start;

  /// The active edge of a selection, as a byte offset.
  int end;

  /// A saved horizontal position (used primarily for line up/down movement).
  HorizPos? horiz;

  /// The affinity of the cursor.
  Affinity affinity;

  SelRegion(this.start, this.end) : affinity = Affinity.downstream;

  /// Returns a new caret region (`start == end`).
  SelRegion.caret(int pos)
      : start = pos,
        end = pos,
        affinity = Affinity.downstream;

  /// Gets the earliest offset within the region, ie the minimum of both edges.
  int min() {
    return math.min(start, end);
  }

  /// Gets the latest offset within the region, ie the maximum of both edges.
  int max() {
    return math.max(start, end);
  }

  /// Determines whether the region's affinity is upstream.
  bool isUpstream() {
    return affinity == Affinity.upstream;
  }

  // Indicate whether this region should merge with the next.
  // Assumption: regions are sorted (self.min() <= other.min())
  bool shouldMerge(SelRegion other) {
    return other.min() < max() ||
        ((isCaret() || other.isCaret()) && other.min() == max());
  }

  /// Determines whether the region is a caret (ie has an empty interior).
  bool isCaret() {
    return start == end;
  }

  // Merge self with an overlapping region.
  // Retains direction of self.
  SelRegion mergeWith(SelRegion other) {
    var isForward = this.end >= this.start;
    var newMin = math.min(min(), other.min());
    var newMax = math.max(max(), other.max());
    int start, end;

    if (isForward) {
      start = newMin;
      end = newMax;
    } else {
      start = newMax;
      end = newMin;
    }

    // Could try to preserve horiz/affinity from one of the
    // sources, but very likely not worth it.
    return SelRegion(start, end);
  }

  @override
  SelRegion clone() {
    return SelRegion(start, end)
      ..horiz = horiz
      ..affinity = affinity;
  }

  @override
  String toString() => '''
    start: $start,
    end: $end,
    horiz: $horiz,
    affinity: $affinity,
    ''';
}

/// A set of zero or more selection regions, representing a selection state.
class Selection {
  // An invariant: regions[i].max() <= regions[i+1].min()
  // and < if either is_caret()
  List<SelRegion> regions;

  /// Creates a new empty selection.
  Selection() : regions = [];

  /// Creates a selection with a single region.
  Selection.simple(SelRegion region) : regions = [region];

  /// Gets a slice of regions that intersect the given range. Regions that
  /// merely touch the range at the edges are also included, so it is the
  /// caller's responsibility to further trim them, in particular to only
  /// display one caret in the upstream/downstream cases.
  ///
  /// Performance note: O(log n).
  List<SelRegion> regionsInRange(int start, int end) {
    final int first = search(start);
    var last = search(end);
    if (last < regions.length && regions[last].min() <= end) {
      last += 1;
    }

    return regions.sublist(first, last);
  }

  // The smallest index so that offset > region.max() for all preceding
  // regions.
  int search(int offset) {
    if (regions.isEmpty || offset > regions.last.max()) {
      return regions.length;
    }

    return binarySearchBy(regions, (SelRegion r) => r.max().compareTo(offset));
  }

  Selection applyDelta(RopeDelta delta, bool after) {
    var result = Selection();
    var transformer = Transformer(delta);
    for (var region in regions) {
      var newRegion = SelRegion(transformer.transform(region.start, true),
          transformer.transform(region.end, true))
        ..affinity = region.affinity;

      result.addRegion(newRegion);
    }

    return result;
  }

  /// Add a region to the selection. This method implements merging logic.
  ///
  /// Two non-caret regions merge if their interiors intersect; merely
  /// touching at the edges does not cause a merge. A caret merges with
  /// a non-caret if it is in the interior or on either edge. Two carets
  /// merge if they are the same offset.
  ///
  /// Performance note: should be O(1) if the new region strictly comes
  /// after all the others in the selection, otherwise O(n).
  void addRegion(SelRegion region) {
    var ix = search(region.min());
    if (ix == regions.length) {
      regions.add(region);
      return;
    }

    var endIx = ix;

    if (regions[ix].min() <= region.min()) {
      if (regions[ix].shouldMerge(region)) {
        region = region.mergeWith(regions[ix]);
      } else {
        ix += 1;
      }

      endIx += 1;
    }

    while (endIx < regions.length && region.shouldMerge(regions[endIx])) {
      region = region.mergeWith(regions[endIx]);
      endIx += 1;
    }

    if (ix == endIx) {
      regions.insert(ix, region);
    } else {
      regions[ix] = region;
      removeNAt(regions, ix + 1, endIx - ix - 1);
    }
  }

  @override
  String toString() {
    return "regions: $regions";
  }
}
