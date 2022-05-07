import 'package:rope/rope.dart';

import 'selection.dart';

/// Replaces the selection with the text `T`.
RopeDelta insert(RopeNode base, List<SelRegion> regions, RopeNode rope) {
  var builder = Builder<StringLeaf, RopeInfo>(base.len());
  for (var region in regions) {
    var iv = Range(region.min(), region.max());
    builder.replace(iv, rope.clone());
  }

  return builder.build();
}

RopeDelta deleteBackward(RopeNode base, List<SelRegion> regions) {
  var builder = Builder<StringLeaf, RopeInfo>(base.len());
  for (var region in regions) {
    var start = base.prevCodepointOffset(region.end) ?? 0;
    var iv = Range(start, region.max());
    if (!iv.isEmpty()) {
      builder.delete(iv);
    }
  }

  return builder.build();
}
