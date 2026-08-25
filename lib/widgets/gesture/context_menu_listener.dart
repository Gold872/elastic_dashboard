import 'dart:ui';

import 'package:collection/collection.dart';

import 'package:material_ui/material_ui.dart';

class ContextMenuListener extends StatefulWidget {
  final HitTestBehavior? behavior;

  final void Function(Offset globalPosition, Offset localPosition)
  onContextMenuGesture;

  final Widget child;

  const ContextMenuListener({
    super.key,
    this.behavior,
    required this.onContextMenuGesture,
    required this.child,
  });

  @override
  State<ContextMenuListener> createState() => _ContextMenuListenerState();
}

class _ContextMenuListenerState extends State<ContextMenuListener> {
  Offset longPressGlobalPosition = Offset.zero;
  Offset longPressLocalPosition = Offset.zero;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: widget.behavior,
    supportedDevices: PointerDeviceKind.values
        .whereNot((e) => e == PointerDeviceKind.mouse)
        .toSet(),
    onLongPressDown: (details) {
      longPressGlobalPosition = details.globalPosition;
      longPressLocalPosition = details.localPosition;
    },
    onLongPress: () => widget.onContextMenuGesture(
      longPressGlobalPosition,
      longPressLocalPosition,
    ),
    child: GestureDetector(
      behavior: widget.behavior,
      onSecondaryTapUp: (details) => widget.onContextMenuGesture(
        details.globalPosition,
        details.localPosition,
      ),
      child: widget.child,
    ),
  );
}
