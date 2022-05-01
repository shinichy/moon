import 'dart:async';
import 'client.dart';
import 'core_interface.dart';
import 'handler_adapter.dart';
import 'handler_interface.dart';
import 'view_impl.dart';
import 'view_interface.dart';
import 'dart:math';

// mytodo: Replace this class with custom dart implementation.
/// An implementation of [XiCoreProxy] wrapping any [XiClient].
class CoreProxy implements XiCoreProxy {
  final XiClient _inner;

  CoreProxy(this._inner);

  set handler(XiHandler handler) {
    _inner.handler = XiHandlerAdapter(handler);
  }

  // @override
  // XiViewProxy view(String viewId) {
  //   return ViewProxy(_inner, viewId);
  // }
  //
  // @override
  // Future<Null> clientStarted() {
  //   return _inner.init().then((Null _) {
  //     _inner.sendNotification('client_started', <String, dynamic>{});
  //   });
  // }

  // @override
  // String newView() {
  //   return getRandomString(15);
  // }
  //
  // @override
  // void closeView(String viewId) {
  //   Map<String, dynamic> params = <String, dynamic>{
  //     'view_id': viewId,
  //   };
  //   _inner.sendNotification('close_view', params);
  // }
  //
  // @override
  // void save(String viewId, {String? path}) {
  //   Map<String, dynamic> params = <String, dynamic>{
  //     'view_id': viewId,
  //   };
  //   if (path != null) {
  //     params['file_path'] = path;
  //   }
  //   _inner.sendNotification('save', params);
  // }
}
