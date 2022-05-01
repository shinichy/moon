// import 'dart:async';
// import 'package:xi_client/client.dart';
// import 'package:rope/rope.dart';
//
// import '../client.dart';
// import '../core_interface.dart';
// import '../handler_adapter.dart';
// import '../handler_interface.dart';
// import '../view_impl.dart';
// import '../view_interface.dart';
//
// // mytodo: Replace this class with custom dart implementation.
// /// An implementation of [XiCoreProxy] wrapping any [XiClient].
// class XiCore implements XiCoreProxy {
//   XiCore();
//
//   set handler(XiHandler handler) {
//     // _inner.handler = XiHandlerAdapter(handler);
//   }
//
//   @override
//   XiViewProxy view(String viewId) {
//     return ViewProxy(_inner, viewId);
//   }
//
//   @override
//   Future<void> clientStarted() {
//     // do some initialization;
//     return Future.value();
//   }
//
//   @override
//   Future<String> newView() {
//     var rope = Rope.from("");
//     // return _inner.sendRpc('new_view', <String, dynamic>{}).then((data) => data);
//   }
//
//   @override
//   void closeView(String viewId) {
//     Map<String, dynamic> params = <String, dynamic>{
//       'view_id': viewId,
//     };
//     _inner.sendNotification('close_view', params);
//   }
//
//   @override
//   void save(String viewId, {String? path}) {
//     Map<String, dynamic> params = <String, dynamic>{
//       'view_id': viewId,
//     };
//     if (path != null) {
//       params['file_path'] = path;
//     }
//     _inner.sendNotification('save', params);
//   }
// }
