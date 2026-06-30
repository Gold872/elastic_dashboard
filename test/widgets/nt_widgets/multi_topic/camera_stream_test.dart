import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/custom_loading_indicator.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
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
    );

    expect(cameraStreamModel.toJson(), cameraStreamJson);
  });

  test('CameraStreamType fromUrl parsing', () {
    expect(
      CameraStreamType.fromUrl('whep:http://10.20.53.2:8889'),
      CameraStreamType.whep,
    );
    expect(
      CameraStreamType.fromUrl('mjpg:http://10.20.53.2:1181/?action=stream'),
      CameraStreamType.mjpeg,
    );
    expect(CameraStreamType.fromUrl('unknown://test'), isNull);
  });

  test('Camera stream activeStreamType and selection with mixed streams', () {
    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Camera Stream/streams',
          type: NT4Type.string(),
          properties: {},
        ),
      ],
    );

    CameraStreamModel cameraStreamModel = CameraStreamModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Camera Stream',
      period: 0.100,
    );

    expect(cameraStreamModel.activeStreamType, CameraStreamType.mjpeg);

    ntConnection.updateDataFromTopicName('Test/Camera Stream/streams', [
      'mjpg:http://10.0.0.1',
    ]);
    expect(cameraStreamModel.activeStreamType, CameraStreamType.mjpeg);

    ntConnection.updateDataFromTopicName('Test/Camera Stream/streams', [
      'whep:http://10.0.0.1:8889',
      'mjpg:http://10.0.0.1',
    ]);
    expect(cameraStreamModel.activeStreamType, CameraStreamType.whep);

    cameraStreamModel.selectedStreamType = CameraStreamType.mjpeg;
    expect(cameraStreamModel.activeStreamType, CameraStreamType.mjpeg);
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

    expect(fps, findsOneWidget);
    expect(width, findsOneWidget);
    expect(height, findsOneWidget);
    expect(quality, findsOneWidget);
    expect(rotateLeft, findsOneWidget);
    expect(rotateRight, findsOneWidget);

    await widgetTester.enterText(fps, '25');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.fps, 25);

    await widgetTester.enterText(fps, '0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.fps, isNull);

    await widgetTester.enterText(width, '640');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.resolution?.width, 640);

    await widgetTester.enterText(height, '480');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.resolution?.height, 480);

    await widgetTester.enterText(width, '0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(cameraStreamModel.resolution, isNull);

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
  });
}
