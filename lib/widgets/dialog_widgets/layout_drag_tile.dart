import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:collection/collection.dart';

import 'package:elastic_dashboard/widgets/draggable_containers/models/layout_container_model.dart';
import 'package:elastic_dashboard/widgets/gesture/drag_container_listener.dart';

class LayoutDragTile extends StatelessWidget {
  final int gridIndex;
  final String title;
  final IconData icon;

  final LayoutContainerModel Function() layoutBuilder;

  final void Function(Offset globalPosition, LayoutContainerModel widget)
  onDragUpdate;

  final void Function(LayoutContainerModel widget) onDragEnd;

  final void Function() onRemoveWidget;

  const LayoutDragTile({
    super.key,
    required this.gridIndex,
    required this.title,
    required this.icon,
    required this.layoutBuilder,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onRemoveWidget,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () {},
    child: DragContainerListener<LayoutContainerModel>(
      gridIndex: gridIndex,
      supportedDevices: PointerDeviceKind.values
          .whereNot((element) => element == PointerDeviceKind.trackpad)
          .toSet(),
      onDragCreate: () => layoutBuilder.call(),
      onDragUpdate: onDragUpdate,
      onDragEnd: onDragEnd,
      onRemoveWidget: onRemoveWidget,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16.0),
        child: ListTile(
          style: ListTileStyle.drawer,
          contentPadding: const EdgeInsets.only(right: 20.0),
          leading: Icon(icon),
          title: Text(title),
        ),
      ),
    ),
  );
}
