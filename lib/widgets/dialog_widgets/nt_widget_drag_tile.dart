import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/widget_container_model.dart';
import 'package:elastic_dashboard/widgets/gesture/drag_listener.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class NTWidgetDragTile extends StatefulWidget {
  final NTConnection ntConnection;
  final SharedPreferences preferences;
  final NT4StructMeta? ntStructMeta;

  final int gridIndex;
  final String widgetName;

  final void Function(Offset globalPosition, WidgetContainerModel widget)
  onDragUpdate;

  final void Function(WidgetContainerModel widget) onDragEnd;

  final void Function() onRemoveWidget;

  const NTWidgetDragTile({
    super.key,
    required this.ntConnection,
    required this.preferences,
    this.ntStructMeta,
    required this.gridIndex,
    required this.widgetName,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onRemoveWidget,
  });

  @override
  State<NTWidgetDragTile> createState() => _NTWidgetDragTileState();
}

class _NTWidgetDragTileState extends State<NTWidgetDragTile> {
  WidgetContainerModel? draggingWidget;

  void cancelDrag() {
    if (draggingWidget != null) {
      draggingWidget?.unSubscribe();
      draggingWidget?.softDispose(deleting: true);
      draggingWidget?.dispose();

      widget.onRemoveWidget();

      draggingWidget = null;
    }
  }

  @override
  void didUpdateWidget(NTWidgetDragTile oldWidget) {
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
  Widget build(BuildContext context) => InkWell(
    onTap: () {},
    child: DragListener(
      overrideVertical: false,
      supportedDevices: PointerDeviceKind.values
          .whereNot((element) => element == PointerDeviceKind.trackpad)
          .toSet(),
      onDragStart: (details) {
        if (draggingWidget != null) {
          return;
        }

        // Prevents 2 finger drags from dragging a widget
        if (details.kind != null &&
            details.kind! == PointerDeviceKind.trackpad) {
          draggingWidget = null;
          return;
        }

        setState(() {
          NTWidgetModel widgetModel = NTWidgetRegistry.buildNTModelFromType(
            widget.ntConnection,
            widget.preferences,
            widget.ntStructMeta,
            widget.widgetName,
            null,
          );

          NTWidget? ntWidget = NTWidgetRegistry.buildNTWidgetFromModel(
            widgetModel,
          );

          if (ntWidget == null) {
            widgetModel.unSubscribe();
            widgetModel.softDispose(deleting: true);
            widgetModel.dispose();
            return;
          }

          double width = NTWidgetRegistry.getDefaultWidth(widgetModel);
          double height = NTWidgetRegistry.getDefaultHeight(widgetModel);

          draggingWidget = NTWidgetContainerModel(
            ntConnection: widget.ntConnection,
            preferences: widget.preferences,
            initialPosition: Rect.fromLTWH(0.0, 0.0, width, height),
            title: widget.widgetName,
            childModel: widgetModel,
          );
        });
      },
      onDragUpdate: (details) {
        if (draggingWidget == null) {
          return;
        }

        widget.onDragUpdate.call(details.globalPosition, draggingWidget!);
      },
      onDragEnd: (details) {
        if (draggingWidget == null) {
          return;
        }

        widget.onDragEnd.call(draggingWidget!);

        setState(() => draggingWidget = null);
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 32),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(right: 20),
              title: Text(widget.widgetName),
            ),
          ),
          const Divider(height: 0),
        ],
      ),
    ),
  );
}
