import 'dart:ui';

import 'package:material_ui/material_ui.dart';

/// A gesture detector for dragging that will disable any pan gestures from parent widgets
class DragListener extends StatelessWidget {
  final Widget child;

  /// The kind of devices that are allowed to be recognized.
  ///
  /// If set to null, events from all device types will be recognized. Defaults to null.
  final Set<PointerDeviceKind>? supportedDevices;

  /// Callback for when the widget begins dragging
  final GestureDragStartCallback? onDragStart;

  /// Callback for when the drag is updated
  final GestureDragUpdateCallback? onDragUpdate;

  /// Callback for when the drag ends
  final GestureDragEndCallback? onDragEnd;

  /// Whether or not to overrride horizontal scrolling, defaults to true
  final bool overrideHorizontal;

  /// Whether or not to override vertical scrolling, defaults to true
  final bool overrideVertical;

  const DragListener({
    super.key,
    required this.child,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.overrideHorizontal = true,
    this.overrideVertical = true,
    this.supportedDevices,
  });

  @override
  Widget build(BuildContext context) {
    Widget listener = GestureDetector(
      onPanStart: onDragStart,
      onPanUpdate: onDragUpdate,
      onPanEnd: onDragEnd,
      supportedDevices: supportedDevices,
      child: child,
    );

    if (overrideHorizontal) {
      listener = GestureDetector(
        onHorizontalDragStart: onDragStart,
        onHorizontalDragUpdate: onDragUpdate,
        onHorizontalDragEnd: onDragEnd,
        supportedDevices: supportedDevices,
        child: listener,
      );
    }

    if (overrideVertical) {
      listener = GestureDetector(
        onVerticalDragStart: onDragStart,
        onVerticalDragUpdate: onDragUpdate,
        onVerticalDragEnd: onDragEnd,
        supportedDevices: supportedDevices,
        child: listener,
      );
    }

    return listener;
  }
}
