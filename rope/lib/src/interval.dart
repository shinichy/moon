import 'dart:math';

import 'package:tuple/tuple.dart';

class Interval {
  int start;
  int end;

  Interval({required this.start, required this.end});

  bool isEmpty() {
    return end <= start;
  }

  bool isBefore(int val) {
    return end <= val;
  }

  Interval intersect(Interval other) {
    var start = max(this.start, other.start);
    var end = min(this.end, other.end);
    return Interval(start: start, end: max(start, end));
  }

  Interval translate(int amount) {
    return Interval(start: start + amount, end: end + amount);
  }

  Interval translateNeg(int amount) {
    assert(start >= amount);
    return Interval(start: start - amount, end: end - amount);
  }

  // the first half of self - other
  Interval prefix(Interval other) {
    return Interval(start: min(start, other.start), end: min(end, other.start));
  }

  // the second half of self - other
  Interval suffix(Interval other) {
    return Interval(start: max(start, other.end), end: max(end, other.end));
  }

  Tuple2<int, int> startEnd() {
    return Tuple2(start, end);
  }
}

abstract class IntervalBounds {
  Interval intoInterval(int upperBound);
}

class RangeFull extends IntervalBounds {
  @override
  Interval intoInterval(int upperBound) {
    return Interval(start: 0, end: upperBound);
  }
}

class Range extends IntervalBounds {
  final int start;
  final int end;

  Range(this.start, this.end);

  @override
  Interval intoInterval(int _upperBound) {
    return Interval(start: start, end: end);
  }
}
