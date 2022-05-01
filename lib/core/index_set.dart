import 'package:rope/rope.dart';

void removeNAt<T extends Clone<T>>(List<T> v, int index, int n) {
  var result = n.compareTo(1);
  if (result == 0) {
    v.removeAt(index);
  } else if (result > 0) {
    var newLen = v.length - n;
    for (var i in [for(var i=index; i<newLen; i+=1) i]) {
      v[i] = v[i+n].clone();
    }
    v.removeRange(newLen, v.length);
  }
}
