import 'package:rope/rope.dart';

// Toy app for experimenting with ropes
void main() {
  RopeNode rope = Rope.from("hello.");
  rope = rope.edit(Range(5, 6), Rope.from("!"), RopeInfo.computeInfo, Rope.fromLeaf);
  print(rope.toStr());
}
