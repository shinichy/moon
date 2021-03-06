import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui
    show Paragraph, ParagraphBuilder, ParagraphConstraints, ParagraphStyle;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:xi_client/client.dart';

import 'document.dart';
import 'key_info.dart';
import 'line_cache.dart';
import 'text_line.dart';

final log = Logger('EditorLogger');

/// Widget for one editor tab.
class Editor extends StatefulWidget {
  /// If `true`, draws a watermark in the background of the editor view.
  final bool debugBackground;

  final Document document;

  const Editor({required this.document, Key? key, this.debugBackground = false})
      : super(key: key);

  @override
  EditorState createState() => EditorState();
}

/// A simple class representing a line and column location in the view.
class LineCol {
  /// Create a new location for the given line and column
  LineCol({required this.line, required this.col});

  /// The line number, 0-based
  final int line;

  /// The column, as a utf-8 offset from beginning of line
  final int col;

  @override
  String toString() {
    return 'line: $line, col: $col';
  }
}

const String _zeroWidthSpace = '\u{200b}';

/// State for editor tab
class EditorState extends State<Editor> {
  final ScrollController _controller = ScrollController();

  // Height of lines (currently fixed, all lines have the same height)
  late double _lineHeight;

  // location of last tap (used to expand selection on long press)
  LineCol? _lastTapLocation;

  final FocusNode _focusNode = FocusNode();
  late FocusAttachment _focusAttachment;
  TextStyle _defaultStyle;

  StreamSubscription<Document>? _documentStream;

  /// Creates a new editor state.
  EditorState() : _defaultStyle = TextStyle(color: Color(0xFF000000)) {
    // TODO: make style configurable
    _lineHeight = _lineHeightForStyle(_defaultStyle);
  }

  /// Returns a [Future] that will resolve when initialization has finished.
  Future<XiViewProxy> get viewProxy {
    return widget.document.viewProxy;
  }

  @override
  void initState() {
    super.initState();
    _setupStream();
    _focusAttachment = _focusNode.attach(context);
  }

  @override
  void didUpdateWidget(Editor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _setupStream();
  }

  void _setupStream() {
    _documentStream ??= widget.document.listen((Document doc) => setState(() {
          assert(doc == widget.document);
          _updateScrollPosition();
        }));
  }

  @override
  void dispose() {
    _documentStream?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  double _lineHeightForStyle(TextStyle style) {
    ui.ParagraphBuilder builder = ui.ParagraphBuilder(ui.ParagraphStyle())
      ..pushStyle(style.getTextStyle())
      ..addText(_zeroWidthSpace);
    ui.Paragraph layout = builder.build()
      ..layout(ui.ParagraphConstraints(width: double.infinity));
    return layout.height;
  }

  void _updateScrollPosition() {
    if (_controller.hasClients && _controller.position.haveDimensions) {
      ScrollPosition pos = _controller.position;
      double topY = widget.document.scrollPos.line * _lineHeight;
      double botY = topY + _lineHeight;
      if (topY < pos.pixels) {
        pos.jumpTo(topY);
      } else if (botY > pos.pixels + pos.viewportDimension) {
        pos.jumpTo(botY - pos.viewportDimension);
      }
    }
  }

  void _doMovement(Movement movement, bool modifySel) {
    viewProxy.then((view) => modifySel
        ? view.moveCursorModifyingSelection(movement)
        : view.moveCursor(movement));
  }

  void _handleHidKey(int hidUsage, Modifiers modifiers) {
    if (hidUsage == 0x2A) {
      // Keyboard DELETE (Backspace)
      viewProxy.then((view) => view.deleteBackward());
    } else if (hidUsage == 0x28) {
      // Keyboard Return (ENTER)
      viewProxy.then((view) => view.insertNewline());
    } else if (modifiers.ctrl && hidUsage == 0x04) {
      // Keyboard a
      _doMovement(Movement.beginningOfParagraph, false);
    } else if (modifiers.ctrl && hidUsage == 0x08) {
      // Keyboard e
      _doMovement(Movement.endOfParagraph, false);
    } else if (modifiers.ctrl && hidUsage == 0x0E) {
      // Keyboard k
      viewProxy.then((view) => view.kill());
    } else if (modifiers.ctrl && hidUsage == 0x17) {
      // Keyboard t
      viewProxy.then((view) => view.transpose());
    } else if (modifiers.ctrl && hidUsage == 0x1C) {
      // Keyboard y
      viewProxy.then((view) => view.yank());
    } else if (modifiers.ctrl && hidUsage == 0x1D) {
      // Keyboard z
      if (modifiers.shift) {
        viewProxy.then((view) => view.redo());
      } else {
        viewProxy.then((view) => view.undo());
      }
    } else if (hidUsage == 0x50) {
      // Keyboard LeftArrow
      _doMovement(Movement.left, modifiers.shift);
    } else if (hidUsage == 0x4F) {
      // keyboard RightArrow
      _doMovement(Movement.right, modifiers.shift);
    } else if (hidUsage == 0x52) {
      // Keyboard UpArrow
      _doMovement(Movement.up, modifiers.shift);
    } else if (hidUsage == 0x51) {
      // Keyboard DownArrow
      _doMovement(Movement.down, modifiers.shift);
    } else if (modifiers.altRight && hidUsage == 0x04) {
      // altgr-a inserts emoji, to test unicode ability
      viewProxy.then((view) => view.insert('\u{1f601}'));
    } else if (modifiers.altRight && hidUsage == 0x0f) {
      // altgr-l inserts arabic lam, to test bidi ability
      viewProxy.then((view) => view.insert('\u{0644}'));
    }
  }

  void _handleCodePoint(int codePoint) {
    if (codePoint == 9) {
      widget.document.insert('\t');
      // fixme: show tab correctly
    } else if (codePoint == 13) {
      widget.document.insert('\n');
    } else {
      String chars = String.fromCharCode(codePoint);
      widget.document.insert(chars);
    }
  }

  void _handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      log.info(
          'physicalKey=${event.physicalKey}, logicalKey=${event.logicalKey}');
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {}

      RawKeyEventData data = event.data;

      // mytodo: remove Android and Fuchsia
      if (data is RawKeyEventDataAndroid) {
        log.info(
            'codePoint=${data.codePoint}, metaState=${data.metaState}, keyCode=${data.keyCode}');
        var modifiers = Modifiers.fromAndroid(data.metaState);
        if (data.codePoint != 0) {
          _handleCodePoint(data.codePoint);
        } else {
          int _hidKey = keyCodeFromAndroid(data.keyCode);
          _handleHidKey(_hidKey, modifiers);
        }
      } else if (data is RawKeyEventDataFuchsia) {
        log.info(
            'codePoint=${data.codePoint}, modifiers=${data.modifiers}, hidUsage=${data.hidUsage}');
        var modifiers = Modifiers.fromFuchsia(data.modifiers);
        if (data.codePoint != 0 && !modifiers.ctrl) {
          _handleCodePoint(data.codePoint);
        } else {
          _handleHidKey(data.hidUsage, modifiers);
        }
      } else if (data is RawKeyEventDataMacOs) {
        var codePoint = data.charactersIgnoringModifiers.runes.first;
        var modifiers = Modifiers.fromMac(data.modifiers);
        log.info(
            '''charactersIgnoringModifiers=${data.charactersIgnoringModifiers},
               characters=${data.characters},
               _isUnprintableKey=${_isUnprintableKey(data.charactersIgnoringModifiers)},
               runes=${data.charactersIgnoringModifiers.runes},
               codePoint=$codePoint,
               modifiers=${data.modifiers},
               keyCode=${data.keyCode}
               logicalKey=${data.logicalKey}''');

        // mytodo: Handle other keys
        if (data.modifiers == 0) {
          if (codePoint == 9) {
            widget.document.insert('\t');
            // fixme: show tab correctly
          } else if (codePoint == 13) {
            widget.document.insert('\n');
          } else if (data.logicalKey == LogicalKeyboardKey.backspace) {
            widget.document.deleteBackward();
          } else {
            String chars = String.fromCharCode(codePoint);
            widget.document.insert(chars);
          }
        } else {
          int _hidKey = keyCodeFromAndroid(data.keyCode);
          _handleHidKey(_hidKey, modifiers);
        }
        // String chars = String.fromCharCode(codePoint);
        // widget.document.insert(chars);
        // viewProxy.then((view) => view.insert(chars));
        //
        // var modifiers = Modifiers.fromFuchsia(data.modifiers);
        // if (codePoint != 0 && !modifiers.ctrl) {
        //   _handleCodePoint(codePoint, modifiers);
        // } else {
        //   _handleHidKey(data.hidUsage, modifiers);
        // }
      }
    }
  }

  /// Returns true if the given label represents an unprintable key.
  ///
  /// Examples of unprintable keys are "NSUpArrowFunctionKey = 0xF700"
  /// or "NSHomeFunctionKey = 0xF729".
  ///
  /// See <https://developer.apple.com/documentation/appkit/1535851-function-key_unicodes?language=objc> for more
  /// information.
  ///
  /// Used by [RawKeyEvent] subclasses to help construct IDs.
  static bool _isUnprintableKey(String label) {
    if (label.length != 1) {
      return false;
    }
    final int codeUnit = label.codeUnitAt(0);
    return codeUnit >= 0xF700 && codeUnit <= 0xF8FF;
  }

  void _requestKeyboard() {
    _focusNode.requestFocus();
  }

  LineCol _getLineColFromGlobal(Offset globalPosition) {
    RenderBox renderObject = context.findRenderObject() as RenderBox;
    Offset local = renderObject.globalToLocal(globalPosition);
    double x = local.dx;
    double y = local.dy + _controller.offset;
    int line = y ~/ _lineHeight;
    int col = 0;
    Line? text = widget.document.lines.getLine(line);
    if (text != null) {
      col = _utf16ToUtf8Offset(text.text.text!, text.getIndexForHorizontal(x));
    }
    return LineCol(line: line, col: col);
  }

  void _handleTapDown(TapDownDetails details) {
    _requestKeyboard();
    _lastTapLocation = _getLineColFromGlobal(details.globalPosition);
    GestureType gestureType = GestureType.pointSelect;
    var lastTapLocation = _lastTapLocation;
    if (lastTapLocation != null) {
      viewProxy.then((view) =>
          view.gesture(lastTapLocation.line, lastTapLocation.col, gestureType));
    }
  }

  void _handleLongPress() {
    var lastTapLocation = _lastTapLocation;
    if (lastTapLocation != null) {
      GestureType gestureType = GestureType.pointSelect;
      viewProxy.then((view) =>
          view.gesture(lastTapLocation.line, lastTapLocation.col, gestureType));
    }
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    LineCol lineCol = _getLineColFromGlobal(details.globalPosition);
    viewProxy.then((view) => view.drag(lineCol.line, lineCol.col));
  }

  void _sendScrollViewport() {
    if (_controller.hasClients) {
      ScrollPosition pos = _controller.position;
      int viewHeight = 1 + pos.viewportDimension ~/ _lineHeight;
      if (viewHeight == 1) {
        // TODO: horrible hack, remove when we reliably get viewport height
        viewHeight = 42;
      }
      int start = pos.pixels ~/ _lineHeight;
      // TODO: be less noisy, send only if changed
      viewProxy.then((view) => view.scroll(start, start + viewHeight));
      log.info('sending scroll $start $viewHeight');
    }
  }

  TextLine _itemBuilder(BuildContext ctx, int ix) {
    Line? line = widget.document.lines.getLine(ix);
    if (line == null) {
      viewProxy.then((view) => view.requestLines(ix, ix + 1));
    }
    return TextLine(
      // TODO: the string '[invalid]' is debug painting, replace with actual UX.
      line?.text ??
          TextSpan(text: '[invalid]', style: widget.document.lines.style),
      line?.cursor,
      line?.styles,
      _lineHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    _focusAttachment.reparent();

    final Widget lines = ListView.builder(
      itemExtent: _lineHeight,
      itemCount: widget.document.lines.height,
      itemBuilder: _itemBuilder,
      controller: _controller,
    );

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKey,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onLongPress: _handleLongPress,
        onHorizontalDragUpdate: _handleHorizontalDragUpdate,
        behavior: HitTestBehavior.opaque,
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: (ScrollUpdateNotification update) {
            _sendScrollViewport();
            return true;
          },
          child: Container(
            color: Colors.white,
            constraints: BoxConstraints.expand(),
            child: widget.debugBackground ? _makeDebugBackground(lines) : lines,
          ),
        ),
      ),
    );
  }
}

/// Convert a UTF-16 offset within a string to the corresponding UTF-8 offset
int _utf16ToUtf8Offset(String s, int utf16Offset) {
  int utf8Ix = 0;
  int utf16Ix = 0;
  while (utf16Ix < utf16Offset) {
    int codeUnit = s.codeUnitAt(utf16Ix);
    if (codeUnit < 0x80) {
      utf8Ix += 1;
    } else if (codeUnit < 0x800) {
      utf8Ix += 2;
    } else if (codeUnit >= 0xDC00 && codeUnit < 0xE000) {
      // We count the leading surrogate as 3, trailing as 1, total 4
      utf8Ix += 1;
    } else {
      utf8Ix += 3;
    }
    utf16Ix++;
  }
  return utf8Ix;
}

/// Creates a new widget with the editor overlayed on a watermarked background
Widget _makeDebugBackground(Widget editor) {
  return Stack(children: <Widget>[
    Container(
        constraints: BoxConstraints.expand(),
        child: Center(
            child: Transform.rotate(
          angle: -math.pi / 6.0,
          child: Text('moon',
              style: TextStyle(
                  fontSize: 144.0,
                  color: Colors.pink[50],
                  fontWeight: FontWeight.w800)),
        ))),
    editor,
  ]);
}
