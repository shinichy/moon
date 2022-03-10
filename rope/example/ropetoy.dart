import 'package:rope/rope.dart';

// Toy app for experimenting with ropes
void main() {
  RopeNode a = Rope.from("hello.");
  a = a.edit(Range(5, 6), Rope.from("!"), RopeInfo.computeInfo, Rope.fromLeaf);
  for (var i in Iterable<int>.generate(1000000)) {
    var l = a.len();
    a = a.edit(Range(l, l), Rope.from(i.toString() + "\n"), RopeInfo.computeInfo, Rope.fromLeaf);
  }
  var l = a.len();
  for (var s in a.clone().chunks(Range(1000, 3000))) {
    print("chunk $s");
  }
  a = a.edit(Range(1000, l), Rope.from(""), RopeInfo.computeInfo, Rope.fromLeaf);
  print(a.toStr());
}
