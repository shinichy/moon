import 'package:flutter/material.dart';

import 'DummySyntaxHighlighter.dart';
import 'rich_code_controller.dart';
import 'rich_code_field.dart';
import 'syntaxt_highlighter_base.dart';

void main() => runApp(const MoonApp());

class MoonApp extends StatelessWidget {
  const MoonApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const appTitle = 'Moon';
    return MaterialApp(
      title: appTitle,
      home: Scaffold(
        body: CodeEditor(),
      ),
    );
  }
}

class CodeEditor extends StatefulWidget {
  @override
  CodeEditorState createState() => CodeEditorState();
}

class CodeEditorState extends State<CodeEditor> {
  late RichCodeEditingController _rec;
  late SyntaxHighlighterBase _syntaxHighlighterBase;

  @override
  void initState() {
    super.initState();
    _syntaxHighlighterBase = DummySyntaxHighlighter();
    _rec = RichCodeEditingController(_syntaxHighlighterBase, text: '');
  }

  @override
  void dispose() {
    //_richTextFieldState.currentState?.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(3.0),
        child: SizedBox.expand(
          child: RichCodeField(
            controller: _rec,
            decoration: null,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            syntaxHighlighter: _syntaxHighlighterBase,
          ),
        ),
      ),
    );
  }
}
