// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'my_scroll_context.dart';

export 'package:flutter/physics.dart' show Tolerance;

/// Signature used by [MyScrollable] to build the viewport through which the
/// scrollable content is displayed.
typedef ViewportBuilder = Widget Function(BuildContext context, ViewportOffset horizontalPosition, ViewportOffset verticalPosition);

/// A widget that scrolls.
///
/// [MyScrollable] implements the interaction model for a scrollable widget,
/// including gesture recognition, but does not have an opinion about how the
/// viewport, which actually displays the children, is constructed.
///
/// It's rare to construct a [MyScrollable] directly. Instead, consider [ListView]
/// or [GridView], which combine scrolling, viewporting, and a layout model. To
/// combine layout models (or to use a custom layout mode), consider using
/// [CustomScrollView].
///
/// The static [MyScrollable.of] and [MyScrollable.ensureVisible] functions are
/// often used to interact with the [MyScrollable] widget inside a [ListView] or
/// a [GridView].
///
/// To further customize scrolling behavior with a [Scrollable]:
///
/// 1. You can provide a [viewportBuilder] to customize the child model. For
///    example, [SingleChildScrollView] uses a viewport that displays a single
///    box child whereas [CustomScrollView] uses a [Viewport] or a
///    [ShrinkWrappingViewport], both of which display a list of slivers.
///
/// 2. You can provide a custom [ScrollController] that creates a custom
///    [ScrollPosition] subclass. For example, [PageView] uses a
///    [PageController], which creates a page-oriented scroll position subclass
///    that keeps the same page visible when the [Scrollable] resizes.
///
/// See also:
///
///  * [ListView], which is a commonly used [ScrollView] that displays a
///    scrolling, linear list of child widgets.
///  * [PageView], which is a scrolling list of child widgets that are each the
///    size of the viewport.
///  * [GridView], which is a [ScrollView] that displays a scrolling, 2D array
///    of child widgets.
///  * [CustomScrollView], which is a [ScrollView] that creates custom scroll
///    effects using slivers.
///  * [SingleChildScrollView], which is a scrollable widget that has a single
///    child.
///  * [ScrollNotification] and [NotificationListener], which can be used to watch
///    the scroll position without using a [ScrollController].
class MyScrollable extends StatefulWidget {
  /// Creates a widget that scrolls.
  ///
  /// The [horizontalAxisDirection] and [viewportBuilder] arguments must not be null.
  const MyScrollable({
    Key? key,
    this.horizontalAxisDirection = AxisDirection.right,
    this.verticalAxisDirection = AxisDirection.down,
    this.horizontalController,
    this.verticalController,
    this.physics,
    required this.viewportBuilder,
    this.incrementCalculator,
    this.excludeFromSemantics = false,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.restorationId,
    this.scrollBehavior,
  }) : assert(horizontalAxisDirection != null),
        assert(verticalAxisDirection != null),
        assert(dragStartBehavior != null),
        assert(viewportBuilder != null),
        assert(excludeFromSemantics != null),
        assert(semanticChildCount == null || semanticChildCount >= 0),
        super (key: key);

  /// The horizontal direction in which this widget scrolls.
  ///
  /// For example, if [horizontalAxisDirection] is
  /// [AxisDirection.right], increasing the scroll position will cause content
  /// beyond the right edge of the viewport to become visible through the
  /// viewport.
  ///
  /// Defaults to [AxisDirection.right].
  final AxisDirection horizontalAxisDirection;

  /// The vertical direction in which this widget scrolls.
  ///
  /// For example, if the [verticalAxisDirection] is [AxisDirection.down], increasing
  /// the scroll position will cause content below the bottom of the viewport to
  /// become visible through the viewport.
  ///
  /// Defaults to [AxisDirection.down].
  final AxisDirection verticalAxisDirection;

  /// An object that can be used to control the horizontal position to which this widget is
  /// scrolled.
  ///
  /// A [ScrollController] serves several purposes. It can be used to control
  /// the initial scroll position (see [ScrollController.initialScrollOffset]).
  /// It can be used to control whether the scroll view should automatically
  /// save and restore its scroll position in the [PageStorage] (see
  /// [ScrollController.keepScrollOffset]). It can be used to read the current
  /// scroll position (see [ScrollController.offset]), or change it (see
  /// [ScrollController.animateTo]).
  ///
  /// See also:
  ///
  ///  * [ensureVisible], which animates the scroll position to reveal a given
  ///    [BuildContext].
  final ScrollController? horizontalController;

  /// An object that can be used to control the vertical position to which this widget is
  /// scrolled.
  ///
  /// A [ScrollController] serves several purposes. It can be used to control
  /// the initial scroll position (see [ScrollController.initialScrollOffset]).
  /// It can be used to control whether the scroll view should automatically
  /// save and restore its scroll position in the [PageStorage] (see
  /// [ScrollController.keepScrollOffset]). It can be used to read the current
  /// scroll position (see [ScrollController.offset]), or change it (see
  /// [ScrollController.animateTo]).
  ///
  /// See also:
  ///
  ///  * [ensureVisible], which animates the scroll position to reveal a given
  ///    [BuildContext].
  final ScrollController? verticalController;

  /// How the widgets should respond to user input.
  ///
  /// For example, determines how the widget continues to animate after the
  /// user stops dragging the scroll view.
  ///
  /// Defaults to matching platform conventions via the physics provided from
  /// the ambient [ScrollConfiguration].
  ///
  /// If an explicit [ScrollBehavior] is provided to [scrollBehavior], the
  /// [ScrollPhysics] provided by that behavior will take precedence after
  /// [physics].
  ///
  /// The physics can be changed dynamically, but new physics will only take
  /// effect if the _class_ of the provided object changes. Merely constructing
  /// a new instance with a different configuration is insufficient to cause the
  /// physics to be reapplied. (This is because the final object used is
  /// generated dynamically, which can be relatively expensive, and it would be
  /// inefficient to speculatively create this object each frame to see if the
  /// physics should be updated.)
  ///
  /// See also:
  ///
  ///  * [AlwaysScrollableScrollPhysics], which can be used to indicate that the
  ///    scrollable should react to scroll requests (and possible overscroll)
  ///    even if the scrollable's contents fit without scrolling being necessary.
  final ScrollPhysics? physics;

  /// Builds the viewport through which the scrollable content is displayed.
  ///
  /// A typical viewport uses the given [ViewportOffset] to determine which part
  /// of its content is actually visible through the viewport.
  ///
  /// See also:
  ///
  ///  * [Viewport], which is a viewport that displays a list of slivers.
  ///  * [ShrinkWrappingViewport], which is a viewport that displays a list of
  ///    slivers and sizes itself based on the size of the slivers.
  final ViewportBuilder viewportBuilder;

  /// An optional function that will be called to calculate the distance to
  /// scroll when the scrollable is asked to scroll via the keyboard using a
  /// [ScrollAction].
  ///
  /// If not supplied, the [MyScrollable] will scroll a default amount when a
  /// keyboard navigation key is pressed (e.g. pageUp/pageDown, control-upArrow,
  /// etc.), or otherwise invoked by a [ScrollAction].
  ///
  /// If [incrementCalculator] is null, the default for
  /// [ScrollIncrementType.page] is 80% of the size of the scroll window, and
  /// for [ScrollIncrementType.line], 50 logical pixels.
  final ScrollIncrementCalculator? incrementCalculator;

  /// Whether the scroll actions introduced by this [MyScrollable] are exposed
  /// in the semantics tree.
  ///
  /// Text fields with an overflow are usually scrollable to make sure that the
  /// user can get to the beginning/end of the entered text. However, these
  /// scrolling actions are generally not exposed to the semantics layer.
  ///
  /// See also:
  ///
  ///  * [GestureDetector.excludeFromSemantics], which is used to accomplish the
  ///    exclusion.
  final bool excludeFromSemantics;

  /// The number of children that will contribute semantic information.
  ///
  /// The value will be null if the number of children is unknown or unbounded.
  ///
  /// Some subtypes of [ScrollView] can infer this value automatically. For
  /// example [ListView] will use the number of widgets in the child list,
  /// while the [new ListView.separated] constructor will use half that amount.
  ///
  /// For [CustomScrollView] and other types which do not receive a builder
  /// or list of widgets, the child count must be explicitly provided.
  ///
  /// See also:
  ///
  ///  * [CustomScrollView], for an explanation of scroll semantics.
  ///  * [SemanticsConfiguration.scrollChildCount], the corresponding semantics property.
  final int? semanticChildCount;

  // TODO(jslavitz): Set the DragStartBehavior default to be start across all widgets.
  /// {@template flutter.widgets.scrollable.dragStartBehavior}
  /// Determines the way that drag start behavior is handled.
  ///
  /// If set to [DragStartBehavior.start], scrolling drag behavior will
  /// begin at the position where the drag gesture won the arena. If set to
  /// [DragStartBehavior.down] it will begin at the position where a down
  /// event is first detected.
  ///
  /// In general, setting this to [DragStartBehavior.start] will make drag
  /// animation smoother and setting it to [DragStartBehavior.down] will make
  /// drag behavior feel slightly more reactive.
  ///
  /// By default, the drag start behavior is [DragStartBehavior.start].
  ///
  /// See also:
  ///
  ///  * [DragGestureRecognizer.dragStartBehavior], which gives an example for
  ///    the different behaviors.
  ///
  /// {@endtemplate}
  final DragStartBehavior dragStartBehavior;

  /// {@template flutter.widgets.scrollable.restorationId}
  /// Restoration ID to save and restore the scroll offset of the scrollable.
  ///
  /// If a restoration id is provided, the scrollable will persist its current
  /// scroll offset and restore it during state restoration.
  ///
  /// The scroll offset is persisted in a [RestorationBucket] claimed from
  /// the surrounding [RestorationScope] using the provided restoration ID.
  ///
  /// See also:
  ///
  ///  * [RestorationManager], which explains how state restoration works in
  ///    Flutter.
  /// {@endtemplate}
  final String? restorationId;

  /// {@macro flutter.widgets.shadow.scrollBehavior}
  ///
  /// [ScrollBehavior]s also provide [ScrollPhysics]. If an explicit
  /// [ScrollPhysics] is provided in [physics], it will take precedence,
  /// followed by [scrollBehavior], and then the inherited ancestor
  /// [ScrollBehavior].
  final ScrollBehavior? scrollBehavior;

  /// The horizontal axis along which the scroll view scrolls.
  ///
  /// Determined by the [horizontalAxisDirection].
  Axis get horizontalAxis => axisDirectionToAxis(horizontalAxisDirection);

  /// The vertical axis along which the scroll view scrolls.
  ///
  /// Determined by the [verticalAxisDirection].
  Axis get verticalAxis => axisDirectionToAxis(verticalAxisDirection);

  @override
  MyScrollableState createState() => MyScrollableState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<AxisDirection>('axisDirection', horizontalAxisDirection));
    properties.add(DiagnosticsProperty<ScrollPhysics>('physics', physics));
    properties.add(StringProperty('restorationId', restorationId));
  }

  /// The state from the closest instance of this class that encloses the given context.
  ///
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// ScrollableState scrollable = Scrollable.of(context);
  /// ```
  ///
  /// Calling this method will create a dependency on the closest [MyScrollable]
  /// in the [context], if there is one.
  static MyScrollableState? of(BuildContext context) {
    final _ScrollableScope? widget = context.dependOnInheritedWidgetOfExactType<_ScrollableScope>();
    return widget?.scrollable;
  }

  /// Provides a heuristic to determine if expensive frame-bound tasks should be
  /// deferred for the [context] at a specific point in time.
  ///
  /// Calling this method does _not_ create a dependency on any other widget.
  /// This also means that the value returned is only good for the point in time
  /// when it is called, and callers will not get updated if the value changes.
  ///
  /// The heuristic used is determined by the [physics] of this [MyScrollable]
  /// via [ScrollPhysics.recommendDeferredLoading]. That method is called with
  /// the current [ScrollPosition.activity]'s [ScrollActivity.velocity].
  ///
  /// If there is no [MyScrollable] in the widget tree above the [context], this
  /// method returns false.
  static bool recommendDeferredLoadingForContext(BuildContext context) {
    final _ScrollableScope? widget = context.getElementForInheritedWidgetOfExactType<_ScrollableScope>()?.widget as _ScrollableScope?;
    if (widget == null) {
      return false;
    }
    return widget.horizontalPosition.recommendDeferredLoading(context);
  }

  /// Scrolls the scrollables that enclose the given context so as to make the
  /// given context visible.
  static Future<void> ensureVisible(
      BuildContext context, {
        double alignment = 0.0,
        Duration duration = Duration.zero,
        Curve curve = Curves.ease,
        ScrollPositionAlignmentPolicy alignmentPolicy = ScrollPositionAlignmentPolicy.explicit,
      }) {
    final List<Future<void>> futures = <Future<void>>[];

    // The `targetRenderObject` is used to record the first target renderObject.
    // If there are multiple scrollable widgets nested, we should let
    // the `targetRenderObject` as visible as possible to improve the user experience.
    // Otherwise, let the outer renderObject as visible as possible maybe cause
    // the `targetRenderObject` invisible.
    // Also see https://github.com/flutter/flutter/issues/65100
    RenderObject? targetRenderObject;
    MyScrollableState? scrollable = MyScrollable.of(context);
    while (scrollable != null) {
      futures.add(scrollable.horizontalPosition.ensureVisible(
        context.findRenderObject()!,
        alignment: alignment,
        duration: duration,
        curve: curve,
        alignmentPolicy: alignmentPolicy,
        targetRenderObject: targetRenderObject,
      ));
      futures.add(scrollable.verticalPosition.ensureVisible(
        context.findRenderObject()!,
        alignment: alignment,
        duration: duration,
        curve: curve,
        alignmentPolicy: alignmentPolicy,
        targetRenderObject: targetRenderObject,
      ));

      targetRenderObject = targetRenderObject ?? context.findRenderObject();
      context = scrollable.context;
      scrollable = MyScrollable.of(context);
    }

    if (futures.isEmpty || duration == Duration.zero)
      return Future<void>.value();
    if (futures.length == 1)
      return futures.single;
    return Future.wait<void>(futures).then<void>((List<void> _) => null);
  }
}

// Enable Scrollable.of() to work as if ScrollableState was an inherited widget.
// ScrollableState.build() always rebuilds its _ScrollableScope.
class _ScrollableScope extends InheritedWidget {
  const _ScrollableScope({
    Key? key,
    required this.scrollable,
    required this.horizontalPosition,
    required this.verticalPosition,
    required Widget child,
  }) : assert(scrollable != null),
        assert(child != null),
        super(key: key, child: child);

  final MyScrollableState scrollable;
  final ScrollPosition horizontalPosition;
  final ScrollPosition verticalPosition;

  @override
  bool updateShouldNotify(_ScrollableScope old) {
    return horizontalPosition != old.horizontalPosition || verticalPosition != old.verticalPosition;
  }
}

class MySingleScrollableState implements ScrollContext {
  final AxisDirection _axisDirection;
  final MyScrollableState _parentState;

  MySingleScrollableState(this._parentState, this._axisDirection);

  @override
  AxisDirection get axisDirection => _axisDirection;

  @override
  BuildContext? get notificationContext => _parentState._gestureDetectorKey.currentContext;

  @override
  void saveOffset(double offset) {
    switch (axisDirection) {
      case AxisDirection.up:
      case AxisDirection.down:
        _parentState.saveOffsets(_parentState.horizontalPosition.pixels, offset);
        break;
      case AxisDirection.right:
      case AxisDirection.left:
        _parentState.saveOffsets(offset, _parentState.verticalPosition.pixels);
        break;
    }
  }

  @override
  void setCanDrag(bool value) {
    _parentState.setCanDrag(value);
  }

  @override
  void setIgnorePointer(bool value) {
    _parentState.setIgnorePointer(value);
  }

  @override
  void setSemanticsActions(Set<SemanticsAction> actions) {
    _parentState.setSemanticsActions(actions);
  }

  @override
  BuildContext get storageContext => _parentState.storageContext;

  @override
  TickerProvider get vsync => _parentState.vsync;
}

/// State object for a [MyScrollable] widget.
///
/// To manipulate a [MyScrollable] widget's scroll position, use the object
/// obtained from the [horizontalPosition] and [verticalPosition] property.
///
/// To be informed of when a [MyScrollable] widget is scrolling, use a
/// [NotificationListener] to listen for [ScrollNotification] notifications.
///
/// This class is not intended to be subclassed. To specialize the behavior of a
/// [MyScrollable], provide it with a [ScrollPhysics].
class MyScrollableState extends State<MyScrollable> with TickerProviderStateMixin, RestorationMixin
    implements MyScrollContext {
  late MySingleScrollableState _horizontalState;
  late MySingleScrollableState _verticalState;

  /// The manager for this [MyScrollable] widget's horizontal viewport position.
  ///
  /// To control what kind of [ScrollPosition] is created for a [MyScrollable],
  /// provide it with custom [ScrollController] that creates the appropriate
  /// [ScrollPosition] in its [ScrollController.createScrollPosition] method.
  ScrollPosition get horizontalPosition => _horizontalPosition!;
  ScrollPosition? _horizontalPosition;
  
  /// The manager for this [MyScrollable] widget's vertical viewport position.
  ///
  /// To control what kind of [ScrollPosition] is created for a [MyScrollable],
  /// provide it with custom [ScrollController] that creates the appropriate
  /// [ScrollPosition] in its [ScrollController.createScrollPosition] method.
  ScrollPosition get verticalPosition => _verticalPosition!;
  ScrollPosition? _verticalPosition;

  final _RestorableScrollOffsets _persistedScrollOffsets = _RestorableScrollOffsets();

  @override
  AxisDirection get horizontalAxisDirection => widget.horizontalAxisDirection;
  
  @override
  AxisDirection get verticalAxisDirection => widget.verticalAxisDirection;

  late ScrollBehavior _configuration;
  ScrollPhysics? _physics;
  ScrollController? _fallbackHorizontalScrollController;
  ScrollController? _fallbackVerticalScrollController;

  ScrollController get _effectiveHorizontalScrollController => widget.horizontalController ?? _fallbackHorizontalScrollController!;
  
  ScrollController get _effectiveVerticalScrollController => widget.verticalController ?? _fallbackVerticalScrollController!;

  // Only call this from places that will definitely trigger a rebuild.
  void _updateHorizontalPosition() {
    _configuration = widget.scrollBehavior ?? ScrollConfiguration.of(context);
    _physics = _configuration.getScrollPhysics(context);
    if (widget.physics != null) {
      _physics = widget.physics!.applyTo(_physics);
    } else if (widget.scrollBehavior != null) {
      _physics = widget.scrollBehavior!.getScrollPhysics(context).applyTo(_physics);
    }
    final ScrollPosition? oldPosition = _horizontalPosition;
    if (oldPosition != null) {
      _effectiveHorizontalScrollController.detach(oldPosition);
      // It's important that we not dispose the old position until after the
      // viewport has had a chance to unregister its listeners from the old
      // position. So, schedule a microtask to do it.
      scheduleMicrotask(oldPosition.dispose);
    }

    _horizontalPosition = _effectiveHorizontalScrollController.createScrollPosition(_physics!, _horizontalState, oldPosition);
    assert(_horizontalPosition != null);
    _effectiveHorizontalScrollController.attach(horizontalPosition);
  }

  // Only call this from places that will definitely trigger a rebuild.
  void _updateVerticalPosition() {
    _configuration = widget.scrollBehavior ?? ScrollConfiguration.of(context);
    _physics = _configuration.getScrollPhysics(context);
    if (widget.physics != null) {
      _physics = widget.physics!.applyTo(_physics);
    } else if (widget.scrollBehavior != null) {
      _physics = widget.scrollBehavior!.getScrollPhysics(context).applyTo(_physics);
    }
    final ScrollPosition? oldPosition = _verticalPosition;
    if (oldPosition != null) {
      _effectiveVerticalScrollController.detach(oldPosition);
      // It's important that we not dispose the old position until after the
      // viewport has had a chance to unregister its listeners from the old
      // position. So, schedule a microtask to do it.
      scheduleMicrotask(oldPosition.dispose);
    }

    _verticalPosition = _effectiveVerticalScrollController.createScrollPosition(_physics!, _verticalState, oldPosition);
    assert(_verticalPosition != null);
    _effectiveVerticalScrollController.attach(verticalPosition);
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_persistedScrollOffsets, 'offsets');
    assert(_horizontalPosition != null);
    assert(_verticalPosition != null);
    horizontalPosition.restoreOffset(_persistedScrollOffsets.value?.first ?? 0, initialRestore: initialRestore);
    verticalPosition.restoreOffset(_persistedScrollOffsets.value?.last ?? 0, initialRestore: initialRestore);
  }

  @override
  void saveOffsets(double horizontalOffset, double verticalOffset) {
    assert(debugIsSerializableForRestoration(horizontalOffset));
    _persistedScrollOffsets.value = [horizontalOffset, verticalOffset];
    // [saveOffset] is called after a scrolling ends and it is usually not
    // followed by a frame. Therefore, manually flush restoration data.
    ServicesBinding.instance!.restorationManager.flushData();
  }

  @override
  void initState() {
    if (widget.horizontalController == null) {
      _fallbackHorizontalScrollController = ScrollController();
    }
    if (widget.verticalController == null) {
      _fallbackVerticalScrollController = ScrollController();
    }
    _horizontalState = MySingleScrollableState(this, AxisDirection.right);
    _verticalState = MySingleScrollableState(this, AxisDirection.down);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    _updateHorizontalPosition();
    _updateVerticalPosition();
    super.didChangeDependencies();
  }

  bool _shouldUpdateHorizontalPosition(MyScrollable oldWidget) {
    ScrollPhysics? newPhysics = widget.physics ?? widget.scrollBehavior?.getScrollPhysics(context);
    ScrollPhysics? oldPhysics = oldWidget.physics ?? oldWidget.scrollBehavior?.getScrollPhysics(context);
    do {
      if (newPhysics?.runtimeType != oldPhysics?.runtimeType)
        return true;
      newPhysics = newPhysics?.parent;
      oldPhysics = oldPhysics?.parent;
    } while (newPhysics != null || oldPhysics != null);

    return widget.horizontalController?.runtimeType != oldWidget.horizontalController?.runtimeType;
  }

  bool _shouldUpdateVerticalPosition(MyScrollable oldWidget) {
    ScrollPhysics? newPhysics = widget.physics ?? widget.scrollBehavior?.getScrollPhysics(context);
    ScrollPhysics? oldPhysics = oldWidget.physics ?? oldWidget.scrollBehavior?.getScrollPhysics(context);
    do {
      if (newPhysics?.runtimeType != oldPhysics?.runtimeType)
        return true;
      newPhysics = newPhysics?.parent;
      oldPhysics = oldPhysics?.parent;
    } while (newPhysics != null || oldPhysics != null);

    return widget.verticalController?.runtimeType != oldWidget.verticalController?.runtimeType;
  }

  @override
  void didUpdateWidget(MyScrollable oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.horizontalController != oldWidget.horizontalController) {
      if (oldWidget.horizontalController == null) {
        // The old controller was null, meaning the fallback cannot be null.
        // Dispose of the fallback.
        assert(_fallbackHorizontalScrollController !=  null);
        assert(widget.horizontalController != null);
        _fallbackHorizontalScrollController!.detach(horizontalPosition);
        _fallbackHorizontalScrollController!.dispose();
        _fallbackHorizontalScrollController = null;
      } else {
        // The old controller was not null, detach.
        oldWidget.horizontalController?.detach(horizontalPosition);
        if (widget.horizontalController == null) {
          // If the new controller is null, we need to set up the fallback
          // ScrollController.
          _fallbackHorizontalScrollController = ScrollController();
        }
      }
      // Attach the updated effective scroll controller.
      _effectiveHorizontalScrollController.attach(horizontalPosition);
    }

    if (_shouldUpdateHorizontalPosition(oldWidget)) {
      _updateHorizontalPosition();
    }

    if (widget.verticalController != oldWidget.verticalController) {
      if (oldWidget.verticalController == null) {
        // The old controller was null, meaning the fallback cannot be null.
        // Dispose of the fallback.
        assert(_fallbackVerticalScrollController !=  null);
        assert(widget.verticalController != null);
        _fallbackVerticalScrollController!.detach(verticalPosition);
        _fallbackVerticalScrollController!.dispose();
        _fallbackVerticalScrollController = null;
      } else {
        // The old controller was not null, detach.
        oldWidget.verticalController?.detach(verticalPosition);
        if (widget.verticalController == null) {
          // If the new controller is null, we need to set up the fallback
          // ScrollController.
          _fallbackVerticalScrollController = ScrollController();
        }
      }
      // Attach the updated effective scroll controller.
      _effectiveVerticalScrollController.attach(verticalPosition);
    }

    if (_shouldUpdateVerticalPosition(oldWidget)) {
      _updateVerticalPosition();
    }
  }

  @override
  void dispose() {
    if (widget.horizontalController != null) {
      widget.horizontalController!.detach(horizontalPosition);
    } else {
      _fallbackHorizontalScrollController?.detach(horizontalPosition);
      _fallbackHorizontalScrollController?.dispose();
    }
    horizontalPosition.dispose();
    
    if (widget.verticalController != null) {
      widget.verticalController!.detach(verticalPosition);
    } else {
      _fallbackVerticalScrollController?.detach(verticalPosition);
      _fallbackVerticalScrollController?.dispose();
    }
    verticalPosition.dispose();

    _persistedScrollOffsets.dispose();
    super.dispose();
  }


  // SEMANTICS

  final GlobalKey _scrollSemanticsKey = GlobalKey();

  @override
  @protected
  void setSemanticsActions(Set<SemanticsAction> actions) {
    if (_gestureDetectorKey.currentState != null)
      _gestureDetectorKey.currentState!.replaceSemanticsActions(actions);
  }

  // GESTURE RECOGNITION AND POINTER IGNORING

  final GlobalKey<RawGestureDetectorState> _gestureDetectorKey = GlobalKey<RawGestureDetectorState>();
  final GlobalKey _ignorePointerKey = GlobalKey();

  // This field is set during layout, and then reused until the next time it is set.
  Map<Type, GestureRecognizerFactory> _gestureRecognizers = const <Type, GestureRecognizerFactory>{};
  bool _shouldIgnorePointer = false;

  bool? _lastCanDrag;
  Axis? _lastAxisDirection;

  @override
  @protected
  void setCanDrag(bool value) {
    if (value == _lastCanDrag && (!value || widget.horizontalAxis == _lastAxisDirection))
      return;
    if (!value) {
      _gestureRecognizers = const <Type, GestureRecognizerFactory>{};
      // Cancel the active hold/drag (if any) because the gesture recognizers
      // will soon be disposed by our RawGestureDetector, and we won't be
      // receiving pointer up events to cancel the hold/drag.
      _handleDragCancel();
    } else {
      switch (widget.horizontalAxis) {
        case Axis.vertical:
          _gestureRecognizers = <Type, GestureRecognizerFactory>{
            VerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
                  () => VerticalDragGestureRecognizer(supportedDevices: _configuration.dragDevices),
                  (VerticalDragGestureRecognizer instance) {
                instance
                  ..onDown = _handleDragDown
                  ..onStart = _handleDragStart
                  ..onUpdate = _handleDragUpdate
                  ..onEnd = _handleDragEnd
                  ..onCancel = _handleDragCancel
                  ..minFlingDistance = _physics?.minFlingDistance
                  ..minFlingVelocity = _physics?.minFlingVelocity
                  ..maxFlingVelocity = _physics?.maxFlingVelocity
                  ..velocityTrackerBuilder = _configuration.velocityTrackerBuilder(context)
                  ..dragStartBehavior = widget.dragStartBehavior;
              },
            ),
          };
          break;
        case Axis.horizontal:
          _gestureRecognizers = <Type, GestureRecognizerFactory>{
            HorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
                  () => HorizontalDragGestureRecognizer(supportedDevices: _configuration.dragDevices),
                  (HorizontalDragGestureRecognizer instance) {
                instance
                  ..onDown = _handleDragDown
                  ..onStart = _handleDragStart
                  ..onUpdate = _handleDragUpdate
                  ..onEnd = _handleDragEnd
                  ..onCancel = _handleDragCancel
                  ..minFlingDistance = _physics?.minFlingDistance
                  ..minFlingVelocity = _physics?.minFlingVelocity
                  ..maxFlingVelocity = _physics?.maxFlingVelocity
                  ..velocityTrackerBuilder = _configuration.velocityTrackerBuilder(context)
                  ..dragStartBehavior = widget.dragStartBehavior;
              },
            ),
          };
          break;
      }
    }
    _lastCanDrag = value;
    _lastAxisDirection = widget.horizontalAxis;
    if (_gestureDetectorKey.currentState != null)
      _gestureDetectorKey.currentState!.replaceGestureRecognizers(_gestureRecognizers);
  }

  @override
  TickerProvider get vsync => this;

  @override
  @protected
  void setIgnorePointer(bool value) {
    if (_shouldIgnorePointer == value)
      return;
    _shouldIgnorePointer = value;
    if (_ignorePointerKey.currentContext != null) {
      final RenderIgnorePointer renderBox = _ignorePointerKey.currentContext!.findRenderObject()! as RenderIgnorePointer;
      renderBox.ignoring = _shouldIgnorePointer;
    }
  }

  @override
  BuildContext? get notificationContext => _gestureDetectorKey.currentContext;

  @override
  BuildContext get storageContext => context;

  // TOUCH HANDLERS

  Drag? _horizontalDrag;
  Drag? _verticalDrag;
  ScrollHoldController? _horizontalHold;
  ScrollHoldController? _verticalHold;

  void _handleDragDown(DragDownDetails details) {
    assert(_horizontalDrag == null);
    assert(_horizontalHold == null);
    _horizontalHold = horizontalPosition.hold(_disposeHold);
    assert(_verticalHold == null);
    _verticalHold = verticalPosition.hold(_disposeHold);
  }

  void _handleDragStart(DragStartDetails details) {
    // It's possible for _hold to become null between _handleDragDown and
    // _handleDragStart, for example if some user code calls jumpTo or otherwise
    // triggers a new activity to begin.
    assert(_horizontalDrag == null);
    _horizontalDrag = horizontalPosition.drag(details, _disposeDrag);
    assert(_horizontalDrag != null);
    assert(_horizontalHold == null);
    
    assert(_verticalDrag == null);
    _verticalDrag = verticalPosition.drag(details, _disposeDrag);
    assert(_verticalDrag != null);
    assert(_verticalHold == null);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    // _drag might be null if the drag activity ended and called _disposeDrag.
    assert(_horizontalHold == null || _horizontalDrag == null);
    _horizontalDrag?.update(details);
  }

  void _handleDragEnd(DragEndDetails details) {
    // _drag might be null if the drag activity ended and called _disposeDrag.
    assert(_horizontalHold == null || _horizontalDrag == null);
    _horizontalDrag?.end(details);
    assert(_horizontalDrag == null);
  }

  void _handleDragCancel() {
    // _hold might be null if the drag started.
    // _drag might be null if the drag activity ended and called _disposeDrag.
    assert(_horizontalHold == null || _horizontalDrag == null);
    _horizontalHold?.cancel();
    _horizontalDrag?.cancel();
    assert(_horizontalHold == null);
    assert(_horizontalDrag == null);
  }

  void _disposeHold() {
    _horizontalHold = null;
  }

  void _disposeDrag() {
    _horizontalDrag = null;
  }

  // SCROLL WHEEL

  // Returns the horizontal offset that should result from applying [event] to the current
  // position, taking min/max scroll extent into account.
  double _targetHorizontalScrollOffsetForPointerScroll(double delta) {
    return math.min(
      math.max(horizontalPosition.pixels + delta, horizontalPosition.minScrollExtent),
      horizontalPosition.maxScrollExtent,
    );
  }

  // Returns the vertical offset that should result from applying [event] to the current
  // position, taking min/max scroll extent into account.
  double _targetVerticalScrollOffsetForPointerScroll(double delta) {
    return math.min(
      math.max(verticalPosition.pixels + delta, verticalPosition.minScrollExtent),
      verticalPosition.maxScrollExtent,
    );
  }

  // Returns the horizontal delta that should result from applying [event] with 
  // direction taken into account.
  double _horizontalPointerSignalEventDelta(PointerScrollEvent event) {
    double delta = event.scrollDelta.dx;

    if (axisDirectionIsReversed(widget.horizontalAxisDirection)) {
      delta *= -1;
    }
    return delta;
  }

  // Returns the vertical delta that should result from applying [event] with
  // direction taken into account.
  double _verticalPointerSignalEventDelta(PointerScrollEvent event) {
    double delta = event.scrollDelta.dy;

    if (axisDirectionIsReversed(widget.verticalAxisDirection)) {
      delta *= -1;
    }
    return delta;
  }

  void _handlePointerScroll(PointerEvent event) {
    assert(event is PointerScrollEvent);
    final double horizontalDelta = _horizontalPointerSignalEventDelta(event as PointerScrollEvent);
    final double horizontalTargetScrollOffset = _targetHorizontalScrollOffsetForPointerScroll(horizontalDelta);
    if (horizontalDelta != 0.0 && horizontalTargetScrollOffset != horizontalPosition.pixels) {
      horizontalPosition.pointerScroll(horizontalDelta);
    }

    final double verticalDelta = _verticalPointerSignalEventDelta(event as PointerScrollEvent);
    final double verticalTargetScrollOffset = _targetVerticalScrollOffsetForPointerScroll(verticalDelta);
    if (verticalDelta != 0.0 && verticalTargetScrollOffset != verticalPosition.pixels) {
      verticalPosition.pointerScroll(verticalDelta);
    }
  }

  void _receivedPointerSignal(PointerSignalEvent event) {
    // Horizontal
    if (event is PointerScrollEvent && _horizontalPosition != null) {
      if (_physics != null && !_physics!.shouldAcceptUserOffset(horizontalPosition)) {
        return;
      }
      final double delta = _horizontalPointerSignalEventDelta(event);
      final double targetScrollOffset = _targetHorizontalScrollOffsetForPointerScroll(delta);
      // Only express interest in the event if it would actually result in a scroll.
      if (delta != 0.0 && targetScrollOffset != horizontalPosition.pixels) {
        GestureBinding.instance!.pointerSignalResolver.register(event, _handlePointerScroll);
        return;
      }
    }

    // Vertical 
    if (event is PointerScrollEvent && _verticalPosition != null) {
      if (_physics != null && !_physics!.shouldAcceptUserOffset(verticalPosition)) {
        return;
      }
      final double delta = _verticalPointerSignalEventDelta(event);
      final double targetScrollOffset = _targetVerticalScrollOffsetForPointerScroll(delta);
      // Only express interest in the event if it would actually result in a scroll.
      if (delta != 0.0 && targetScrollOffset != verticalPosition.pixels) {
        GestureBinding.instance!.pointerSignalResolver.register(event, _handlePointerScroll);
      }
    }
  }

  bool _handleScrollMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.depth == 0) {
      final RenderObject? scrollSemanticsRenderObject = _scrollSemanticsKey.currentContext?.findRenderObject();
      if (scrollSemanticsRenderObject != null)
        scrollSemanticsRenderObject.markNeedsSemanticsUpdate();
    }
    return false;
  }

  // DESCRIPTION

  @override
  Widget build(BuildContext context) {
    assert(_horizontalPosition != null);
    assert(_verticalPosition != null);
    // _ScrollableScope must be placed above the BuildContext returned by notificationContext
    // so that we can get this ScrollableState by doing the following:
    //
    // ScrollNotification notification;
    // Scrollable.of(notification.context)
    //
    // Since notificationContext is pointing to _gestureDetectorKey.context, _ScrollableScope
    // must be placed above the widget using it: RawGestureDetector
    Widget result = _ScrollableScope(
      scrollable: this,
      horizontalPosition: horizontalPosition,
      verticalPosition: verticalPosition,
      // TODO(ianh): Having all these global keys is sad.
      child: Listener(
        onPointerSignal: _receivedPointerSignal,
        child: RawGestureDetector(
          key: _gestureDetectorKey,
          gestures: _gestureRecognizers,
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: widget.excludeFromSemantics,
          child: Semantics(
            explicitChildNodes: !widget.excludeFromSemantics,
            child: IgnorePointer(
              key: _ignorePointerKey,
              ignoring: _shouldIgnorePointer,
              ignoringSemantics: false,
              child: widget.viewportBuilder(context, horizontalPosition, verticalPosition),
            ),
          ),
        ),
      ),
    );

    if (!widget.excludeFromSemantics) {
      result = NotificationListener<ScrollMetricsNotification>(
          onNotification: _handleScrollMetricsNotification,
          child: _ScrollSemantics(
            key: _scrollSemanticsKey,
            position: horizontalPosition,
            allowImplicitScrolling: _physics!.allowImplicitScrolling,
            semanticChildCount: widget.semanticChildCount,
            child: result,
          )
      );
    }

    final ScrollableDetails horizontalDetails = ScrollableDetails(
      direction: widget.horizontalAxisDirection,
      controller: _effectiveHorizontalScrollController,
    );

    final ScrollableDetails verticalDetails = ScrollableDetails(
      direction: widget.verticalAxisDirection,
      controller: _effectiveVerticalScrollController,
    );

    final Widget verticalScrollbar = _configuration.buildScrollbar(
      context,
      _configuration.buildOverscrollIndicator(context, result, verticalDetails),
      verticalDetails,
    );

    // Need to create Scrollbar explicitly because _configuration.buildScrollbar skips creating a horizontal scrollbar.
    final Scrollbar horizontalScrollbar = Scrollbar(
      controller: horizontalDetails.controller,
      child: verticalScrollbar,
    );
    return horizontalScrollbar;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ScrollPosition>('horizontal position', horizontalPosition));
    properties.add(DiagnosticsProperty<ScrollPosition>('vertical position', verticalPosition));
    properties.add(DiagnosticsProperty<ScrollPhysics>('effective physics', _physics));
  }

  @override
  String? get restorationId => widget.restorationId;
}

/// With [_ScrollSemantics] certain child [SemanticsNode]s can be
/// excluded from the scrollable area for semantics purposes.
///
/// Nodes, that are to be excluded, have to be tagged with
/// [RenderViewport.excludeFromScrolling] and the [RenderAbstractViewport] in
/// use has to add the [RenderViewport.useTwoPaneSemantics] tag to its
/// [SemanticsConfiguration] by overriding
/// [RenderObject.describeSemanticsConfiguration].
///
/// If the tag [RenderViewport.useTwoPaneSemantics] is present on the viewport,
/// two semantics nodes will be used to represent the [Scrollable]: The outer
/// node will contain all children, that are excluded from scrolling. The inner
/// node, which is annotated with the scrolling actions, will house the
/// scrollable children.
class _ScrollSemantics extends SingleChildRenderObjectWidget {
  const _ScrollSemantics({
    Key? key,
    required this.position,
    required this.allowImplicitScrolling,
    required this.semanticChildCount,
    Widget? child,
  }) : assert(position != null),
        assert(semanticChildCount == null || semanticChildCount >= 0),
        super(key: key, child: child);

  final ScrollPosition position;
  final bool allowImplicitScrolling;
  final int? semanticChildCount;

  @override
  _RenderScrollSemantics createRenderObject(BuildContext context) {
    return _RenderScrollSemantics(
      position: position,
      allowImplicitScrolling: allowImplicitScrolling,
      semanticChildCount: semanticChildCount,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderScrollSemantics renderObject) {
    renderObject
      ..allowImplicitScrolling = allowImplicitScrolling
      ..position = position
      ..semanticChildCount = semanticChildCount;
  }
}

class _RenderScrollSemantics extends RenderProxyBox {
  _RenderScrollSemantics({
    required ScrollPosition position,
    required bool allowImplicitScrolling,
    required int? semanticChildCount,
    RenderBox? child,
  }) : _position = position,
        _allowImplicitScrolling = allowImplicitScrolling,
        _semanticChildCount = semanticChildCount,
        assert(position != null),
        super(child) {
    position.addListener(markNeedsSemanticsUpdate);
  }

  /// Whether this render object is excluded from the semantic tree.
  ScrollPosition get position => _position;
  ScrollPosition _position;
  set position(ScrollPosition value) {
    assert(value != null);
    if (value == _position)
      return;
    _position.removeListener(markNeedsSemanticsUpdate);
    _position = value;
    _position.addListener(markNeedsSemanticsUpdate);
    markNeedsSemanticsUpdate();
  }

  /// Whether this node can be scrolled implicitly.
  bool get allowImplicitScrolling => _allowImplicitScrolling;
  bool _allowImplicitScrolling;
  set allowImplicitScrolling(bool value) {
    if (value == _allowImplicitScrolling)
      return;
    _allowImplicitScrolling = value;
    markNeedsSemanticsUpdate();
  }

  int? get semanticChildCount => _semanticChildCount;
  int? _semanticChildCount;
  set semanticChildCount(int? value) {
    if (value == semanticChildCount)
      return;
    _semanticChildCount = value;
    markNeedsSemanticsUpdate();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
    if (position.haveDimensions) {
      config
        ..hasImplicitScrolling = allowImplicitScrolling
        ..scrollPosition = _position.pixels
        ..scrollExtentMax = _position.maxScrollExtent
        ..scrollExtentMin = _position.minScrollExtent
        ..scrollChildCount = semanticChildCount;
    }
  }

  SemanticsNode? _innerNode;

  @override
  void assembleSemanticsNode(SemanticsNode node, SemanticsConfiguration config, Iterable<SemanticsNode> children) {
    if (children.isEmpty || !children.first.isTagged(RenderViewport.useTwoPaneSemantics)) {
      super.assembleSemanticsNode(node, config, children);
      return;
    }

    _innerNode ??= SemanticsNode(showOnScreen: showOnScreen);
    _innerNode!
      ..isMergedIntoParent = node.isPartOfNodeMerging
      ..rect = node.rect;

    int? firstVisibleIndex;
    final List<SemanticsNode> excluded = <SemanticsNode>[_innerNode!];
    final List<SemanticsNode> included = <SemanticsNode>[];
    for (final SemanticsNode child in children) {
      assert(child.isTagged(RenderViewport.useTwoPaneSemantics));
      if (child.isTagged(RenderViewport.excludeFromScrolling)) {
        excluded.add(child);
      } else {
        if (!child.hasFlag(SemanticsFlag.isHidden))
          firstVisibleIndex ??= child.indexInParent;
        included.add(child);
      }
    }
    config.scrollIndex = firstVisibleIndex;
    node.updateWith(config: null, childrenInInversePaintOrder: excluded);
    _innerNode!.updateWith(config: config, childrenInInversePaintOrder: included);
  }

  @override
  void clearSemantics() {
    super.clearSemantics();
    _innerNode = null;
  }
}

/// A typedef for a function that can calculate the offset for a type of scroll
/// increment given a [ScrollIncrementDetails].
///
/// This function is used as the type for [MyScrollable.incrementCalculator],
/// which is called from a [ScrollAction].
typedef ScrollIncrementCalculator = double Function(ScrollIncrementDetails details);

/// Describes the type of scroll increment that will be performed by a
/// [ScrollAction] on a [MyScrollable].
///
/// This is used to configure a [ScrollIncrementDetails] object to pass to a
/// [ScrollIncrementCalculator] function on a [MyScrollable].
///
/// {@template flutter.widgets.ScrollIncrementType.intent}
/// This indicates the *intent* of the scroll, not necessarily the size. Not all
/// scrollable areas will have the concept of a "line" or "page", but they can
/// respond to the different standard key bindings that cause scrolling, which
/// are bound to keys that people use to indicate a "line" scroll (e.g.
/// control-arrowDown keys) or a "page" scroll (e.g. pageDown key). It is
/// recommended that at least the relative magnitudes of the scrolls match
/// expectations.
/// {@endtemplate}
enum ScrollIncrementType {
  /// Indicates that the [ScrollIncrementCalculator] should return the scroll
  /// distance it should move when the user requests to scroll by a "line".
  ///
  /// The distance a "line" scrolls refers to what should happen when the key
  /// binding for "scroll down/up by a line" is triggered. It's up to the
  /// [ScrollIncrementCalculator] function to decide what that means for a
  /// particular scrollable.
  line,

  /// Indicates that the [ScrollIncrementCalculator] should return the scroll
  /// distance it should move when the user requests to scroll by a "page".
  ///
  /// The distance a "page" scrolls refers to what should happen when the key
  /// binding for "scroll down/up by a page" is triggered. It's up to the
  /// [ScrollIncrementCalculator] function to decide what that means for a
  /// particular scrollable.
  page,
}

/// A details object that describes the type of scroll increment being requested
/// of a [ScrollIncrementCalculator] function, as well as the current metrics
/// for the scrollable.
class ScrollIncrementDetails {
  /// A const constructor for a [ScrollIncrementDetails].
  ///
  /// All of the arguments must not be null, and are required.
  const ScrollIncrementDetails({
    required this.type,
    required this.metrics,
  })  : assert(type != null),
        assert(metrics != null);

  /// The type of scroll this is (e.g. line, page, etc.).
  ///
  /// {@macro flutter.widgets.ScrollIncrementType.intent}
  final ScrollIncrementType type;

  /// The current metrics of the scrollable that is being scrolled.
  final ScrollMetrics metrics;
}

/// An [Intent] that represents scrolling the nearest scrollable by an amount
/// appropriate for the [type] specified.
///
/// The actual amount of the scroll is determined by the
/// [MyScrollable.incrementCalculator], or by its defaults if that is not
/// specified.
class ScrollIntent extends Intent {
  /// Creates a const [ScrollIntent] that requests scrolling in the given
  /// [direction], with the given [type].
  const ScrollIntent({
    required this.direction,
    this.type = ScrollIncrementType.line,
  })  : assert(direction != null),
        assert(type != null);

  /// The direction in which to scroll the scrollable containing the focused
  /// widget.
  final AxisDirection direction;

  /// The type of scrolling that is intended.
  final ScrollIncrementType type;
}

/// An [Action] that scrolls the [MyScrollable] that encloses the current
/// [primaryFocus] by the amount configured in the [ScrollIntent] given to it.
///
/// If a Scrollable cannot be found above the current [primaryFocus], the
/// [PrimaryScrollController] will be considered for default handling of
/// [ScrollAction]s.
///
/// If [MyScrollable.incrementCalculator] is null for the scrollable, the default
/// for a [ScrollIntent.type] set to [ScrollIncrementType.page] is 80% of the
/// size of the scroll window, and for [ScrollIncrementType.line], 50 logical
/// pixels.
class ScrollAction extends Action<ScrollIntent> {
  @override
  bool isEnabled(ScrollIntent intent) {
    final FocusNode? focus = primaryFocus;
    final bool contextIsValid = focus != null && focus.context != null;
    if (contextIsValid) {
      // Check for primary scrollable within the current context
      if (MyScrollable.of(focus.context!) != null)
        return true;
      // Check for fallback scrollable with context from PrimaryScrollController
      if (PrimaryScrollController.of(focus.context!) != null) {
        final ScrollController? primaryScrollController = PrimaryScrollController.of(focus.context!);
        return primaryScrollController != null
            && primaryScrollController.hasClients
            && primaryScrollController.position.context.notificationContext != null
            && MyScrollable.of(primaryScrollController.position.context.notificationContext!) != null;
      }
    }
    return false;
  }

  // Returns the scroll increment for a single scroll request, for use when
  // scrolling using a hardware keyboard.
  //
  // Must not be called when the position is null, or when any of the position
  // metrics (pixels, viewportDimension, maxScrollExtent, minScrollExtent) are
  // null. The type and state arguments must not be null, and the widget must
  // have already been laid out so that the position fields are valid.
  double _calculateHorizontalScrollIncrement(MyScrollableState state, { ScrollIncrementType type = ScrollIncrementType.line }) {
    assert(type != null);
    assert(state.horizontalPosition != null);
    assert(state.horizontalPosition.hasPixels);
    assert(state.horizontalPosition.viewportDimension != null);
    assert(state.horizontalPosition.maxScrollExtent != null);
    assert(state.horizontalPosition.minScrollExtent != null);
    assert(state._physics == null || state._physics!.shouldAcceptUserOffset(state.horizontalPosition));
    if (state.widget.incrementCalculator != null) {
      return state.widget.incrementCalculator!(
        ScrollIncrementDetails(
          type: type,
          metrics: state.horizontalPosition,
        ),
      );
    }
    switch (type) {
      case ScrollIncrementType.line:
        return 50.0;
      case ScrollIncrementType.page:
        return 0.8 * state.horizontalPosition.viewportDimension;
    }
  }

  // Returns the scroll increment for a single scroll request, for use when
  // scrolling using a hardware keyboard.
  //
  // Must not be called when the position is null, or when any of the position
  // metrics (pixels, viewportDimension, maxScrollExtent, minScrollExtent) are
  // null. The type and state arguments must not be null, and the widget must
  // have already been laid out so that the position fields are valid.
  double _calculateVerticalScrollIncrement(MyScrollableState state, { ScrollIncrementType type = ScrollIncrementType.line }) {
    assert(type != null);
    assert(state.verticalPosition != null);
    assert(state.verticalPosition.hasPixels);
    assert(state.verticalPosition.viewportDimension != null);
    assert(state.verticalPosition.maxScrollExtent != null);
    assert(state.verticalPosition.minScrollExtent != null);
    assert(state._physics == null || state._physics!.shouldAcceptUserOffset(state.verticalPosition));
    if (state.widget.incrementCalculator != null) {
      return state.widget.incrementCalculator!(
        ScrollIncrementDetails(
          type: type,
          metrics: state.verticalPosition,
        ),
      );
    }
    switch (type) {
      case ScrollIncrementType.line:
        return 50.0;
      case ScrollIncrementType.page:
        return 0.8 * state.verticalPosition.viewportDimension;
    }
  }

  // Find out how much of an increment to move by, taking the different
  // directions into account.
  double _getHorizontalIncrement(MyScrollableState state, ScrollIntent intent) {
    final double increment = _calculateHorizontalScrollIncrement(state, type: intent.type);
    switch (intent.direction) {
      case AxisDirection.left:
        return -increment;
      case AxisDirection.right:
        return increment;
      case AxisDirection.up:
        return 0.0;
      case AxisDirection.down:
        return 0.0;
    }
  }

  // Find out how much of an increment to move by, taking the different
  // directions into account.
  double _getVerticalIncrement(MyScrollableState state, ScrollIntent intent) {
    final double increment = _calculateVerticalScrollIncrement(state, type: intent.type);
    switch (intent.direction) {
      case AxisDirection.left:
        return 0.0;
      case AxisDirection.right:
        return 0.0;
      case AxisDirection.up:
        return -increment;
      case AxisDirection.down:
        return increment;
    }
  }

  @override
  void invoke(ScrollIntent intent) {
    MyScrollableState? state = MyScrollable.of(primaryFocus!.context!);
    if (state == null) {
      final ScrollController? primaryScrollController = PrimaryScrollController.of(primaryFocus!.context!);
      state = MyScrollable.of(primaryScrollController!.position.context.notificationContext!);
    }
    assert(state != null, '$ScrollAction was invoked on a context that has no scrollable parent');

    switch (intent.direction) {
      case AxisDirection.down:
      case AxisDirection.up:
        assert(state!.verticalPosition.hasPixels, 'Scrollable must be laid out before it can be scrolled via a ScrollAction');
        assert(state!.verticalPosition.viewportDimension != null);
        assert(state!.verticalPosition.maxScrollExtent != null);
        assert(state!.verticalPosition.minScrollExtent != null);

        // Don't do anything if the user isn't allowed to scroll.
        if (state!._physics != null && !state._physics!.shouldAcceptUserOffset(state.verticalPosition)) {
          return;
        }
        final double increment = _getVerticalIncrement(state, intent);
        if (increment == 0.0) {
          return;
        }
        state.verticalPosition.moveTo(
          state.verticalPosition.pixels + increment,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
        );
        return;
      case AxisDirection.left:
      case AxisDirection.right:
        assert(state!.horizontalPosition.hasPixels, 'Scrollable must be laid out before it can be scrolled via a ScrollAction');
        assert(state!.horizontalPosition.viewportDimension != null);
        assert(state!.horizontalPosition.maxScrollExtent != null);
        assert(state!.horizontalPosition.minScrollExtent != null);

        // Don't do anything if the user isn't allowed to scroll.
        if (state!._physics != null && !state._physics!.shouldAcceptUserOffset(state.horizontalPosition)) {
          return;
        }
        final double increment = _getHorizontalIncrement(state, intent);
        if (increment == 0.0) {
          return;
        }
        state.horizontalPosition.moveTo(
          state.horizontalPosition.pixels + increment,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
        );
    }
  }
}

// Not using a RestorableDouble because we want to allow null values and override
// [enabled].
class _RestorableScrollOffsets extends RestorableValue<List<double>?> {
  @override
  List<double>? createDefaultValue() => null;

  @override
  void didUpdateValue(List<double>? oldValue) {
    notifyListeners();
  }

  @override
  List<double>? fromPrimitives(Object? data) {
    return data! as List<double>?;
  }

  @override
  Object? toPrimitives() {
    return value;
  }

  @override
  bool get enabled => value != null;
}
