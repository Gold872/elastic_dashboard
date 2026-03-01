import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/layout_container_model.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'nt_widget_container_model.dart';
import 'widget_container_model.dart';

typedef DragOutFunctions = ({
  bool Function(WidgetContainerModel widget) dragOutEnd,
  void Function(WidgetContainerModel widget, Offset globalPosition)
  dragOutUpdate,
});

class ListLayoutModel extends LayoutContainerModel {
  @override
  String type = 'List Layout';

  List<NTWidgetContainerModel> children = [];

  String labelPosition = 'TOP';

  static const double _minWidth = 128 * 2;
  static const double _minHeight = 128 * 2;

  final DragOutFunctions? dragOutFunctions;
  final NTWidgetContainerModel? Function(
    SharedPreferences preferences,
    Map<String, dynamic> jsonData,
    bool enabled, {
    Function(String errorMessage)? onJsonLoadingWarning,
  })?
  ntWidgetBuilder;

  final Function(WidgetContainerModel model)? onDragCancel;

  static List<String> labelPositions = const [
    'Top',
    'Left',
    'Right',
    'Bottom',
    'Hidden',
  ];

  ListLayoutModel({
    required super.preferences,
    required super.initialPosition,
    required super.title,
    this.dragOutFunctions,
    required this.onDragCancel,
    this.ntWidgetBuilder,
    List<NTWidgetContainerModel>? children,
    super.minWidth = _minWidth,
    super.minHeight = _minHeight,
    this.labelPosition = 'TOP',
  }) : super() {
    if (children != null) {
      this.children = children;
    }
  }

  ListLayoutModel.fromJson({
    required super.jsonData,
    required super.preferences,
    required this.ntWidgetBuilder,
    this.dragOutFunctions,
    required this.onDragCancel,
    super.enabled,
    super.minWidth = _minWidth,
    super.minHeight = _minHeight,
    super.onJsonLoadingWarning,
  }) : super.fromJson();

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), ...getChildrenJson()};

  Map<String, dynamic> getChildrenJson() {
    var childrenJson = [];

    for (WidgetContainerModel childContainer in children) {
      childrenJson.add(childContainer.toJson());
    }

    return {'children': childrenJson};
  }

  @override
  Map<String, dynamic> getProperties() => {'label_position': labelPosition};

  @override
  void fromJson(
    Map<String, dynamic> jsonData, {
    Function(String errorMessage)? onJsonLoadingWarning,
  }) {
    super.fromJson(jsonData, onJsonLoadingWarning: onJsonLoadingWarning);

    if (jsonData.containsKey('properties') &&
        jsonData['properties'] is Map<String, dynamic>) {
      labelPosition =
          tryCast(jsonData['properties']['label_position']) ??
          tryCast(jsonData['properties']['Label position']) ??
          'TOP';

      if (!labelPositions
          .map((e) => e.toUpperCase())
          .contains(labelPosition.toUpperCase())) {
        labelPosition = 'TOP';
      }
    }

    if (!jsonData.containsKey('children')) {
      onJsonLoadingWarning?.call(
        'List Layout JSON data does not contain any children',
      );
      return;
    }

    if (jsonData['children'] is! List<dynamic>) {
      onJsonLoadingWarning?.call(
        'List Layout JSON data does not contain any children',
      );
      return;
    }

    for (Map<String, dynamic> childData in jsonData['children']) {
      NTWidgetContainerModel? widgetModel = ntWidgetBuilder!(
        preferences,
        childData,
        enabled,
        onJsonLoadingWarning: onJsonLoadingWarning,
      );

      if (widgetModel != null) {
        children.add(widgetModel);
      }
    }
  }

  @override
  void softDispose({bool deleting = false}) {
    super.softDispose(deleting: deleting);

    for (var child in children) {
      child.softDispose(deleting: deleting);
    }
  }

  @override
  void unSubscribe() {
    super.unSubscribe();

    for (var child in children) {
      child.unSubscribe();
    }
  }

  @override
  set enabled(bool enabled) {
    for (var container in children) {
      container.enabled = enabled;
    }

    super.enabled = enabled;
  }

  @override
  void showEditProperties(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Properties'),
        content: StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 375,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...getContainerEditProperties(),
                const Divider(),
                const Center(child: Text('Label Position')),
                DialogDropdownChooser(
                  onSelectionChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    if (!labelPositions.contains(value)) {
                      return;
                    }

                    setState(() {
                      labelPosition = value.toUpperCase();

                      notifyListeners();
                    });
                  },
                  choices: labelPositions,
                  initialValue:
                      labelPosition.substring(0, 1).toUpperCase() +
                      labelPosition.substring(1).toLowerCase(),
                ),
                const Divider(),
                if (children.isNotEmpty)
                  Flexible(
                    child: ReorderableListView(
                      header: const Text('Children Order & Properties'),
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: children
                          .map(
                            (container) => Padding(
                              key: UniqueKey(),
                              padding: EdgeInsets.zero,
                              child: ExpansionTile(
                                title: Text(container.title ?? ''),
                                subtitle: Text(container.childModel.type),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      children.remove(container);

                                      container.unSubscribe();
                                      container.softDispose(deleting: true);
                                      container.dispose();

                                      notifyListeners();
                                    });
                                  },
                                ),
                                tilePadding: const EdgeInsets.only(
                                  right: 40.0,
                                ),
                                childrenPadding: const EdgeInsets.only(
                                  left: 16.0,
                                  top: 8.0,
                                  right: 32.0,
                                  bottom: 8.0,
                                ),
                                expandedCrossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: getChildEditProperties(
                                  context,
                                  container,
                                  setState,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) {
                            newIndex--;
                          }
                          var temp = children[newIndex];
                          children[newIndex] = children[oldIndex];
                          children[oldIndex] = temp;

                          notifyListeners();
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Widget> getChildEditProperties(
    BuildContext context,
    NTWidgetContainerModel container,
    StateSetter setState,
  ) {
    List<Widget> containerEditProperties = [
      // Settings for the widget container
      const Text('Container Settings'),
      const SizedBox(height: 5),
      DialogTextInput(
        onSubmit: (value) {
          setState(() {
            container.title = value;

            notifyListeners();
          });
        },
        label: 'Title',
        initialText: container.title,
      ),
    ];

    List<Widget> childEditProperties = container.childModel.getEditProperties(
      context,
    );

    return [
      ...containerEditProperties,
      container.getWidgetTypeProperties((fn) {
        setState(fn);
        notifyListeners();
      }),
      if (childEditProperties.isNotEmpty) ...[
        const Divider(),
        Text('${container.childModel.type} Widget Settings'),
        const SizedBox(height: 5),
        ...childEditProperties,
      ],
      const Divider(),
      ...container.getNTEditProperties(),
      const SizedBox(height: 5),
    ];
  }

  @override
  void addWidget(WidgetContainerModel widget) {
    children.add(widget as NTWidgetContainerModel);
    notifyListeners();
  }

  @override
  void removeWidget(WidgetContainerModel widget) {
    children.remove(widget);
    notifyListeners();
  }

  @override
  bool willAcceptWidget(
    WidgetContainerModel widget, {
    Offset? globalPosition,
  }) => widget is NTWidgetContainerModel;

  List<Widget> _getListColumn() {
    List<Widget> column = [];

    for (NTWidgetContainerModel widget in children) {
      Widget widgetInContainer = Container(
        constraints: BoxConstraints(
          minHeight: 32.0,
          maxHeight: max((widget.minHeight) - 48.0, 32.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 1.5,
                  vertical: 2.0,
                ),
                child: AbsorbPointer(
                  absorbing: !widget.enabled,
                  child: ChangeNotifierProvider<NTWidgetModel>.value(
                    value: widget.childModel,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      Widget containerContent;

      switch (labelPosition.toUpperCase()) {
        case 'LEFT':
          containerContent = Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2.0),
                  child: Text(
                    widget.title ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Flexible(child: widgetInContainer),
            ],
          );
          break;
        case 'RIGHT':
          containerContent = Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: widgetInContainer),
              const SizedBox(width: 5),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2.0),
                  child: Text(
                    widget.title ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          );
          break;
        case 'BOTTOM':
          containerContent = Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              widgetInContainer,
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2.0),
                  child: Text(
                    widget.title ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          );
          break;
        case 'HIDDEN':
          containerContent = widgetInContainer;
        case 'TOP':
        default:
          containerContent = Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2.0),
                  child: Text(
                    widget.title ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              widgetInContainer,
            ],
          );
          break;
      }

      column.add(
        GestureDetector(
          supportedDevices: PointerDeviceKind.values
              .whereNot((element) => element == PointerDeviceKind.trackpad)
              .toSet(),
          onPanDown: (details) {
            if (preferences.getBool(PrefKeys.layoutLocked) ??
                Defaults.layoutLocked) {
              return;
            }
            widget.cursorGlobalLocation = details.globalPosition;

            if (dragging || resizing) {
              onDragCancel?.call(this);
            }

            draggable = false;
          },
          onPanUpdate: (details) {
            if (preferences.getBool(PrefKeys.layoutLocked) ??
                Defaults.layoutLocked) {
              return;
            }
            widget.cursorGlobalLocation = details.globalPosition;

            dragOutFunctions?.dragOutUpdate(widget, details.globalPosition);
          },
          onPanEnd: (details) {
            if (preferences.getBool(PrefKeys.layoutLocked) ??
                Defaults.layoutLocked) {
              return;
            }

            if (dragOutFunctions?.dragOutEnd(widget) ?? false) {
              children.remove(widget);
              notifyListeners();
            }

            draggable = true;
          },
          onPanCancel: () {
            if (preferences.getBool(PrefKeys.layoutLocked) ??
                Defaults.layoutLocked) {
              return;
            }

            if (dragging || resizing) {
              onDragCancel?.call(this);
            }

            draggable = true;
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2.5),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 4.0,
                vertical: 2.0,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7.5),
                color: const Color.fromARGB(255, 45, 45, 45),
                boxShadow: const [
                  BoxShadow(
                    offset: Offset(1.0, 1.0),
                    blurRadius: 3.0,
                    color: Colors.black,
                  ),
                ],
              ),
              child: containerContent,
            ),
          ),
        ),
      );
    }

    return column;
  }

  @override
  WidgetContainer getDraggingWidgetContainer(BuildContext context) =>
      WidgetContainer(
        title: title,
        width: draggingRect.width,
        height: draggingRect.height,
        cornerRadius:
            preferences.getDouble(PrefKeys.cornerRadius) ??
            Defaults.cornerRadius,
        opacity: 0.80,
        horizontalPadding: 5.0,
        verticalPadding: 5.0,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Column(children: [..._getListColumn()]),
              ),
            ),
          ],
        ),
      );

  @override
  WidgetContainer getWidgetContainer(BuildContext context) => WidgetContainer(
    title: title,
    width: displayRect.width,
    height: displayRect.height,
    cornerRadius:
        preferences.getDouble(PrefKeys.cornerRadius) ?? Defaults.cornerRadius,
    opacity: (previewVisible) ? 0.25 : 1.00,
    horizontalPadding: 5.0,
    verticalPadding: 5.0,
    child: Opacity(
      opacity: (enabled) ? 1.00 : 0.50,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Column(children: [..._getListColumn()]),
            ),
          ),
        ],
      ),
    ),
  );
}
