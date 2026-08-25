import 'package:dot_cast/dot_cast.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';

abstract class WidgetContainerModel extends ChangeNotifier {
  final Key key = UniqueKey();
  final SharedPreferences preferences;

  String? _title;

  String? get title => _title;

  set title(String? value) {
    _title = value;
    notifyListeners();
  }

  late bool _draggable =
      !(preferences.getBool(PrefKeys.layoutLocked) ?? Defaults.layoutLocked);

  bool get draggable => _draggable;

  set draggable(bool value) {
    _draggable = value;
    notifyListeners();
  }

  late Rect _draggingRect = Rect.fromLTWH(
    0,
    0,
    (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble(),
    (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble(),
  );

  Rect get draggingRect => _draggingRect;

  set draggingRect(Rect value) {
    _draggingRect = value;
    notifyListeners();
  }

  Offset _cursorGlobalLocation = const Offset(double.nan, double.nan);

  Offset get cursorGlobalLocation => _cursorGlobalLocation;

  set cursorGlobalLocation(Offset value) {
    _cursorGlobalLocation = value;
    notifyListeners();
  }

  late Rect _displayRect = Rect.fromLTWH(
    0,
    0,
    (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble(),
    (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble(),
  );

  Rect get displayRect => _displayRect;

  set displayRect(Rect value) {
    _displayRect = value;
    notifyListeners();
  }

  late Rect _previewRect = Rect.fromLTWH(
    0,
    0,
    (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble(),
    (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble(),
  );

  Rect get previewRect => _previewRect;

  set previewRect(Rect value) {
    _previewRect = value;
    notifyListeners();
  }

  bool _enabled = false;

  bool get enabled => _enabled;

  set enabled(bool value) {
    _enabled = value;
    notifyListeners();
  }

  bool _dragging = false;

  bool get dragging => _dragging;

  set dragging(bool value) {
    _dragging = value;
    notifyListeners();
  }

  bool _resizing = false;

  bool get resizing => _resizing;

  set resizing(bool value) {
    _resizing = value;
    notifyListeners();
  }

  bool _draggingIntoLayout = false;

  bool get draggingIntoLayout => _draggingIntoLayout;

  set draggingIntoLayout(bool value) {
    _draggingIntoLayout = value;
    notifyListeners();
  }

  bool _previewVisible = false;

  bool get previewVisible => _previewVisible;

  set previewVisible(bool value) {
    _previewVisible = value;
    notifyListeners();
  }

  bool _validLocation = true;

  bool get validLocation => _validLocation;

  set validLocation(bool value) {
    _validLocation = value;
    notifyListeners();
  }

  late double minWidth =
      (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble();
  late double minHeight =
      (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble();

  late Rect _dragStartLocation;

  Rect get dragStartLocation => _dragStartLocation;

  set dragStartLocation(Rect value) {
    _dragStartLocation = value;
    notifyListeners();
  }

  WidgetContainerModel({
    required this.preferences,
    required Rect initialPosition,
    required this._title,
    this._enabled = false,
    this.minWidth = 128.0,
    this.minHeight = 128.0,
  }) {
    _displayRect = initialPosition;
    init();
  }

  WidgetContainerModel.fromJson({
    required Map<String, dynamic> jsonData,
    required this.preferences,
    this._enabled = false,
    this.minWidth = 128.0,
    this.minHeight = 128.0,
    Function(String errorMessage)? onJsonLoadingWarning,
  }) {
    fromJson(jsonData);
    init();
  }

  void init() {
    draggingRect = displayRect;
    dragStartLocation = displayRect;
  }

  @mustCallSuper
  Map<String, dynamic> toJson() => {
    'title': title,
    'x': displayRect.left,
    'y': displayRect.top,
    'width': displayRect.width,
    'height': displayRect.height,
  };

  @mustCallSuper
  void fromJson(
    Map<String, dynamic> jsonData, {
    Function(String warningMessage)? onJsonLoadingWarning,
  }) {
    title = tryCast(jsonData['title']) ?? '';

    double x = tryCast(jsonData['x']) ?? 0.0;

    double y = tryCast(jsonData['y']) ?? 0.0;

    double width =
        tryCast(jsonData['width']) ??
        (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble();

    double height =
        tryCast(jsonData['height']) ??
        (preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize).toDouble();

    displayRect = Rect.fromLTWH(x, y, width, height);
  }

  List<ContextMenuEntry> getContextMenuItems() => [];

  void softDispose({bool deleting = false}) {}

  void unSubscribe() {}

  @mustCallSuper
  void updateGridSize(int oldGridSize, int newGridSize) {
    double newX = DraggableWidgetContainer.snapToGrid(
      displayRect.left,
      newGridSize,
    );
    double newY = DraggableWidgetContainer.snapToGrid(
      displayRect.top,
      newGridSize,
    );

    double newWidth = DraggableWidgetContainer.snapToGrid(
      displayRect.width,
      newGridSize,
    ).clamp(minWidth, double.infinity);
    double newHeight = DraggableWidgetContainer.snapToGrid(
      displayRect.height,
      newGridSize,
    ).clamp(minHeight, double.infinity);

    displayRect = Rect.fromLTWH(newX, newY, newWidth, newHeight);
    draggingRect = displayRect;

    notifyListeners();
  }

  void showEditProperties(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Properties'),
        content: SizedBox(
          width: 353,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: getContainerEditProperties(),
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

  List<Widget> getContainerEditProperties() => [
    // Settings for the widget container
    const Text('Container Settings'),
    const SizedBox(height: 5),
    DialogTextInput(
      onSubmit: (value) {
        title = value;
      },
      label: 'Title',
      initialText: title,
    ),
  ];

  WidgetContainer getDraggingWidgetContainer(BuildContext context) =>
      WidgetContainer(
        title: title,
        width: draggingRect.width,
        height: draggingRect.height,
        cornerRadius:
            preferences.getDouble(PrefKeys.cornerRadius) ??
            Defaults.cornerRadius,
        opacity: 0.80,
        child: Container(),
      );

  WidgetContainer getWidgetContainer(BuildContext context) => WidgetContainer(
    title: title,
    width: displayRect.width,
    height: displayRect.height,
    cornerRadius:
        preferences.getDouble(PrefKeys.cornerRadius) ?? Defaults.cornerRadius,
    child: Container(),
  );

  Widget getDefaultPreview() => Positioned(
    left: previewRect.left,
    top: previewRect.top,
    width: previewRect.width,
    height: previewRect.height,
    child: Visibility(
      visible: previewVisible,
      child: Container(
        decoration: BoxDecoration(
          color: (validLocation)
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(
            preferences.getDouble(PrefKeys.cornerRadius) ??
                Defaults.cornerRadius,
          ),
          border: Border.all(
            color: (validLocation)
                ? Colors.lightGreenAccent.shade400
                : Colors.red,
            width: 5.0,
          ),
        ),
      ),
    ),
  );
}
