import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'document.dart';
import 'editor.dart';

final log = Logger('EditorTabsLogger');

/// Widget that displays multiple editors in a tab view.
class EditorTabs extends StatefulWidget {
  // final CoreProxy coreProxy;
  final bool debugBackground;

  const EditorTabs({
    // required this.coreProxy,
    Key? key,
  })  : debugBackground = false,
        super(key: key);

  @override
  State<EditorTabs> createState() => EditorTabsState();
}

class EditorTabsState extends State<EditorTabs> with TickerProviderStateMixin {
  /// the order of views as displayed in tabs
  final List<String> _viewIds = [];

  final Map<String, Document> _documents = {};

  /// We display "Untitled 1" in the tab instead of an internal view id
  final Map<String, String> _fakeDocumentTitles = {};

  int _nextDocumentTitleNumber = 1;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: 0);
    newView();
    // widget.coreProxy.clientStarted().then((_) => newView());
  }

  static const _chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  static final math.Random _rnd = math.Random();

  static String _getRandomString(int length) =>
      String.fromCharCodes(Iterable.generate(
          length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  void newView() {
    var viewId = _getRandomString(15);
    setState(() {
      _viewIds.add(viewId);
      _fakeDocumentTitles[viewId] = 'Untitled $_nextDocumentTitleNumber';
      _nextDocumentTitleNumber += 1;
      _documents.putIfAbsent(viewId, () => Document());
      // _documents[viewId]?.finalizeViewProxy(widget.coreProxy.view(viewId));
      int prevIndex = _tabController.index;
      _tabController = TabController(
          vsync: this, length: _viewIds.length, initialIndex: prevIndex);
      // Workaround to avoid "Build scheduled during frame" error
      Future.delayed(Duration(milliseconds: 100), () {
        _tabController.index = _viewIds.length - 1;
      });
    });
  }

  void closeView(String viewId) {
    setState(() {
      log.info('closing $viewId, views: $_viewIds');
      // widget.coreProxy.closeView(viewId);
      _viewIds.remove(viewId);
      _documents.remove(viewId);
      int prevIndex = _tabController.index;
      _tabController = TabController(
          vsync: this,
          length: _viewIds.length,
          initialIndex: math.max(0, math.min(prevIndex, _viewIds.length - 1)));
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> actions = [
      IconButton(icon: Icon(Icons.add), onPressed: newView)
    ];
    if (_viewIds.length > 1) {
      actions.add(IconButton(
          icon: Icon(Icons.remove),
          onPressed: () => closeView(_viewIds[_tabController.index])));
    }

    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.pink[300],
      ),
      home: Scaffold(
        appBar: AppBar(
          actions: actions,
          bottom: _viewIds.length > 1
              ? TabBar(
                  indicatorColor: Colors.white,
                  indicatorWeight: 4.0,
                  labelStyle: TextStyle(fontSize: 16.0),
                  isScrollable: true,
                  controller: _tabController,
                  tabs: _viewIds
                      .map((id) => Tab(text: _fakeDocumentTitles[id]))
                      .toList(),
                )
              : null,
        ),
        body: makeMainWidget(),
      ),
    );
  }

  Widget makeMainWidget() {
    if (_viewIds.isEmpty) {
      return Container();
    }

    if (_documents.length == 1) {
      return Editor(
          document: _documents[_viewIds[0]]!,
          key: Key(_viewIds[0]),
          debugBackground: widget.debugBackground);
    }

    return TabBarView(
      physics: NeverScrollableScrollPhysics(),
      controller: _tabController,
      children: _viewIds.map((id) {
        return Editor(
          document: _documents[id]!,
          key: Key(id),
          debugBackground: widget.debugBackground,
        );
      }).toList(),
    );
  }
}
