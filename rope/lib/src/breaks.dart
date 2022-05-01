import 'dart:math';

import 'interval.dart';
import 'tree.dart';
import 'rope.dart';
import 'package:collection/collection.dart';

class BreaksLeaf extends Leaf<BreaksLeaf> {
  int _len;
  List<int> _data;

  BreaksLeaf({required int len, required List<int> data})
      : _len = len,
        _data = data;

  @override
  int len() {
    return _len;
  }

  @override
  bool isOkChild() {
    return _data.length >= minLeaf;
  }

  @override
  BreaksLeaf? pushMaybeSplit(BreaksLeaf other, Interval iv) {
    var t = iv.startEnd();
    var start = t.item1;
    var end = t.item2;
    for (var v in other._data) {
      if (start < v && v <= end) {
        _data.add(v - start + _len);
      }
    }
    // the min with other.len() shouldn't be needed
    _len += min(end, other.len()) - start;

    if (_data.length <= maxLeaf) {
      return null;
    } else {
      var splitpoint = (_data.length / 2).floor(); // number of breaks
      var splitpointUnits = _data[splitpoint - 1];
      _data = _data.sublist(0, splitpoint);
      var newData = _data.sublist(splitpoint).map((x) => x - splitpointUnits);
      var newLen = _len - splitpointUnits;
      _len = splitpointUnits;
      return BreaksLeaf(len: newLen, data: newData.toList());
    }
  }

  @override
  BreaksLeaf clone() {
    return BreaksLeaf(len: _len, data: List.of(_data));
  }

  @override
  BreaksLeaf defaultValue() {
    return BreaksLeaf(len: 0, data: []);
  }
}

class BreaksInfo extends NodeInfo<BreaksLeaf, BreaksInfo> {
  int numBreaks;

  BreaksInfo(this.numBreaks);

  @override
  void accumulate(BreaksInfo other) {
    numBreaks += other.numBreaks;
  }

  static BreaksInfo computeInfo(BreaksLeaf l) {
    return BreaksInfo(l._data.length);
  }

  @override
  BreaksInfo clone() {
    return BreaksInfo(numBreaks);
  }
}

class BreaksMetric {
  static int measure(BreaksInfo info, int len) {
    return info.numBreaks;
  }

  static int? prev(BreaksLeaf l, int offset) {
    for (var i in Iterable<int>.generate(l._data.length)) {
      if (offset <= l._data[i]) {
        if (i == 0) {
          return null;
        } else {
          return l._data[i - 1];
        }
      }
    }

    return l._data.last;
  }


  static int? next(BreaksLeaf l, int offset) {
    final int n;
    var result = binarySearch(l._data, offset);
    if (0 <= result) {
      n = result + 1;
    } else {
      n = lowerBound(l._data, offset);
    }

    if (n == l._data.length) {
      return null;
    } else {
      return l._data[n];
    }
  }

  static bool canFragment() {
    return true;
  }

  static bool isBoundary(BreaksLeaf l, int offset) {
    return 0 <= binarySearch(l._data, offset);
  }

  static int toBaseUnits(BreaksLeaf l, int inMeasuredUnits) {
    if (inMeasuredUnits > l._data.length) {
      return l._len + 1;
    } else if (inMeasuredUnits == 0) {
      return 0;
    } else {
      return l._data[inMeasuredUnits - 1];
    }
  }

  static int fromBaseUnits(BreaksLeaf l, int inBaseUnits) {
    var n = binarySearch(l._data, inBaseUnits);
    if (0 <= n) {
      return n + 1;
    } else {
      return lowerBound(l._data, inBaseUnits);
    }
  }
}

class BreaksBaseMetric {
  static int measure(BreaksInfo info, int len) {
    return len;
  }

  static int toBaseUnits(BreaksLeaf l, int inMeasuredUnits) {
    return inMeasuredUnits;
  }

  static int fromBaseUnits(BreaksLeaf l, int inBaseUnits) {
    return inBaseUnits;
  }

  static bool isBoundary(BreaksLeaf l, int offset) {
    return BreaksMetric.isBoundary(l, offset);
  }

  static int? prev(BreaksLeaf l, int offset) {
    return BreaksMetric.prev(l, offset);
  }

  static int? next(BreaksLeaf l, int offset) {
    return BreaksMetric.next(l, offset);
  }

  static bool canFragment() {
    return true;
  }
}
