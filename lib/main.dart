import 'package:flutter/material.dart';

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

class CodeEditor extends StatelessWidget {
  const CodeEditor({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(3.0),
        child: SizedBox.expand(
          child: TextField(
            decoration: null,
            keyboardType: TextInputType.multiline,
            maxLines: null,
          ),
        ),
      ),
    );
  }
}
