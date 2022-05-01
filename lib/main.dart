import 'package:flutter/material.dart';
import 'package:moon/test_data.dart';

import 'editor_tabs.dart';
import 'my_text_field.dart';
import 'package:logging/logging.dart';

void main() {
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(const MoonApp());
}

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
          // child: MyTextField(
          //   controller: TextEditingController(text: TestData.text),
          //   decoration: null,
          //   keyboardType: TextInputType.multiline,
          //   maxLines: null,
          // ),
          child: EditorTabs(),
        ),
      ),
    );
  }
}
