import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/custom_loading_indicator.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/camera_stream.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> cameraStreamJson = {
    'topic': 'Test/Camera Stream',
    'period': 0.100,
    'rotation_turns': 0,
    'compression': 50,
    'fps': 60,
    'resolution': [100.0, 100.0],
    'crosshair_enabled': false,
    'crosshair_width': 25,
    'crosshair_height': 35,
    'crosshair_thickness': 2,
    'crosshair_x': 15,
    'crosshair_y': 10,
    'crosshair_color': 4294198070, //Colors.red.toARGB32()
    'crosshair_centered': false,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4();
  });

  test('Camera stream from json', () {
    NTWidgetModel cameraStreamModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Camera Stream',
      cameraStreamJson,
    );

    expect(cameraStreamModel.type, 'Camera Stream');
    expect(cameraStreamModel.runtimeType, CameraStreamModel);

    if (cameraStreamModel is! CameraStreamModel) {
      return;
    }

    expect(cameraStreamModel.rotationTurns, 0);
    expect(cameraStreamModel.fps, 60);
    expect(cameraStreamModel.quality, 50);
    expect(cameraStreamModel.resolution, const Size(100.0, 100.0));

    expect(cameraStreamModel.crosshairEnabled, false);
    expect(cameraStreamModel.crosshairWidth, 25);
    expect(cameraStreamModel.crosshairHeight, 35);
    expect(cameraStreamModel.crosshairThickness, 2);
    expect(cameraStreamModel.crosshairX, 15);
    expect(cameraStreamModel.crosshairY, 10);
    expect(cameraStreamModel.crosshairColor, Color(Colors.red.toARGB32()));

    expect(
      cameraStreamModel.getUrlWithParameters('0.0.0.0'),
      '0.0.0.0?resolution=100x100&fps=60&compression=50',
    );

    cameraStreamModel.fps = null;

    expect(
      cameraStreamModel.getUrlWithParameters('0.0.0.0'),
      '0.0.0.0?resolution=100x100&compression=50',
    );

    cameraStreamModel.resolution = const Size(0.0, 100);

    expect(
      cameraStreamModel.getUrlWithParameters('0.0.0.0'),
      '0.0.0.0?compression=50',
    );

    cameraStreamModel.quality = null;

    expect(cameraStreamModel.getUrlWithParameters('0.0.0.0'), '0.0.0.0?');
  });

  test('Camera stream from json (with invalid resolution)', () {
    NTWidgetModel cameraStreamModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Camera Stream',
      {...cameraStreamJson}..update('resolution', (_) => [101.0, 100.0]),
    );

    expect(cameraStreamModel.type, 'Camera Stream');
    expect(cameraStreamModel.runtimeType, CameraStreamModel);

    if (cameraStreamModel is! CameraStreamModel) {
      return;
    }
    expect(cameraStreamModel.resolution, const Size(102.0, 100.0));

    expect(
      cameraStreamModel.getUrlWithParameters('0.0.0.0'),
      '0.0.0.0?resolution=102x100&fps=60&compression=50',
    );
  });

  test('Camera stream from json (with negative resolution)', () {
    NTWidgetModel cameraStreamModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Camera Stream',
      {...cameraStreamJson}..update('resolution', (_) => [-1, 100.0]),
    );

    expect(cameraStreamModel.type, 'Camera Stream');
    expect(cameraStreamModel.runtimeType, CameraStreamModel);

    if (cameraStreamModel is! CameraStreamModel) {
      return;
    }

    expect(cameraStreamModel.resolution, isNull);

    expect(
      cameraStreamModel.getUrlWithParameters('0.0.0.0'),
      '0.0.0.0?fps=60&compression=50',
    );
  });

  test('Camera stream to json', () {
    CameraStreamModel cameraStreamModel = CameraStreamModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Camera Stream',
      rotation: 0,
      period: 0.100,
      compression: 50,
      fps: 60,
      resolution: const Size(100.0, 100.0),
      crosshairEnabled: false,
      crosshairWidth: 25,
      crosshairHeight: 35,
      crosshairThickness: 2,
      crosshairX: 15,
      crosshairY: 10,
      crosshairColor: Colors.red,
    );

    expect(cameraStreamModel.toJson(), cameraStreamJson);
  });

  testWidgets('Camera stream online widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel cameraStreamModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Camera Stream',
      cameraStreamJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: cameraStreamModel,
            child: const CameraStreamWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(CustomLoadingIndicator), findsOneWidget);
    expect(
      find.text('Waiting for Camera Stream connection...'),
      findsOneWidget,
    );
  });

  testWidgets('Camera stream offline widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel cameraStreamModel = NTWidgetRegistry.buildNTModelFromJson(
      createMockOfflineNT4(),
      preferences,
      'Camera Stream',
      cameraStreamJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: cameraStreamModel,
            child: const CameraStreamWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(CustomLoadingIndicator), findsOneWidget);
    expect(
      find.text('Waiting for Network Tables connection...'),
      findsOneWidget,
    );
  });

  testWidgets('Camera stream edit properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    CameraStreamModel cameraStreamModel = CameraStreamModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Camera Stream',
      period: 0.100,
      rotation: 0,
      compression: 50,
      fps: 60,
      resolution: const Size(100.0, 100.0),
      crosshairEnabled: false,
      crosshairWidth: 15,
      crosshairHeight: 15,
      crosshairThickness: 2,
      crosshairX: 0,
      crosshairY: 0,
      crosshairColor: Colors.red,
    );

    NTWidgetContainerModel ntContainerModel = NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.zero,
      title: 'Camera Stream',
      childModel: cameraStreamModel,
    );

    final key = GlobalKey();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetContainerModel>.value(
            key: key,
            value: ntContainerModel,
            child: const DraggableNTWidgetContainer(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    ntContainerModel.showEditProperties(key.currentContext!);

    await widgetTester.pumpAndSettle();

    final fps = find.widgetWithText(DialogTextInput, 'FPS');
    final width = find.widgetWithText(DialogTextInput, 'Width');
    final height = find.widgetWithText(DialogTextInput, 'Height');
    final quality = find.byType(Slider);
    final rotateLeft = find.ancestor(
      of: find.text('Rotate Left'),
      matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
    );
    final rotateRight = find.ancestor(
      of: find.text('Rotate Right'),
      matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
    );

    final crosshairEnabled = find.ancestor(
      of: find.text('Enabled'),
      matching: find.byWidgetPredicate(
        (widget) => widget is DialogToggleSwitch,
      ),
    );
    final crosshairX = find.widgetWithText(DialogTextInput, 'X Position');
    final crosshairY = find.widgetWithText(DialogTextInput, 'Y Position');
    final crosshairThickness = find.widgetWithText(
      DialogTextInput,
      'Thickness',
    );
    final crosshairColor = find.ancestor(
      of: find.text('Crosshair Color'),
      matching: find.byWidgetPredicate((widget) => widget is DialogColorPicker),
    );
    expect(fps, findsOneWidget);
    expect(width, findsNWidgets(2));
    expect(height, findsNWidgets(2));
    expect(quality, findsOneWidget);
    expect(rotateLeft, findsOneWidget);
    expect(rotateRight, findsOneWidget);
    expect(crosshairEnabled, findsOneWidget);
    expect(crosshairX, findsOneWidget);
    expect(crosshairY, findsOneWidget);
    expect(crosshairColor, findsOneWidget);
    expect(crosshairThickness, findsOneWidget);

    await widgetTester.enterText(fps, '25');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.fps, 25);

    await widgetTester.enterText(fps, '0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.fps, isNull);

    await widgetTester.enterText(width.first, '640');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.resolution?.width, 640);
    expect(cameraStreamModel.crosshairWidth, 15);

    await widgetTester.enterText(height.first, '480');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.resolution?.height, 480);
    expect(cameraStreamModel.crosshairHeight, 15);

    await widgetTester.enterText(width.first, '0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.resolution, isNull);
    expect(cameraStreamModel.crosshairWidth, 15);

    await widgetTester.drag(quality, const Offset(100, 0));
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.quality, isNotNull);

    await widgetTester.drag(quality, const Offset(-100, 0));
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.quality, isNull);

    await widgetTester.ensureVisible(rotateRight);
    await widgetTester.tap(rotateRight);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.rotationTurns, 1);

    await widgetTester.tap(rotateRight);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.rotationTurns, 2);

    await widgetTester.tap(rotateRight);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.rotationTurns, 3);

    await widgetTester.tap(rotateRight);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.rotationTurns, 0);

    await widgetTester.ensureVisible(rotateLeft);
    await widgetTester.tap(rotateLeft);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.rotationTurns, 3);

    await widgetTester.tap(rotateLeft);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.rotationTurns, 2);

    await widgetTester.tap(
      find.descendant(
        of: crosshairEnabled,
        matching: find.byType(Switch),
      ),
    );
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.crosshairEnabled, true);

    await widgetTester.enterText(crosshairX, '25');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.crosshairX, 25);

    await widgetTester.enterText(crosshairY, '25');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.crosshairY, 25);

    await widgetTester.enterText(width.last, '25');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.crosshairWidth, 25);
    expect(cameraStreamModel.resolution, isNull);

    await widgetTester.enterText(height.last, '45');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.crosshairHeight, 45);
    expect(cameraStreamModel.resolution, isNull);

    await widgetTester.enterText(crosshairThickness, '3');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.crosshairThickness, 3);
  });
}
