import 'dart:math';

import 'package:tuple/tuple.dart';

import 'interval.dart';

class Node<L extends Leaf<L>, N extends NodeInfo<L, N>> {
  final NodeBody<L, N> body;

  static const int minChildren = 4;
  static const int maxChildren = 8;

  Node({required this.body});

  int len() {
    return body.len;
  }

  int height() {
    return body.height;
  }

  List<Node<L,N>> getChildren() {
    var val = body.val;
    if (val is InternalVal<L,N>) {
      return val.nodes;
    } else {
      throw Exception("getChildren called on leaf node");
    }
  }

  L getLeaf() {
    var val = body.val;
    if (val is LeafVal<L,N>) {
      return val.value;
    } else {
      throw Exception("getLeaf called on internal node");
    }
  }

  bool isOkChild() {
    var val = body.val;
    if (val is LeafVal<L,N>) {
      return val.value.isOkChild();
    }
    if (val is InternalVal<L,N>) {
      return val.nodes.length >= minChildren;
    }

    throw Exception("unreachable!");
  }

  T withLeaf<T>(T Function(L) f, N Function(L) computeInfo) {
    var inner = body;
    var val = inner.val;
    if (val is LeafVal<L,N>) {
      var result = f(val.value);
      inner.len = val.value.len();
      inner.info = computeInfo(val.value);
      return result;
    } else {
      throw Exception("withLeaf called on internal node");
    }
  }

  static Node<L, N> fromLeaf<L extends Leaf<L>, N extends NodeInfo<L, N>>(
      L l, N Function(L) computeInfo) {
    var len = l.len();
    var info = computeInfo(l);
    var body = NodeBody(
        height: 0, len: len, info: info, val: LeafVal<L, N>(value: l));
    return Node<L, N>(body: body);
  }

  static Node<L,N> fromNodes<L extends Leaf<L>, N extends NodeInfo<L, N>>(List<Node<L,N>> nodes) {
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
    return Node(body: NodeBody(height: height, len: len, info: info, val: InternalVal(nodes: nodes)));
  }

  static Node<L, N> concat<L extends Leaf<L>, N extends NodeInfo<L, N>>(
      Node<L, N> rope1, Node<L, N> rope2) {
    throw UnimplementedError;
  }
}

abstract class Leaf<Self extends Leaf<Self>> {
  int len();

  bool isOkChild();

  Self? pushMaybeSplit(Self other, Interval iv);
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

class NodeBody<L, N extends NodeInfo<L, N>> {
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
}

abstract class NodeVal<L, N extends NodeInfo<L, N>> {}

class LeafVal<L extends Leaf<L>, N extends NodeInfo<L, N>> extends NodeVal<L, N> {
  final L value;

  LeafVal({required this.value});
}

class InternalVal<L extends Leaf<L>, N extends NodeInfo<L, N>> extends NodeVal<L, N> {
  final List<Node<L,N>> nodes;

  InternalVal({required this.nodes});
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
          n = Node.concat(pop(), n);
          break;
        case Ordering.equal:
          var tos = stack.last;
          if (tos.last.isOkChild() && n.isOkChild()) {
            tos.add(n);
          } else if (n.height() == 0) {
            var iv = Interval(start: 0, end: n.len());
            var newLeaf = tos.last.withLeaf((l) => l.pushMaybeSplit(n.getLeaf(), iv), computeInfo);
            if (newLeaf != null) {
              tos.add(Node.fromLeaf(newLeaf, computeInfo));
            }
          } else {
            var last = tos.removeLast();
            var children1 = last.getChildren();
            var children2 = n.getChildren();
            var nChildren = children1.length + children2.length;
            var allChildren = children1 + children2;
            if (nChildren <= Node.maxChildren) {
              tos.add(Node.fromNodes(allChildren));
            } else {
              // Note: this leans left. Splitting at midpoint is also an option
              var splitpoint = min(Node.maxChildren, nChildren - Node.minChildren);
              var left = allChildren.take(splitpoint).toList();
              var right =allChildren.skip(splitpoint).toList();
              tos.add(Node.fromNodes(left));
              tos.add(Node.fromNodes(right));
            }
          }
          if (tos.length < Node.maxChildren) {
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

  Node<L, N> build(
    Node<L, N> Function() fromLeaf,
  ) {
    if (stack.isEmpty) {
      return fromLeaf();
    } else {
      var n = pop();
      while (stack.isNotEmpty) {
        n = Node.concat(pop(), n);
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
  })  : cache = List<Tuple2<Node<L, N>, int>?>.filled(cursorCacheSize, null),
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
      if (j + 1 < node.getChildren().length) {
        cache[i] = Tuple2(node, j + 1);
        var nodeDown = node.getChildren()[j + 1];
        for (var k in Iterable<int>.generate(i).toList().reversed) {
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
}
