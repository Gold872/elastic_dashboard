import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import 'package:collection/collection.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';

class DraggableDialog extends StatefulWidget {
  final Widget dialog;
  final Rect initialPosition;

  const DraggableDialog({
    super.key,
    required this.dialog,
    this.initialPosition = const Rect.fromLTWH(50.0, 50.0, 400, 500),
  });

  @override
  State<DraggableDialog> createState() => _DraggableDialogState();
}

class _DraggableDialogState extends State<DraggableDialog> {
  late Rect position = widget.initialPosition;

  @override
  Widget build(BuildContext context) => TransformableBox(
    constraints: const BoxConstraints(
      minWidth: 300,
      minHeight: 400,
      maxWidth: double.infinity,
      maxHeight: double.infinity,
    ),
    clampingRect: const Rect.fromLTWH(0, 0, double.infinity, double.infinity),
    allowFlippingWhileResizing: false,
    visibleHandles: const {},
    supportedDragDevices: PointerDeviceKind.values
        .whereNot((e) => e == PointerDeviceKind.trackpad)
        .toSet(),
    supportedResizeDevices: PointerDeviceKind.values
        .whereNot((e) => e == PointerDeviceKind.trackpad)
        .toSet(),
    resizeModeResolver: () => ResizeMode.freeform,
    rect: position,
    onChanged: (result, event) {
      setState(() => position = result.rect);
    },
    contentBuilder: (context, rect, flip) => widget.dialog,
  );
}
