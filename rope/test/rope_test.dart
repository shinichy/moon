import 'package:rope/rope.dart';
import 'package:test/test.dart';

void main() {
  group('Rope', () {
    test('should be created from String', () {
      var s = "hello.";
      RopeNode rope = Rope.from(s);
      expect(rope.toStr(), s);
    });

    test('should be edited', () {
      var s = "hello.";
      RopeNode rope = Rope.from(s);
      rope = rope.edit(Range(5, 6), Rope.from("!"), RopeInfo.computeInfo, Rope.fromLeaf);
      expect(rope.toStr(), "hello!");
    });
  });
}
