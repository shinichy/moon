import 'dart:math';

import 'delta.dart';
import 'interval.dart';

import 'tree.dart';

typedef RopeNode = Node<StringLeaf, RopeInfo>;

typedef RopeDelta = Delta<StringLeaf, RopeInfo>;

class Rope extends Node<StringLeaf, RopeInfo> {
  Rope({required NodeBody<StringLeaf, RopeInfo> body}) : super(body: body);

  static RopeNode from(String s) {
    var b = RopeTreeBuilder();
    b.pushStr(s);
    return b.build(fromLeaf, RopeInfo.computeInfo);
  }

  static String to(RopeNode r) {
    return r.sliceToCow(RangeFull());
  }

  static RopeNode fromLeaf() {
    return Node.fromLeaf("".toLeaf(), RopeInfo.computeInfo);
  }

  /// Return the line number corresponding to the byte index `offset`.
  ///
  /// The line number is 0-based, thus this is equivalent to the count of newlines
  /// in the slice up to `offset`.
  ///
  /// Time complexity: O(log n)
  ///
  /// # Panics
  ///
  /// This function will panic if `offset > self.len()`. Callers are expected to
  /// validate their input.
  static int lineOfOffset(RopeNode rope, int offset) {
    return rope.count(offset, BaseMetric.canFragment, BaseMetric.measure,
        LinesMetric.measure, BaseMetric.toBaseUnits, LinesMetric.fromBaseUnits);
  }
}

class Chunks extends Iterable<String?> {
  final Cursor<StringLeaf, RopeInfo> cursor;
  final int end;

  Chunks({required this.cursor, required this.end});

  @override
  Iterator<String?> get iterator => ChunkIter(cursor: cursor, end: end);
}

class ChunkIter extends Iterator<String?> {
  final Cursor<StringLeaf, RopeInfo> cursor;
  final int end;
  String? _current;

  ChunkIter({required this.cursor, required this.end});

  @override
  String? get current {
    return _current;
  }

  @override
  bool moveNext() {
    if (cursor.pos() >= end) {
      _current = null;
      return false;
    }
    var t = cursor.getLeaf()!;
    var leaf = t.item1;
    var startPos = t.item2;
    var len = min(end - cursor.pos(), leaf.len() - startPos);
    cursor.nextLeaf();
    _current = leaf.toString().substring(startPos, startPos + len);
    return true;
  }
}

extension RopeNodeExtension on RopeNode {
  String sliceToCow<T extends IntervalBounds>(T range) {
    var iter = iterChunks(range);
    iter.moveNext();
    var first = iter.current;
    iter.moveNext();
    var second = iter.current;

    if (first == null && second == null) {
      return "";
    } else if (first != null && second == null) {
      return first;
    } else if (first != null && second != null) {
      final sb = StringBuffer([first, second]);
      while (iter.moveNext()) {
        var chunk = iter.current;
        sb.write(chunk);
      }
      return sb.toString();
    } else {
      throw Exception("unreachable!");
    }
  }

  ChunkIter iterChunks<T extends IntervalBounds>(T range) {
    var interval = range.intoInterval(len());
    var cursor = Cursor(root: this, position: interval.start);
    return ChunkIter(cursor: cursor, end: interval.end);
  }

  Chunks chunks(IntervalBounds range) {
    var interval = range.intoInterval(len());
    var cursor = Cursor(root: this, position: interval.start);
    return Chunks(cursor: cursor, end: interval.end);
  }

  /// Return the offset of the codepoint before `offset`.
  int? prevCodepointOffset(int offset) {
    var cursor = Cursor(root: this, position: offset);
    return cursor.prev(BaseMetric.isBoundary ,BaseMetric.prev, BaseMetric.measure);
  }

  /// Return the offset of the codepoint after `offset`.
  int? nextCodepointOffset(int offset) {
    var cursor = Cursor(root: this, position: offset);
    return cursor.next(BaseMetric.next, BaseMetric.measure);
  }
}

class RopeInfo extends NodeInfo<StringLeaf, RopeInfo> {
  int lines;
  int utf16Size;

  RopeInfo({
    required this.lines,
    required this.utf16Size,
  });

  @override
  void accumulate(RopeInfo other) {
    lines += other.lines;
    utf16Size += other.utf16Size;
  }

  static RopeInfo computeInfo(StringLeaf self) {
    return RopeInfo(
        lines: countNewlines(self.toString()), utf16Size: self.length);
  }

  static RopeInfo identity() {
    return RopeInfo(lines: 0, utf16Size: 0);
  }

  static int countNewlines(String s) {
    return '\n'.allMatches(s).length;
  }

  @override
  RopeInfo clone() {
    return RopeInfo(lines: lines, utf16Size: utf16Size);
  }
}

const int minLeaf = 511;
const int maxLeaf = 1024;

class RopeTreeBuilder extends TreeBuilder<StringLeaf, RopeInfo> {
  String? pushStr(String s) {
    if (s.length <= maxLeaf) {
      if (s.isNotEmpty) {
        pushLeaf(s.toLeaf(), RopeInfo.computeInfo);
      }
      return null;
    }
    while (s.isNotEmpty) {
      var splitpoint = s.length > maxLeaf ? findLeafSplitForBulk(s) : s.length;
      pushLeaf(s.substring(0, splitpoint).toLeaf(), RopeInfo.computeInfo);
      s = s.substring(splitpoint);
    }

    return s;
  }
}

int findLeafSplitForBulk(String s) {
  return findLeafSplit(s, minLeaf);
}

int findLeafSplitForMerge(String s) {
  return findLeafSplit(s, max(minLeaf, s.length - maxLeaf));
}

int findLeafSplit(String s, int minsplit) {
  var splitpoint = min(maxLeaf, s.length - minLeaf);
  // use memrchr to improve performance?
  var pos = s.substring(minsplit - 1, splitpoint).lastIndexOf('\n');
  if (0 <= pos) {
    return minsplit + pos;
  } else {
    while (!s.isCharBoundary(splitpoint)) {
      splitpoint -= 1;
    }
    return splitpoint;
  }
}

class StringLeaf extends Leaf<StringLeaf> {
  StringBuffer _sb;

  StringLeaf(String s) : _sb = StringBuffer(s);

  @override
  int len() {
    return _sb.length;
  }

  @override
  bool isOkChild() {
    return len() >= minLeaf;
  }

  @override
  StringLeaf? pushMaybeSplit(StringLeaf other, Interval iv) {
    var t = iv.startEnd();
    var start = t.item1;
    var end = t.item2;
    _sb.write(other.toString().substring(start, end));
    if (len() <= maxLeaf) {
      return null;
    } else {
      var str = _sb.toString();
      var splitpoint = findLeafSplitForMerge(str);
      var rightStr = str.substring(splitpoint);
      _sb = StringBuffer(str.substring(0, splitpoint));
      return rightStr.toLeaf();
    }
  }

  @override
  StringLeaf clone() {
    return StringLeaf(_sb.toString());
  }

  @override
  StringLeaf defaultValue() {
    return StringLeaf("");
  }

  String toString() {
    return _sb.toString();
  }

  int get length => _sb.length;
}

extension StringLeafConversion on String {
  StringLeaf toLeaf() {
    return StringLeaf(this);
  }

  // From Rust's is_char_boundary
  bool isCharBoundary(int index) {
    if (index == 0) {
      return true;
    }

    if (index == length) {
      return true;
    } else if (length < index) {
      return false;
    } else {
      return codeUnitAt(index) >= -0x40;
    }
  }
}

extension RopeNodeConversion on RopeNode {
  String toStr() {
    return sliceToCow(RangeFull());
  }
}

class LinesMetric {
  int numLines;

  LinesMetric(this.numLines);

  static int measure(RopeInfo info, int len) {
    return info.lines;
  }

  static int? prev(StringLeaf l, int offset) {
    assert(offset > 0, "caller is responsible for validating input");
    var pos = l.toString().substring(0, offset - 1).indexOf('\n');
    return pos + 1;
  }

  static int? next(StringLeaf s, int offset) {
    var pos = s.toString().indexOf('\n', offset);
    return offset + pos + 1;
  }

  static bool canFragment() {
    return true;
  }

  static bool isBoundary(StringLeaf l, int offset) {
    if (offset == 0) {
      // shouldn't be called with this, but be defensive
      return false;
    } else {
      return l.toString()[offset - 1] == '\n';
    }
  }

  static int toBaseUnits(StringLeaf l, int inMeasuredUnits) {
    var offset = 0;
    var s = l.toString();
    for (var i in Iterable<int>.generate(inMeasuredUnits)) {
      var pos = s.indexOf('\n', offset);
      if (0 <= pos) {
        offset += pos + 1;
      } else {
        throw Exception("to_base_units called with arg too large");
      }
    }

    return offset;
  }

  static int fromBaseUnits(StringLeaf l, int inBaseUnits) {
    return RopeInfo.countNewlines(l.toString().substring(0, inBaseUnits));
  }
}

/// This metric let us walk utf8 text by code point.
///
/// `BaseMetric` implements the trait [Metric].  Both its _measured unit_ and
/// its _base unit_ are utf8 code unit.
///
/// Offsets that do not correspond to codepoint boundaries are _invalid_, and
/// calling functions that assume valid offsets with invalid offets will panic
/// in debug mode.
///
/// Boundary is atomic and determined by codepoint boundary.  Atomicity is
/// implicit, because offsets between two utf8 code units that form a code
/// point is considered invalid. For example, if a string starts with a
/// 0xC2 byte, then `offset=1` is invalid.
class BaseMetric {
  static int measure(RopeInfo info, int len) {
    return len;
  }

  static int toBaseUnits(StringLeaf l, int inMeasuredUnits) {
    assert(l.toString().isCharBoundary(inMeasuredUnits));
    return inMeasuredUnits;
  }

  static int fromBaseUnits(StringLeaf l, int inBaseUnits) {
    assert(l.toString().isCharBoundary(inBaseUnits));
    return inBaseUnits;
  }

  static bool isBoundary(StringLeaf l, int offset) {
    return l.toString().isCharBoundary(offset);
  }

  static int? prev(StringLeaf l, int offset) {
    if (offset == 0) {
      // I think it's a precondition that this will never be called
      // with offset == 0, but be defensive.
      return null;
    } else {
      var len = 1;
      var s = l.toString();
      while (!s.isCharBoundary(offset - len)) {
        len += 1;
      }
      return offset - len;
    }
  }

  static int? next(StringLeaf l, int offset) {
    var s = l.toString();
    if (offset == s.length) {
      // I think it's a precondition that this will never be called
      // with offset == s.len(), but be defensive.
      return null;
    } else {
      var b = s[offset];
      return offset + b.length;
    }
  }

  static bool canFragment() {
    return false;
  }
}
