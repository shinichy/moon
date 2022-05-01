/// Same as Rust's binary_search_by
int binarySearchBy<T>(List<T> sortedList, int Function(T) compareToFn) {
  int min = 0;
  int max = sortedList.length;
  while (min < max) {
    final int mid = min + ((max - min) >> 1);
    final T element = sortedList[mid];
    final int comp = compareToFn(element);
    if (comp == 0) {
      return mid;
    }
    if (comp < 0) {
      min = mid + 1;
    } else {
      max = mid;
    }
  }
  return min;
}
