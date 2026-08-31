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
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/camera_stream.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

const String cameraPublisherRoot = '/CameraPublisher';

class CameraStreamList extends StatefulWidget {
  final NTConnection ntConnection;
  final SharedPreferences preferences;

  final int gridIndex;

  final void Function(Offset globalPosition, WidgetContainerModel widget)?
  onDragUpdate;
  final void Function(WidgetContainerModel widget)? onDragEnd;
  final void Function()? onRemoveWidget;

  const CameraStreamList({
    super.key,
    required this.ntConnection,
    required this.preferences,
    this.gridIndex = 0,
    this.onDragUpdate,
    this.onDragEnd,
    this.onRemoveWidget,
  });

  @override
  State<CameraStreamList> createState() => _CameraStreamListState();
}

class _CameraStreamListState extends State<CameraStreamList> {
  final Set<String> cameraNames = {};

  void onTopicAnnounced(NT4Topic topic) {
    if (mounted) {
      setState(() {});
    }
  }

  void onTopicUnannounced(NT4Topic topic) {
    cameraNames.clear();
    if (mounted) {
      setState(() {});
    }
  }

  void onConnected() {
    cameraNames.clear();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();

    widget.ntConnection.addTopicAnnounceListener(onTopicAnnounced);
    widget.ntConnection.addTopicUnannounceListener(onTopicUnannounced);
    widget.ntConnection.addConnectedListener(onConnected);
  }

  @override
  void dispose() {
    widget.ntConnection.removeTopicAnnounceListener(onTopicAnnounced);
    widget.ntConnection.removeTopicUnannounceListener(onTopicUnannounced);
    widget.ntConnection.removeConnectedListener(onConnected);

    super.dispose();
  }

  void createCameras(NT4Topic topic) {
    String topicName = topic.name;
    bool hasLeading = topicName.startsWith('/');
    if (!hasLeading) {
      topicName = '/$topicName';
    }

    List<String> rows = [
      ...topicName.substring(1).split('/'),
    ];
    if (rows.length == 1) {
      return;
    }

    cameraNames.add(rows[1]);
  }

  @override
  Widget build(BuildContext context) {
    List<NT4Topic> cameraTopics = [];

    for (NT4Topic topic in widget.ntConnection.announcedTopics().values) {
      if (!topic.name.startsWith(cameraPublisherRoot)) {
        continue;
      }

      cameraTopics.add(topic);
    }

    for (NT4Topic topic in cameraTopics) {
      createCameras(topic);
    }

    return ListView(
      children: [
        for (final entry in cameraNames.sorted())
          CameraTile(
            gridIndex: widget.gridIndex,
            ntConnection: widget.ntConnection,
            preferences: widget.preferences,
            entry: entry,
            onDragUpdate: widget.onDragUpdate,
            onDragEnd: widget.onDragEnd,
            onRemoveWidget: widget.onRemoveWidget,
          ),
      ],
    );
  }
}

class CameraTile extends StatefulWidget {
  final int gridIndex;

  final NTConnection ntConnection;
  final SharedPreferences preferences;
  final String entry;

  final void Function(Offset globalPosition, WidgetContainerModel widget)?
  onDragUpdate;
  final void Function(WidgetContainerModel widget)? onDragEnd;
  final void Function()? onRemoveWidget;

  const CameraTile({
    super.key,
    required this.gridIndex,
    required this.ntConnection,
    required this.preferences,
    required this.entry,
    this.onDragUpdate,
    this.onDragEnd,
    this.onRemoveWidget,
  });

  @override
  State<CameraTile> createState() => _CameraTileState();
}

class _CameraTileState extends State<CameraTile> {
  WidgetContainerModel? draggingWidget;
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
  void didUpdateWidget(CameraTile oldWidget) {
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

  WidgetContainerModel? createCameraWidget() {
    NTWidgetModel ntWidgetModel = CameraStreamModel(
      ntConnection: widget.ntConnection,
      preferences: widget.preferences,
      topic: '$cameraPublisherRoot/${widget.entry}',
    );

    NTWidget? ntWidget = NTWidgetRegistry.buildNTWidgetFromModel(ntWidgetModel);

    if (ntWidget == null) {
      ntWidgetModel.unSubscribe();
      ntWidgetModel.softDispose(deleting: true);
      ntWidgetModel.dispose();
      return null;
    }

    double width = NTWidgetRegistry.getDefaultWidth(ntWidgetModel);
    double height = NTWidgetRegistry.getDefaultHeight(ntWidgetModel);

    return NTWidgetContainerModel(
      ntConnection: widget.ntConnection,
      preferences: widget.preferences,
      initialPosition: Rect.fromLTWH(0.0, 0.0, width, height),
      title: widget.entry,
      childModel: ntWidgetModel,
    );
  }

  // I have absolutely no idea why Material is needed, but otherwise the tiles start bleeding all over the place, it makes zero sense
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      InkWell(
        onTap: () {},
        child: DragListener(
          overrideVertical: false,
          supportedDevices: PointerDeviceKind.values
              .whereNot((element) => element == PointerDeviceKind.trackpad)
              .toSet(),
          onDragStart: (details) async {
            if (draggingWidget != null) {
              return;
            }
            dragging = true;
            draggingWidget = createCameraWidget();
          },
          onDragUpdate: (details) {
            if (draggingWidget == null) {
              return;
            }

            draggingWidget!.cursorGlobalLocation = details.globalPosition;

            widget.onDragUpdate?.call(
              details.globalPosition,
              draggingWidget!,
            );
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
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: 16.0),
            child: ListTile(
              dense: true,
              style: ListTileStyle.drawer,
              title: Text(widget.entry),
            ),
          ),
        ),
      ),
      const Divider(height: 0),
    ],
  );
}
