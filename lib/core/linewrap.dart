import 'dart:math';

import 'package:rope/rope.dart';

typedef BreaksNode = Node<BreaksLeaf, BreaksInfo>;

class Breaks extends Node<BreaksLeaf, BreaksInfo> {
  Breaks({required NodeBody<BreaksLeaf, BreaksInfo> body}) : super(body: body);

  static BreaksNode newNoBreak(int len) {
    var leaf = BreaksLeaf(len: len, data: []);
    return Node.fromLeaf(leaf, BreaksInfo.computeInfo);
  }
}

class Lines {
  BreaksNode breaks;

  Lines()
      : breaks =
            Node.fromLeaf(BreaksLeaf(len: 0, data: <int>[]), BreaksInfo.computeInfo);

  void setWrapWidth(RopeNode text) {
    breaks = Breaks.newNoBreak(text.len());
  }

  VisualLines iterLines(RopeNode text, int startLine) {
    var cursor = MergedBreaks(text, breaks);
    var offset = cursor.offsetOfLine(startLine);
    var logicalLine = Rope.lineOfOffset(text, offset) + 1;
    cursor.setOffset(offset);
    return VisualLines(
        offset: offset,
        cursor: cursor,
        len: text.len(),
        logicalLine: logicalLine,
        eof: false);
  }
}

/// how far away a line can be before we switch to a binary search
const int maxLinearDist = 20;

class MergedBreaks extends Iterable<int?> {
  final Cursor<StringLeaf, RopeInfo> text;
  final Cursor<BreaksLeaf, BreaksInfo> soft;
  int offset;

  /// Starting from zero, how many calls to `next` to get to `self.offset`?
  int curLine;
  late final int totalLines;

  /// Total length, in base units
  late final int len;

  MergedBreaks(RopeNode rope, BreaksNode breaks)
      : assert(rope.len() == breaks.len()),
        text = Cursor(root: rope, position: 0),
        soft = Cursor(root: breaks, position: 0),
        offset = 0,
        curLine = 0 {
    totalLines = LinesMetric.measure(text.root.body.info, text.root.body.len) +
        BreaksMetric.measure(soft.root.body.info, soft.root.body.len) +
        1;
    len = text.totalLen();
  }

  bool isHardBreak() {
    return offset == text.pos();
  }

  @override
  Iterator<int?> get iterator => MergedBreaksIter(
      text: text,
      soft: soft,
      offset: offset,
      curLine: curLine,
      totalLines: totalLines,
      len: len);

  int offsetOfLine(int line) {
    if (line == 0) {
      return 0;
    } else if (line >= totalLines) {
      return text.totalLen();
    } else if (line == curLine) {
      return offset;
    } else if (line > curLine && line - curLine < maxLinearDist) {
      return offsetOfLineLinear(line);
    } else {
      return offsetOfLineBsearch(line);
    }
  }

  int offsetOfLineLinear(int line) {
    assert(line > curLine);
    var dist = line - curLine;
    try {
      return elementAt(dist - 1)!;
    } catch (_) {
      return len;
    }
  }

  int offsetOfLineBsearch(int line) {
    var range = Range(0, len);
    while (true) {
      var pivot = (range.start + (range.end - range.start) / 2).toInt();
      setOffset(pivot);

      if (curLine == line) {
        return offset;
      } else if (curLine > line) {
        range = Range(range.start, pivot);
      } else if (line - curLine > maxLinearDist) {
        range = Range(pivot, range.end);
      } else {
        return offsetOfLineLinear(line);
      }
    }
  }

  /// Sets the `self.offset` to the first valid break immediately at or preceding `offset`,
  /// and restores invariants.
  void setOffset(int offset) {
    text.set(offset);
    soft.set(offset);
    if (offset > 0) {
      if (text.atOrPrev(LinesMetric.canFragment, LinesMetric.isBoundary,
              LinesMetric.prev, LinesMetric.measure) ==
          null) {
        text.set(0);
      }

      if (soft.atOrPrev(BreaksMetric.canFragment, BreaksMetric.isBoundary,
              BreaksMetric.prev, BreaksMetric.measure) ==
          null) {
        soft.set(0);
      }
    }

    // self.offset should be at the first valid break immediately preceding `offset`, or 0.
    // the position of the non-break cursor should be > than that of the break cursor, or EOF.
    var cmpResult = text.pos().compareTo(soft.pos());
    if (cmpResult < 0) {
      text.next(LinesMetric.next, LinesMetric.measure);
    } else if (0 < cmpResult) {
      soft.next(BreaksMetric.next, BreaksMetric.measure);
    } else {
      assert(text.pos() == 0);
    }

    this.offset = min(text.pos(), soft.pos());
    curLine = mergedLineOfOffset(text.root, soft.root, this.offset);
  }

  int mergedLineOfOffset(RopeNode text, BreaksNode soft, int offset) {
    return text.count(
            offset,
            BaseMetric.canFragment,
            BaseMetric.measure,
            LinesMetric.measure,
            BaseMetric.toBaseUnits,
            LinesMetric.fromBaseUnits) +
        soft.count(
            offset,
            BreaksBaseMetric.canFragment,
            BreaksBaseMetric.measure,
            BreaksMetric.measure,
            BreaksBaseMetric.toBaseUnits,
            BreaksMetric.fromBaseUnits);
  }
}

class MergedBreaksIter extends Iterator<int?> {
  final Cursor<StringLeaf, RopeInfo> text;
  final Cursor<BreaksLeaf, BreaksInfo> soft;
  int offset;
  int curLine;
  final int totalLines;
  final int len;
  int? _current;

  MergedBreaksIter(
      {required this.text,
      required this.soft,
      required this.offset,
      required this.curLine,
      required this.totalLines,
      required this.len});

  @override
  int? get current => _current;

  @override
  bool moveNext() {
    if (text.pos() == offset && !atEof()) {
      // don't iterate past EOF, or we can't get the leaf and check for \n
      text.next(LinesMetric.next, LinesMetric.measure);
    }

    if (soft.pos() == offset) {
      soft.next(BreaksMetric.next, BreaksMetric.measure);
    }

    var prevOff = offset;
    offset = min(text.pos(), soft.pos());

    var isEofWithoutNewline = offset > 0 && atEof() && eofWithoutNewline();
    if (offset == prevOff || isEofWithoutNewline) {
      return false;
    } else {
      curLine += 1;
      _current = offset;
      return true;
    }
  }

  bool atEof() {
    return offset == len;
  }

  bool eofWithoutNewline() {
    assert(atEof());
    text.set(len);
    var tuple = text.getLeaf();
    assert(tuple != null);
    var l = tuple!.item1.toString();
    return !l.endsWith('\n');
  }
}

class VisualLine {
  final Interval interval;

  /// The logical line number for this line. Only present when this is the
  final int? lineNum;

  VisualLine({required this.interval, required this.lineNum});
}

class VisualLines extends Iterable<VisualLine?> {
  final MergedBreaks cursor;
  final int offset;

  /// The current logical line number.
  final int logicalLine;
  final int len;
  final bool eof;

  VisualLines(
      {required this.cursor,
      required this.offset,
      required this.logicalLine,
      required this.len,
      required this.eof});

  @override
  Iterator<VisualLine?> get iterator => VisualLineIter(
      cursor: cursor,
      offset: offset,
      logicalLine: logicalLine,
      len: len,
      eof: eof);
}

class VisualLineIter extends Iterator<VisualLine?> {
  final MergedBreaks cursor;
  int offset;

  /// The current logical line number.
  int logicalLine;
  final int len;
  bool eof;
  VisualLine? _current;

  VisualLineIter(
      {required this.cursor,
      required this.offset,
      required this.logicalLine,
      required this.len,
      required this.eof});

  @override
  VisualLine? get current {
    return _current;
  }

  @override
  bool moveNext() {
    int? lineNum;
    if (cursor.isHardBreak()) {
      lineNum = logicalLine;
    }

    cursor.iterator.moveNext();
    final int nextEndBound;
    var current = cursor.iterator.current;
    if (current != null) {
      nextEndBound = current;
    } else if (eof) {
      _current = null;
      return false;
    } else {
      eof = true;
      nextEndBound = len;
    }

    var result = VisualLine(
        interval: Interval(start: offset, end: nextEndBound), lineNum: lineNum);
    if (cursor.isHardBreak()) {
      logicalLine += 1;
    }
    offset = nextEndBound;
    _current = result;
    return true;
  }
}
