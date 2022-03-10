import 'dart:math';

import 'interval.dart';

import 'tree.dart';

typedef RopeNode = Node<StringLeaf, RopeInfo>;

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
    _current = leaf.str.substring(startPos, startPos + len);
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

  Chunks chunks<T extends IntervalBounds>(T range) {
    var interval = range.intoInterval(len());
    var cursor = Cursor(root: this, position: interval.start);
    return Chunks(cursor: cursor, end: interval.end);
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
        lines: _countNewlines(self.str),
        utf16Size: self.str.length);
  }

  static RopeInfo identity() {
    return RopeInfo(lines: 0, utf16Size: 0);
  }

  static int _countNewlines(String s) {
    return s.allMatches("\n").length;
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
  // todo: use memrchr?
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
  String str;

  StringLeaf(this.str);

  @override
  int len() {
    return str.length;
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
    str = str + other.str.substring(start, end);
    if (len() <= maxLeaf) {
      return null;
    } else {
      var splitpoint = findLeafSplitForMerge(str);
      var rightStr = str.substring(splitpoint);
      str = str.substring(0, splitpoint);
      return rightStr.toLeaf();
    }
  }

  @override
  StringLeaf clone() {
    return StringLeaf(str);
  }

  @override
  StringLeaf defaultValue() {
    return StringLeaf("");
  }
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
