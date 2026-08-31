import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:elastic_dashboard/widgets/draggable_containers/models/widget_container_model.dart';
import 'package:elastic_dashboard/widgets/gesture/drag_listener.dart';

class DragContainerListener<T extends WidgetContainerModel>
    extends StatefulWidget {
  final int gridIndex;
  final FutureOr<T?> Function() onDragCreate;
  final void Function(Offset globalPosition, T widget)? onDragUpdate;
  final void Function(T widget)? onDragEnd;
  final void Function()? onRemoveWidget;

  final bool overrideVertical;
  final Set<PointerDeviceKind>? supportedDevices;

  final Widget child;

  const DragContainerListener({
    super.key,
    required this.gridIndex,
    required this.onDragCreate,
    this.onDragUpdate,
    this.onDragEnd,
    this.onRemoveWidget,
    this.overrideVertical = false,
    this.supportedDevices,
    required this.child,
  });

  @override
  State<DragContainerListener<T>> createState() =>
      _DragContainerListenerState<T>();
}

class _DragContainerListenerState<T extends WidgetContainerModel>
    extends State<DragContainerListener<T>> {
  T? draggingWidget;
  bool dragging = false;

  void cancelDrag() {
    if (draggingWidget != null) {
      draggingWidget!.unSubscribe();
      draggingWidget!.softDispose(deleting: true);
      draggingWidget!.dispose();

      widget.onRemoveWidget?.call();

      draggingWidget = null;
    }
    dragging = false;
  }

  @override
  void didUpdateWidget(DragContainerListener<T> oldWidget) {
    if (widget.gridIndex != oldWidget.gridIndex) {
      cancelDrag();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    cancelDrag();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DragListener(
    overrideVertical: widget.overrideVertical,
    supportedDevices: widget.supportedDevices,
    onDragStart: (details) async {
      if (draggingWidget != null) {
        return;
      }

      dragging = true;
      final T? createdWidget = await widget.onDragCreate();

      if (!dragging) {
        createdWidget?.unSubscribe();
        createdWidget?.softDispose(deleting: true);
        createdWidget?.dispose();
        draggingWidget = null;
      } else {
        draggingWidget = createdWidget;
      }
    },
    onDragUpdate: (details) {
      if (draggingWidget == null) {
        return;
      }

      draggingWidget!.cursorGlobalLocation = details.globalPosition;
      widget.onDragUpdate?.call(details.globalPosition, draggingWidget!);
    },
    onDragEnd: (details) {
      if (draggingWidget == null) {
        dragging = false;
        return;
      }

      widget.onDragEnd?.call(draggingWidget!);
      draggingWidget = null;
      dragging = false;
    },
    child: widget.child,
  );
}
