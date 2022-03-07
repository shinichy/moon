import 'package:rope/rope.dart';
import 'package:test/test.dart';

void main() {
  group('Rope', () {
    test('should be created from String', () {
      var s = "hello.";
      RopeNode rope = Rope.from(s);
      expect(rope.toStr(), s);
    });
  });
}
