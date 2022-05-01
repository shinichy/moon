mixin Clone<Self extends Clone<Self>> {
  Self clone();
}

class Segment with Clone<Segment> {
  int len;
  int count;

  Segment({required this.len, required this.count});

  @override
  Segment clone() {
    return Segment(len: len, count: count);
  }
}

class SubsetBuilder {
  List<Segment> segments = [];
  int totalLen = 0;

  void padToLen(int totalLen) {
    if (totalLen > this.totalLen) {
      var curLen = this.totalLen;
      pushSegment(totalLen - curLen, 0);
    }
  }

  void pushSegment(int len, int count) {
    assert(len > 0, "can't push empty segment");
    totalLen += len;

    // merge into previous segment if possible
    if (segments.isNotEmpty) {
      var last = segments.last;
      if (last.count == count) {
        last.len += len;
        return;
      }
    }

    segments.add(Segment(len: len, count: count));
  }

  Subset build() {
    return Subset(segments);
  }
}

class Subset with Clone<Subset> {
  List<Segment> segments;

  Subset(this.segments);

  // Creates an empty `Subset` of a string of length `len`
  static Subset empty(int len) {
    var sb = SubsetBuilder();
    sb.padToLen(len);
    return sb.build();
  }

  @override
  Subset clone() {
    var newSegments = segments.map((e) => e.clone()).toList();
    return Subset(newSegments);
  }
}
