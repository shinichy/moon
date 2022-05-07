import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rope/rope.dart';
import 'package:xi_client/client.dart';

import 'core/linewrap.dart';
import 'core/selection.dart';
import 'editor.dart';
import 'line_cache.dart';
import "core/edit_ops.dart" as edit_ops;

/// A notification called when the document has changed.
typedef DocumentChangeNotification = void Function(Document event);

// mytodo: performs actual text editing actions in this class instead of Xi core
/// Stores and manages updates to the state for a Xi document, and provides
/// access to the editing API to the [Editor], via the [XiViewProxy].
class Document extends Stream<Document> {
  final Lines _lines;

  final LineCache lines = LineCache(TextStyle(color: Colors.black));

  final TextStyle _defaultStyle = TextStyle(color: Colors.white);

  /// A connection to xi-core.
  XiViewProxy? _viewProxy;

  final StreamController<Document> _controller;

  RopeNode _rope;

  /// The selection state for this view. Invariant: non-empty.
  Selection _selection;

  Document()
      : _controller = StreamController.broadcast(),
        _rope = Rope.from(""),
        _lines = Lines(),
        _selection = Selection.simple(SelRegion.caret(0)) {
    _lines.setWrapWidth(_rope);
  }

  final List<Completer<XiViewProxy>>? _pending = [];

  /// Provides access to the [XiViewProxy] via a [Future].
  ///
  /// Because view creation is asynchronous, we cannot get a handle to the
  /// [XiViewProxy] until after the document has been created. By returning
  /// a [Future], we allow the [Editor] to call edit API methods before the
  /// view has been resolved.
  Future<XiViewProxy> get viewProxy {
    if (_viewProxy != null) {
      return Future.value(_viewProxy);
    }
    final completer = Completer<XiViewProxy>();
    _pending?.add(completer);
    return completer.future;
  }

  // Assigns the XiViewProxy. This should only be called once,
  // by the root [XiHandler] when the 'new_view' request first resolves.
  // void finalizeViewProxy(XiViewProxy newViewProxy) {
  //   assert(_viewProxy == null);
  //   _viewProxy = newViewProxy;
  //   var pending = _pending;
  //   if (pending != null) {
  //     for (var completer in pending) {
  //       completer.complete(_viewProxy);
  //     }
  //   }
  //   _pending = null;
  //   _notifyListeners();
  // }

  LineCol _scrollPos = LineCol(line: 0, col: 0);

  LineCol get scrollPos => _scrollPos;

  double _measureWidth(String s) {
    TextSpan span = TextSpan(text: s, style: _defaultStyle);
    TextPainter painter =
        TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
    return painter.width;
  }

  List<List<double>> measureWidths(List<Map<String, dynamic>> params) {
    List<List<double>> result = <List<double>>[];
    for (Map<String, dynamic> req in params) {
      List<double> inner = <double>[];
      List<String> strings = req['strings'];
      for (String s in strings) {
        inner.add(_measureWidth(s));
      }
      result.add(inner);
    }
    return result;
  }

  void _notifyListeners() {
    _controller.add(this);
  }

  void close() {
    _controller.close();
  }

  // @override
  // void scrollTo(int line, int col) {
  //   _scrollPos = LineCol(line: line, col: col);
  //   _notifyListeners();
  // }
  //
  // @override
  // void update(List<Map<String, dynamic>> params) {
  //   lines.applyUpdate(params);
  //   _notifyListeners();
  // }

  @override
  StreamSubscription<Document> listen(void Function(Document event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    scheduleMicrotask(_notifyListeners);
    return _controller.stream.listen(onData, onError: onError, onDone: onDone);
  }

  void insert(String chars) {
    var firstRegion = _selection.regions.first;
    var text = Rope.from(chars);
    _rope = _rope.edit(
        Range(firstRegion.start, firstRegion.start + chars.length),
        Rope.from(chars),
        RopeInfo.computeInfo,
        Rope.fromLeaf);
    _lines.setWrapWidth(_rope);
    var delta = edit_ops.insert(_rope, _selection.regions, text);
    var newSel = _selection.applyDelta(delta, true);
    _selection = newSel;
    var visualLines = _lines.iterLines(_rope, 0);
    lines.fromVisualLines(_rope, visualLines, _selection);
    _notifyListeners();
  }

  void deleteBackward() {
    var firstRegion = _selection.regions.first;
    _rope = _rope.edit(
        Range(firstRegion.start - 1, firstRegion.start),
        Rope.from(""),
        RopeInfo.computeInfo,
        Rope.fromLeaf);
    _lines.setWrapWidth(_rope);
    var delta = edit_ops.deleteBackward(_rope, _selection.regions);
    var newSel = _selection.applyDelta(delta, true);
    _selection = newSel;
    var visualLines = _lines.iterLines(_rope, 0);
    lines.fromVisualLines(_rope, visualLines, _selection);
    _notifyListeners();
  }
}
