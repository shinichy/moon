import 'package:ffi/ffi.dart';
import 'dart:ffi' as ffi;
import 'tree_sitter.dart' as ts;

void demo() {
  final lib = ffi.DynamicLibrary.executable();
  final treeSitter = ts.TreeSitter(lib);
  final parser = treeSitter.ts_parser_new();
  treeSitter.ts_parser_set_language(parser, treeSitter.tree_sitter_json());
  final jsonStr = "[1, null]".toNativeUtf8();
  final tree = treeSitter.ts_parser_parse_string(
      parser, ffi.nullptr, jsonStr.cast(), jsonStr.length);
  final rootNode = treeSitter.ts_tree_root_node(tree);
  final nodeStr = treeSitter.ts_node_string(rootNode).cast<Utf8>();
  print(nodeStr.toDartString());
  malloc.free(nodeStr);
  treeSitter.ts_tree_delete(tree);
  treeSitter.ts_parser_delete(parser);
}
