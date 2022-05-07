import 'package:rope/src/interval.dart';

import 'tree.dart';

abstract class DeltaElement<L extends Leaf<L>, N extends NodeInfo<L, N>> {}

/// Represents a range of text in the base document. Includes beginning, excludes end.
// note: for now, we lose open/closed info at interval endpoints
class Copy<L extends Leaf<L>, N extends NodeInfo<L, N>>
    extends DeltaElement<L, N> {
  final int begin;
  final int end;

  Copy(this.begin, this.end);
}

class Insert<L extends Leaf<L>, N extends NodeInfo<L, N>>
    extends DeltaElement<L, N> {
  final Node<L, N> node;

  Insert(this.node);
}

class Builder<L extends Leaf<L>, N extends NodeInfo<L, N>> {
  Delta<L, N> delta;
  int lastOffset;

  Builder(int baseLen)
      : delta = Delta(els: [], baseLen: baseLen),
        lastOffset = 0;

  /// Deletes the given interval. Panics if interval is not properly sorted.
  void delete(IntervalBounds interval) {
    var newInterval = interval.intoInterval(delta.baseLen);
    var start = newInterval.start;
    var end = newInterval.end;
    assert(start >= lastOffset, "Delta builder: intervals not properly sorted");
    if (start > lastOffset) {
      delta.els.add(Copy(lastOffset, start));
    }
    lastOffset = end;
  }

  void replace(IntervalBounds interval, Node<L,N> rope) {
    delete(interval);
    if (!rope.isEmpty()) {
      delta.els.add(Insert(rope));
    }
  }

  Delta<L,N> build() {
    if (lastOffset < delta.baseLen) {
      delta.els.add(Copy(lastOffset, delta.baseLen));
    }
    return delta;
  }
}

/// Represents changes to a document by describing the new document as a
/// sequence of sections copied from the old document and of new inserted
/// text. Deletions are represented by gaps in the ranges copied from the old
/// document.
///
/// For example, Editing "abcd" into "acde" could be represented as:
/// `[Copy(0,1),Copy(2,4),Insert("e")]`
class Delta<L extends Leaf<L>, N extends NodeInfo<L, N>> {
  List<DeltaElement<L, N>> els;
  int baseLen;

  Delta({required this.els, required this.baseLen});

  static Delta<L, N> simpleEdit<L extends Leaf<L>, N extends NodeInfo<L, N>>(
      IntervalBounds interval, Node<L, N> rope, int baseLen) {
    var builder = Builder<L,N>(baseLen);
    if (rope.isEmpty()) {
      builder.delete(interval);
    } else {
      builder.replace(interval, rope);
    }
    return builder.build();
  }

  @override
  String toString() {
    return '''
      els: $els,
      baseLen: $baseLen,
    ''';
  }
}

class Transformer<L extends Leaf<L>, N extends NodeInfo<L, N>> {
  final Delta<L, N> delta;

  /// Create a new transformer from a delta.
  Transformer(Delta<L,N> this.delta);

  /// Transform a single coordinate. The `after` parameter indicates whether it
  /// it should land before or after an inserted region.
  int transform(int ix, bool after) {
    if (ix == 0 && !after) {
      return 0;
    }

    var result = 0;
    for (var el in delta.els) {
      if (el is Copy<L,N>) {
        if (ix <= el.begin) {
          return result;
        }

        if (ix < el.end || (ix == el.end && !after)) {
          return result + ix - el.begin;
        }

        result += el.end - el.begin;
      } else if (el is Insert<L,N>) {
        result += el.node.len();
      }
    }

    return result;
  }
}
