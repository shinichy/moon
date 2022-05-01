import 'dart:math';

import 'package:tuple/tuple.dart';

import 'interval.dart';

const int minChildren = 4;
const int maxChildren = 8;

class Node<L extends Leaf<L>, N extends NodeInfo<L, N>> with Clone<Node<L, N>> {
  final NodeBody<L, N> body;

  Node({required this.body});

  int count(int offset,
      bool Function() canFragmentFn1,
      int Function(N, int) measureFn1,
      int Function(N, int) measureFn2,
      int Function(L, int) toBaseUnitsFn1,
      int Function(L, int) fromBaseUnitsFn2) {
    return convertMetrics(
        offset, canFragmentFn1, measureFn1, measureFn2, toBaseUnitsFn1,
        fromBaseUnitsFn2);
  }

  int len() {
    return body.len;
  }

  int height() {
    return body.height;
  }

  bool isLeaf() {
    return body.height == 0;
  }

  bool isEmpty() {
    return len() == 0;
  }

  List<Node<L, N>> getChildren() {
    var val = body.val;
    if (val is InternalVal<L, N>) {
      return val.nodes;
    } else {
      throw Exception("getChildren called on leaf node");
    }
  }

  L getLeaf() {
    var val = body.val;
    if (val is LeafVal<L, N>) {
      return val.value;
    } else {
      throw Exception("getLeaf called on internal node");
    }
  }

  bool isOkChild() {
    var val = body.val;
    if (val is LeafVal<L, N>) {
      return val.value.isOkChild();
    }
    if (val is InternalVal<L, N>) {
      return val.nodes.length >= minChildren;
    }

    throw Exception("unreachable!");
  }

  T withLeaf<T>(T Function(L) f, N Function(L) computeInfo) {
    var inner = body;
    var val = inner.val;
    if (val is LeafVal<L, N>) {
      var result = f(val.value);
      inner.len = val.value.len();
      inner.info = computeInfo(val.value);
      return result;
    } else {
      throw Exception("withLeaf called on internal node");
    }
  }

  Interval interval() {
    return this.body.info.interval(body.len);
  }

  Node<L, N> edit(IntervalBounds iv, Node<L, N> newNode,
      N Function(L) computeInfo, Node<L, N> Function() fromLeaf) {
    var b = TreeBuilder<L, N>();
    var iv2 = iv.intoInterval(len());
    var selfIv = interval();
    b.pushSlice(this, selfIv.prefix(iv2), computeInfo);
    b.push(newNode, computeInfo);
    b.pushSlice(this, selfIv.suffix(iv2), computeInfo);
    return b.build(fromLeaf, computeInfo);
  }

  static Node<L, N> fromLeaf<L extends Leaf<L>, N extends NodeInfo<L, N>>(L l,
      N Function(L) computeInfo) {
    var len = l.len();
    var info = computeInfo(l);
    var body =
    NodeBody(height: 0, len: len, info: info, val: LeafVal<L, N>(value: l));
    return Node<L, N>(body: body);
  }

  static Node<L, N> fromNodes<L extends Leaf<L>, N extends NodeInfo<L, N>>(
      List<Node<L, N>> nodes) {
    assert(nodes.length > 1);
    assert(nodes.length <= maxChildren);
    var height = nodes[0].body.height + 1;
    var len = nodes[0].body.len;
    var info = nodes[0].body.info.clone();
    assert(nodes[0].isOkChild());
    for (var child in nodes.sublist(1)) {
      assert(child.height() + 1 == height);
      assert(child.isOkChild());
      len += child.body.len;
      info.accumulate(child.body.info);
    }
    return Node(
        body: NodeBody(
            height: height,
            len: len,
            info: info,
            val: InternalVal(nodes: nodes)));
  }

  static Node<L, N> mergeNodes<L extends Leaf<L>, N extends NodeInfo<L, N>>(
      List<Node<L, N>> children1, List<Node<L, N>> children2) {
    var nChildren = children1.length + children2.length;
    var allChildren = children1 + children2;
    if (nChildren <= maxChildren) {
      return Node.fromNodes(allChildren);
    } else {
      // Note: this leans left. Splitting at midpoint is also an option
      var splitpoint = min(maxChildren, nChildren - minChildren);
      var left = allChildren.take(splitpoint).toList();
      var right = allChildren.skip(splitpoint).toList();
      var parentNodes = [Node.fromNodes(left), Node.fromNodes(right)];
      return Node.fromNodes(parentNodes);
    }
  }

  static Node<L, N> mergeLeaves<L extends Leaf<L>, N extends NodeInfo<L, N>>(
      Node<L, N> rope1, Node<L, N> rope2, N Function(L) computeInfo) {
    assert(rope1.isLeaf() && rope2.isLeaf());

    var bothOk = rope1.getLeaf().isOkChild() && rope2.getLeaf().isOkChild();
    if (bothOk) {
      return Node.fromNodes([rope1, rope2]);
    }

    var node1 = rope1.body;
    var leaf2 = rope2.getLeaf();
    var val = node1.val;
    if (val is LeafVal<L, N>) {
      var leaf1 = val.value;
      var leaf2Iv = Interval(start: 0, end: leaf2.len());
      var newVal = leaf1.pushMaybeSplit(leaf2, leaf2Iv);
      node1.len = leaf1.len();
      node1.info = computeInfo(leaf1);
      if (newVal != null) {
        return Node.fromNodes([rope1, Node.fromLeaf(newVal, computeInfo)]);
      } else {
        return rope1;
      }
    } else {
      throw Exception("merge_leaves called on non-leaf");
    }
  }

  static Node<L, N> concat<L extends Leaf<L>, N extends NodeInfo<L, N>>(
      Node<L, N> rope1, Node<L, N> rope2, N Function(L) computeInfo) {
    var h1 = rope1.height();
    var h2 = rope2.height();

    var result = h1.compareTo(h2);
    if (result < 0) {
      var children2 = rope2.getChildren();
      if (h1 == h2 - 1 && rope1.isOkChild()) {
        return Node.mergeNodes([rope1], children2);
      }
      var newRope = Node.concat(rope1, children2[0].clone(), computeInfo);
      if (newRope.height() == h2 - 1) {
        return Node.mergeNodes([newRope], children2.sublist(1));
      } else {
        return Node.mergeNodes(newRope.getChildren(), children2.sublist(1));
      }
    } else if (result == 0) {
      if (rope1.isOkChild() && rope2.isOkChild()) {
        return Node.fromNodes([rope1, rope2]);
      }
      if (h1 == 0) {
        return Node.mergeLeaves(rope1, rope2, computeInfo);
      }
      return Node.mergeNodes(rope1.getChildren(), rope2.getChildren());
    } else {
      var children1 = rope1.getChildren();
      if (h2 == h1 - 1 && rope2.isOkChild()) {
        return Node.mergeNodes(children1, [rope2]);
      }
      var lastix = children1.length - 1;
      var newRope = Node.concat(children1[lastix].clone(), rope2, computeInfo);
      if (newRope.height() == h1 - 1) {
        return Node.mergeNodes(children1.sublist(0, lastix), [newRope]);
      } else {
        return Node.mergeNodes(
            children1.sublist(0, lastix), newRope.getChildren());
      }
    }
  }

  @override
  Node<L, N> clone() {
    return Node(body: body.clone());
  }

  // doesn't deal with endpoint, handle that specially if you need it
  int convertMetrics(int m1,
      bool Function() canFragmentFn1,
      int Function(N, int) measureFn1,
      int Function(N, int) measureFn2,
      int Function(L, int) toBaseUnitsFn1,
      int Function(L, int) fromBaseUnitsFn2) {
    if (m1 == 0) {
      return 0;
    }

    // If M1 can fragment, then we must land on the leaf containing
    // the m1 boundary. Otherwise, we can land on the beginning of
    // the leaf immediately following the M1 boundary, which may be
    // more efficient.
    final int m1Fudge;
    if (canFragmentFn1()) {
      m1Fudge = 1;
    } else {
      m1Fudge = 0;
    }

    var m2 = 0;
    var node = this;
    while (node.height() > 0) {
      for (var child in node.getChildren()) {
        var childM1 = child.measure(measureFn1);
        if (m1 < childM1 + m1Fudge) {
          node = child;
          break;
        }

        m2 += child.measure(measureFn2);
        m1 -= childM1;
      }
    }

    var l = node.getLeaf();
    var base = toBaseUnitsFn1(l, m1);
    return m2 + fromBaseUnitsFn2(l, base);
  }

  int measure(int Function(N, int) measureFn) {
    return measureFn(body.info, body.len);
  }
}

abstract class Leaf<Self extends Leaf<Self>> with Clone<Self> {
  int len();

  bool isOkChild();

  Self? pushMaybeSplit(Self other, Interval iv);

  Self defaultValue();

  Self subseq(Interval iv, Self self) {
    var result = defaultValue();
    if (result.pushMaybeSplit(self, iv) != null) {
      throw Exception("unexpected split");
    }
    return result;
  }
}

mixin Clone<Self extends Clone<Self>> {
  Self clone();
}

abstract class NodeInfo<L, Self extends NodeInfo<L, Self>> with Clone<Self> {
  void accumulate(Self other);

  Interval interval(int len) {
    return Interval(start: 0, end: len);
  }
}

class NodeBody<L, N extends NodeInfo<L, N>> with Clone<NodeBody<L, N>> {
  final int height;
  int len;
  N info;
  final NodeVal<L, N> val;

  NodeBody({
    required this.height,
    required this.len,
    required this.info,
    required this.val,
  });

  @override
  NodeBody<L, N> clone() {
    return NodeBody<L, N>(
        height: height, len: len, info: info.clone(), val: val.clone());
  }
}

abstract class NodeVal<L, N extends NodeInfo<L, N>> with Clone<NodeVal<L, N>> {}

class LeafVal<L extends Leaf<L>, N extends NodeInfo<L, N>>
    extends NodeVal<L, N> {
  final L value;

  LeafVal({required this.value});

  @override
  NodeVal<L, N> clone() {
    return LeafVal<L, N>(value: value.clone());
  }
}

class InternalVal<L extends Leaf<L>, N extends NodeInfo<L, N>>
    extends NodeVal<L, N> {
  final List<Node<L, N>> nodes;

  InternalVal({required this.nodes});

  @override
  NodeVal<L, N> clone() {
    var newNodes = nodes.map((e) => e.clone()).toList();
    return InternalVal<L, N>(nodes: newNodes);
  }
}

enum Ordering {
  less,
  equal,
  greater,
}

class TreeBuilder<L extends Leaf<L>, N extends NodeInfo<L, N>> {
  final List<List<Node<L, N>>> stack;

  TreeBuilder() : stack = [];

  void push(Node<L, N> n, N Function(L) computeInfo) {
    topLoop:
    while (true) {
      late Ordering ord;
      if (stack.isNotEmpty) {
        var result = stack.last[0].height().compareTo(n.height());
        if (result < 0) {
          ord = Ordering.less;
        } else if (result == 0) {
          ord = Ordering.equal;
        } else {
          ord = Ordering.greater;
        }
      } else {
        ord = Ordering.greater;
      }

      switch (ord) {
        case Ordering.less:
          n = Node.concat(pop(), n, computeInfo);
          break;
        case Ordering.equal:
          var tos = stack.last;
          if (tos.last.isOkChild() && n.isOkChild()) {
            tos.add(n);
          } else if (n.height() == 0) {
            var iv = Interval(start: 0, end: n.len());
            var newLeaf = tos.last.withLeaf(
                    (l) => l.pushMaybeSplit(n.getLeaf(), iv), computeInfo);
            if (newLeaf != null) {
              tos.add(Node.fromLeaf(newLeaf, computeInfo));
            }
          } else {
            var last = tos.removeLast();
            var children1 = last.getChildren();
            var children2 = n.getChildren();
            var nChildren = children1.length + children2.length;
            var allChildren = children1 + children2;
            if (nChildren <= maxChildren) {
              tos.add(Node.fromNodes(allChildren));
            } else {
              // Note: this leans left. Splitting at midpoint is also an option
              var splitpoint = min(maxChildren, nChildren - minChildren);
              var left = allChildren.take(splitpoint).toList();
              var right = allChildren.skip(splitpoint).toList();
              tos.add(Node.fromNodes(left));
              tos.add(Node.fromNodes(right));
            }
          }
          if (tos.length < maxChildren) {
            break topLoop;
          }
          n = pop();
          break;
        case Ordering.greater:
          stack.add([n]);
          break topLoop;
      }
    }
  }

  Node<L, N> pop() {
    var nodes = stack.removeLast();
    if (nodes.length == 1) {
      var it = nodes.iterator;
      it.moveNext();
      return it.current;
    } else {
      return Node.fromNodes(nodes);
    }
  }

  void pushLeaf(L l, N Function(L) computeInfo) {
    push(Node.fromLeaf(l, computeInfo), computeInfo);
  }

  void pushLeafSlice(L l, Interval iv, N Function(L) computeInfo) {
    push(Node.fromLeaf(l.subseq(iv, l), computeInfo), computeInfo);
  }

  void pushSlice(Node<L, N> n, Interval iv, N Function(L) computeInfo) {
    if (iv.isEmpty()) {
      return;
    }
    if (iv == n.interval()) {
      push(n.clone(), computeInfo);
      return;
    }
    var l = n.body.val;
    if (l is LeafVal<L, N>) {
      pushLeafSlice(l.value, iv, computeInfo);
    } else if (l is InternalVal<L, N>) {
      var offset = 0;
      for (var child in l.nodes) {
        if (iv.isBefore(offset)) {
          break;
        }
        var childIv = child.interval();
        var recIv =
        iv.intersect(childIv.translate(offset)).translateNeg(offset);
        pushSlice(child, recIv, computeInfo);
        offset += child.len();
      }
    } else {
      throw Exception("unreachable!");
    }
  }

  Node<L, N> build(Node<L, N> Function() fromLeaf, N Function(L) computeInfo) {
    if (stack.isEmpty) {
      return fromLeaf();
    } else {
      var n = pop();
      while (stack.isNotEmpty) {
        n = Node.concat(pop(), n, computeInfo);
      }
      return n;
    }
  }
}

class Cursor<L extends Leaf<L>, N extends NodeInfo<L, N>> {
  static const int cursorCacheSize = 4;

  final Node<L, N> root;
  int position;
  final List<Tuple2<Node<L, N>, int>?> cache;
  L? leaf;
  int offsetOfLeaf;

  Cursor({
    required this.root,
    required this.position,
  })
      : cache = List<Tuple2<Node<L, N>, int>?>.filled(cursorCacheSize, null),
        leaf = null,
        offsetOfLeaf = 0 {
    descend();
  }

  Tuple2<L, int>? getLeaf() {
    var l = leaf;
    return l == null ? null : Tuple2(l, position - offsetOfLeaf);
  }

  int pos() {
    return position;
  }

  Tuple2<L, int>? nextLeaf() {
    final leaf = this.leaf;
    if (leaf == null) {
      return null;
    }

    position = offsetOfLeaf + leaf.len();
    for (var i in Iterable<int>.generate(cursorCacheSize)) {
      if (cache[i] == null) {
        this.leaf = null;
        return null;
      }
      var t = cache[i]!;
      var node = t.item1;
      var j = t.item2;
      if (j + 1 < node
          .getChildren()
          .length) {
        cache[i] = Tuple2(node, j + 1);
        var nodeDown = node.getChildren()[j + 1];
        for (var k in Iterable<int>.generate(i)
            .toList()
            .reversed) {
          cache[k] = Tuple2(nodeDown, 0);
          nodeDown = nodeDown.getChildren()[0];
        }
        this.leaf = nodeDown.getLeaf();
        offsetOfLeaf = position;
        return getLeaf();
      }
    }
    if (offsetOfLeaf + this.leaf!.len() == root.len()) {
      this.leaf = null;
      return null;
    }
    descend();
    return getLeaf();
  }

  void descend() {
    var node = root;
    var offset = 0;
    while (node.height() > 0) {
      var children = node.getChildren();
      var i = 0;
      while (true) {
        if (i + 1 == children.length) {
          break;
        }
        var nextoff = offset + children[i].len();
        if (nextoff > position) {
          break;
        }
        offset = nextoff;
        i += 1;
      }
      var cacheIx = node.height() - 1;
      if (cacheIx < cursorCacheSize) {
        cache[cacheIx] = Tuple2(node, i);
      }
      node = children[i];
    }
    leaf = node.getLeaf();
    offsetOfLeaf = offset;
  }

  /// The length of the tree.
  int totalLen() {
    return root.len();
  }

  /// Moves the cursor to the next boundary.
  ///
  /// When there is no next boundary, returns `None` and the cursor becomes invalid.
  ///
  /// Return value: the position of the boundary, if it exists.
  int? next(int? Function(L, int) nextFn, int Function(N, int) measureFn) {
    // mytodo: implement
    if (position >= root.len() || leaf == null) {
      leaf = null;
      return null;
    }

    var nextInsideLeafVal = nextInsideLeaf(nextFn);
    if (nextInsideLeafVal != null) {
      return nextInsideLeafVal;
    }

    var nextLeafResult = nextLeaf();
    if (nextLeafResult == null) {
      return null;
    }

    var nextInsideLeafResult = nextInsideLeaf(nextFn);
    if (nextInsideLeafResult != null) {
      return nextInsideLeafResult;
    }

    // Leaf is 0-measure (otherwise would have already succeeded).
    var measure = measureLeaf(position, measureFn);
    descendMetric(measure + 1, measureFn);
    var nextInsideLeafResult2 = nextInsideLeaf(nextFn);
    if (nextInsideLeafResult2 != null) {
      return nextInsideLeafResult2;
    }

    // Not found, properly invalidate cursor.
    position = root.len();
    leaf = null;
    return null;
  }

  /// Tries to find the next boundary in the leaf the cursor is currently in.
  int? nextInsideLeaf(int? Function(L, int) nextFn) {
    // mytodo: implement
    assert(leaf != null, "inconsistent, shouldn't get here");

    var l = leaf!;
    int offsetInLeaf = position - offsetOfLeaf;
    var maybeResult = nextFn(l, offsetInLeaf);
    if (maybeResult == null) {
      return null;
    }
    offsetInLeaf = maybeResult;

    if (offsetInLeaf == l.len() && offsetOfLeaf + offsetInLeaf != root.len()) {
      nextLeaf();
    } else {
      position = offsetOfLeaf + offsetInLeaf;
    }

    return position;
  }

  /// Returns the measure at the beginning of the leaf containing `pos`.
  ///
  /// This method is O(log n) no matter the current cursor state.
  int measureLeaf(int pos, int Function(N, int) measureFn) {
    var node = root;
    var metric = 0;

    while (node.height() > 0) {
      for (var child in node.getChildren()) {
        var len = child.len();
        if (pos < len) {
          node = child;
          break;
        }
        pos -= len;
        metric += measureFn(child.body.info, child.body.len);
      }
    }

    return metric;
  }

  /// Find the leaf having the given measure.
  ///
  /// This function sets `self.position` to the beginning of the leaf
  /// containing the smallest offset with the given metric, and also updates
  /// state as if [`descend`](#method.descend) was called.
  ///
  /// If `measure` is greater than the measure of the whole tree, then moves
  /// to the last node.
  void descendMetric(int measure, int Function(N, int) measureFn) {
    var node = root;
    var offset = 0;

    while (node.height() > 0) {
      var children = node.getChildren();
      var i = 0;
      while (true) {
        if (i + 1 == children.length) {
          break;
        }

        var child = children[i];
        var childM = measureFn(child.body.info, child.body.len);
        if (childM >= measure) {
          break;
        }
        offset += child.len();
        measure -= childM;
        i += 1;
      }
      var cacheIx = node.height() - 1;
      if (cacheIx < cursorCacheSize) {
        cache[cacheIx] = Tuple2(node, i);
      }
      node = children[i];
    }
    leaf = node.getLeaf();
    position = offset;
    offsetOfLeaf = offset;
  }

  /// Set the position of the cursor.
  ///
  /// The cursor is valid after this call.
  ///
  /// Precondition: `position` is less than or equal to the length of the tree.
  void set(int pos) {
    this.position = pos;
    var l = leaf;
    if (l != null) {
      if (this.position >= offsetOfLeaf &&
          this.position < offsetOfLeaf + l.len()) {
        return;
      }
    }
    descend();
  }

  /// Returns the current position if it is a boundary in this [`Metric`],
  /// else behaves like [`prev`](#method.prev).
  ///
  /// [`Metric`]: struct.Metric.html
  int? atOrPrev(bool Function() canFragmentFn,
      bool Function(L, int) isBoundaryFn,
      int? Function(L, int) prevFn,
      int Function(N, int) measureFn) {
    if (isBoundary(canFragmentFn, isBoundaryFn)) {
      return pos();
    } else {
      return prev(isBoundaryFn, prevFn, measureFn);
    }
  }

  /// Determine whether the current position is a boundary.
  ///
  /// Note: the beginning and end of the tree may or may not be boundaries, depending on the
  /// metric. If the metric is not `can_fragment`, then they always are.
  bool isBoundary(bool Function() canFragmentFn,
      bool Function(L, int) isBoundaryFn) {
    if (leaf == null) {
      // not at a valid position
      return false;
    }

    if (position == offsetOfLeaf && !canFragmentFn()) {
      return true;
    }

    if (position == 0 || position > offsetOfLeaf) {
      return isBoundaryFn(leaf!, position - offsetOfLeaf);
    }

    // tricky case, at beginning of leaf, need to query end of previous
    // leaf; TODO: would be nice if we could do it another way that didn't
    // make the method &mut self.
    var l = prevLeaf()!.item1;
    var result = isBoundaryFn(l, l.len());
    nextLeaf();
    return result;
  }

  /// Move to beginning of previous leaf.
  ///
  /// Return value: same as [`get_leaf`](#method.get_leaf).
  Tuple2<L, int>? prevLeaf() {
    if (offsetOfLeaf == 0) {
      leaf = null;
      position = 0;
      return null;
    }

    for (var i in Iterable<int>.generate(cursorCacheSize)) {
      var cacheItem = cache[i];
      if (cacheItem == null) {
        // this probably can't happen
        leaf = null;
        return null;
      }

      var node = cacheItem.item1;
      var j = cacheItem.item2;
      if (j > 0) {
        cache[i] = Tuple2(node, j - 1);
        var nodeDown = node.getChildren()[j - 1];
        for (var k in Iterable<int>.generate(i)
            .toList()
            .reversed) {
          var lastIx = nodeDown
              .getChildren()
              .length - 1;
          cache[k] = Tuple2(nodeDown, lastIx);
          nodeDown = nodeDown.getChildren()[lastIx];
        }

        var leaf = nodeDown.getLeaf();
        this.leaf = leaf;
        offsetOfLeaf -= leaf.len();
        position = offsetOfLeaf;
        return getLeaf();
      }
    }

    position = offsetOfLeaf - 1;
    descend();
    position = offsetOfLeaf;
    return getLeaf();
  }

  /// Moves the cursor to the previous boundary.
  ///
  /// When there is no previous boundary, returns `None` and the cursor becomes invalid.
  ///
  /// Return value: the position of the boundary, if it exists.
  int? prev(bool Function(L, int) isBoundaryFn, int? Function(L, int) prevFn,
      int Function(N, int) measureFn) {
    if (position == 0 || leaf == null) {
      leaf = null;
      return null;
    }

    var origPos = position;
    var offsetInLeaf = origPos - offsetOfLeaf;
    if (offsetInLeaf > 0) {
      var l = leaf!;
      var prevResult = prevFn(l, offsetInLeaf);
      if (prevResult != null) {
        position = offsetOfLeaf + prevResult;
        return position;
      }
    }

    // not in same leaf, need to scan backwards
    prevLeaf();
    var offset = lastInsideLeaf(origPos, isBoundaryFn, prevFn);
    if (offset != null) {
      return offset;
    }

    // Not found in previous leaf, find using measurement.
    var measure = measureLeaf(position, measureFn);
    if (measure == 0) {
      leaf = null;
      position = 0;
      return null;
    }

    descendMetric(measure, measureFn);
    return lastInsideLeaf(origPos, isBoundaryFn, prevFn);
  }

  /// Tries to find the last boundary in the leaf the cursor is currently in.
  ///
  /// If the last boundary is at the end of the leaf, it is only counted if
  /// it is less than `orig_pos`.
  int? lastInsideLeaf(int origPos, bool Function(L, int) isBoundaryFn,
      int? Function(L, int) prevFn) {
    assert(leaf != null, "inconsistent, shouldn't get here");
    var l = leaf!;
    var len = l.len();

    if (offsetOfLeaf + len < origPos && isBoundaryFn(l, len)) {
      nextLeaf();
      return position;
    }

    var offsetInLeaf = prevFn(l, len);
    if (offsetInLeaf == null) {
      return null;
    }

    position = offsetOfLeaf + offsetInLeaf;
    return position;
  }
}

abstract class Metric<L extends Leaf<L>, N extends NodeInfo<L, N>> {
  /// Return the size of the
  /// [NodeInfo::L](trait.NodeInfo.html#associatedtype.L), as measured by this
  /// metric.
  ///
  /// The usize argument is the total size/length of the node, in base units.
  ///
  /// # Examples
  /// For the [LinesMetric](../rope/struct.LinesMetric.html), this gives the number of
  /// lines in string contained in the leaf. For the
  /// [BaseMetric](../rope/struct.BaseMetric.html), this gives the size of the string
  /// in uft8 code units, that is, bytes.
  int measure(N info, int len);

  /// Returns the smallest offset, in base units, for an offset in measured units.
  ///
  /// # Invariants:
  ///
  /// - `from_base_units(to_base_units(x)) == x` is True for valid `x`
  int toBaseUnits(L l, int inMeasuredUnits);

  /// Returns the smallest offset in measured units corresponding to an offset in base units.
  ///
  /// # Invariants:
  ///
  /// - `from_base_units(to_base_units(x)) == x` is True for valid `x`
  int fromBaseUnits(L l, int inBaseUnits);

  /// Return whether the offset in base units is a boundary of this metric.
  /// If a boundary is at end of a leaf then this method must return true.
  /// However, a boundary at the beginning of a leaf is optional
  /// (the previous leaf will be queried).
  bool isBoundary(L l, int offset);

  /// Returns the index of the boundary directly preceding offset,
  /// or None if no such boundary exists. Input and result are in base units.
  int? prev(L l, int offset);

  /// Returns the index of the first boundary for which index > offset,
  /// or None if no such boundary exists. Input and result are in base units.
  int? next(L l, int offset);

  /// Returns true if the measured units in this metric can span multiple
  /// leaves.  As an example, in a metric that measures lines in a rope, a
  /// line may start in one leaf and end in another; however in a metric
  /// measuring bytes, storage of a single byte cannot extend across leaves.
  bool canFragment();
}
