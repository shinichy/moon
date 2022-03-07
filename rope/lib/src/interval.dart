class Interval {
  int start;
  int end;

  Interval({required this.start, required this.end});
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
