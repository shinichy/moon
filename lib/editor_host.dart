// import 'package:flutter/material.dart';
// import 'package:xi_client/client.dart';
// import 'package:logging/logging.dart';
//
// import 'document.dart';
// import 'editor.dart';
//
// final log = Logger('EditorHostLogger');
//
// /// Widget that embeds a single [Editor].
// class EditorHost extends StatefulWidget {
//
//   /// If `true`, draws a watermark on the editor view.
//   final bool debugBackground;
//
//   const EditorHost({
//     this.debugBackground = false,
//     Key? key,
//   })  : super(key: key);
//
//   @override
//   State<EditorHost> createState() => EditorHostState();
// }
//
// /// State for XiApp.
// class EditorHostState extends State<EditorHost> {
//   final Document _document = Document();
//
//   EditorHostState();
//
//   @override
//   void initState() {
//     super.initState();
//   }
//
//   /// Uses a [MaterialApp] as the root of the Xi UI hierarchy.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Xi',
//       home: Material(
//         // required for the debug background to render correctly
//         type: MaterialType.transparency,
//         child: Container(
//           constraints: BoxConstraints.expand(),
//           color: Colors.white,
//           child: Editor(
//               document: _document, debugBackground: widget.debugBackground),
//         ),
//       ),
//     );
//   }
// }
