import 'package:material_ui/material_ui.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/number_slider.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> numberSliderJson = {
    'topic': 'Test/Double Value',
    'data_type': NT4Type.double().serialize(),
    'period': 0.100,
    'min_value': -5.0,
    'max_value': 5.0,
    'divisions': 5,
    'update_continuously': true,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Double Value',
          type: NT4Type.double(),
          properties: {},
        ),
      ],
      virtualValues: {'Test/Double Value': -1.0},
    );
  });

  test('Number slider from json', () {
    NTWidgetModel numberSliderModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Number Slider',
      numberSliderJson,
    );

    expect(numberSliderModel.type, 'Number Slider');
    expect(numberSliderModel.runtimeType, NumberSliderModel);
    expect(
      numberSliderModel.getAvailableDisplayTypes(),
      unorderedEquals([
        'Text Display',
        'Number Bar',
        'Number Slider',
        'Graph',
        'Voltage View',
        'Radial Gauge',
        'Match Time',
        'Large Text Display',
      ]),
    );

    if (numberSliderModel is! NumberSliderModel) {
      return;
    }

    expect(numberSliderModel.minValue, -5.0);
    expect(numberSliderModel.maxValue, 5.0);
    expect(numberSliderModel.divisions, 5);
    expect(numberSliderModel.updateContinuously, isTrue);
  });

  test('Number slider to json', () {
    NumberSliderModel numberSliderModel = NumberSliderModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Double Value',
      dataType: NT4Type.double(),
      period: 0.100,
      minValue: -5.0,
      maxValue: 5.0,
      divisions: 5,
      updateContinuously: true,
    );

    expect(numberSliderModel.toJson(), numberSliderJson);
  });

  testWidgets('Number slider widget test continuous update', (
    widgetTester,
  ) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel numberSliderModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Number Slider',
      numberSliderJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: numberSliderModel,
            child: const NumberSlider(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('-1.00'), findsOneWidget);
    expect(find.byType(LinearGauge), findsOneWidget);
    expect(find.byType(Pointer), findsOneWidget);

    Future<void> pointerDrag = widgetTester.timedDrag(
      find.byType(Pointer),
      const Offset(100.0, 0.0),
      const Duration(seconds: 1),
    );

    // Stupid workaround since expect can't be used during a drag
    bool? draggingDuringDrag;
    Object? valueDuringDrag;

    Future.delayed(const Duration(milliseconds: 500), () {
      draggingDuringDrag =
          (numberSliderModel as NumberSliderModel).dragging.value;
      valueDuringDrag = ntConnection.getLastAnnouncedValue('Test/Double Value');
    });

    await pointerDrag;

    expect(draggingDuringDrag, isTrue);
    expect(valueDuringDrag, isNot(-1.0));

    expect(
      ntConnection.getLastAnnouncedValue('Test/Double Value'),
      greaterThan(0.0),
    );
  });

  testWidgets('Number slider widget test non-continuous update', (
    widgetTester,
  ) async {
    FlutterError.onError = ignoreOverflowErrors;

    NumberSliderModel numberSliderModel = NumberSliderModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Double Value',
      dataType: NT4Type.double(),
      period: 0.100,
      minValue: -5.0,
      maxValue: 5.0,
      divisions: 5,
      updateContinuously: false,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: numberSliderModel,
            child: const NumberSlider(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('-1.00'), findsOneWidget);
    expect(find.byType(LinearGauge), findsOneWidget);
    expect(find.byType(Pointer), findsOneWidget);

    Future<void> pointerDrag = widgetTester.timedDrag(
      find.byType(Pointer),
      const Offset(100.0, 0.0),
      const Duration(seconds: 1),
    );

    // Stupid workaround since expect can't be used during a drag
    bool? draggingDuringDrag;
    Object? valueDuringDrag;

    Future.delayed(const Duration(milliseconds: 500), () {
      draggingDuringDrag = numberSliderModel.dragging.value;
      valueDuringDrag = ntConnection.getLastAnnouncedValue('Test/Double Value');
    });

    await pointerDrag;

    expect(draggingDuringDrag, isTrue);
    expect(valueDuringDrag, -1.0);

    expect(
      ntConnection.getLastAnnouncedValue('Test/Double Value'),
      greaterThan(0.0),
    );
  });

  testWidgets('Number slider widget test integer', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTConnection ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(name: 'Test/Int Value', type: NT4Type.int(), properties: {}),
      ],
      virtualValues: {'Test/Int Value': -1},
    );

    NumberSliderModel numberSliderModel = NumberSliderModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Int Value',
      dataType: NT4Type.int(),
      period: 0.100,
      minValue: -5.0,
      maxValue: 5.0,
      divisions: 5,
      updateContinuously: false,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: numberSliderModel,
            child: const NumberSlider(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('-1.00'), findsNothing);
    expect(find.text('-1'), findsOneWidget);
    expect(find.byType(LinearGauge), findsOneWidget);
    expect(find.byType(Pointer), findsOneWidget);

    Future<void> pointerDrag = widgetTester.timedDrag(
      find.byType(Pointer),
      const Offset(200.0, 0.0),
      const Duration(seconds: 1),
    );

    // Stupid workaround since expect can't be used during a drag
    bool? draggingDuringDrag;
    Object? valueDuringDrag;

    Future.delayed(const Duration(milliseconds: 500), () {
      draggingDuringDrag = numberSliderModel.dragging.value;
      valueDuringDrag = ntConnection.getLastAnnouncedValue('Test/Int Value');
    });

    await pointerDrag;

    expect(draggingDuringDrag, isTrue);
    expect(valueDuringDrag, -1);

    expect(
      ntConnection.getLastAnnouncedValue('Test/Int Value'),
      greaterThan(0),
    );

    expect(
      ntConnection.getLastAnnouncedValue('Test/Int Value').runtimeType,
      int,
    );
  });

  testWidgets('Number slider edit properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NumberSliderModel numberSliderModel = NumberSliderModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Double Value',
      dataType: NT4Type.double(),
      period: 0.100,
      minValue: -5.0,
      maxValue: 5.0,
      divisions: 5,
      updateContinuously: false,
    );

    NTWidgetContainerModel ntContainerModel = NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.fromLTWH(
        0,
        0,
        3 * NTWidgetRegistry.getNormalSize(),
        NTWidgetRegistry.getNormalSize(),
      ),
      title: 'Number Slider',
      childModel: numberSliderModel,
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

    final minimum = find.widgetWithText(DialogTextInput, 'Min Value');
    final maximum = find.widgetWithText(DialogTextInput, 'Max Value');
    final divisions = find.widgetWithText(DialogTextInput, 'Divisions');
    final updateWhileDragging = find.widgetWithText(
      DialogToggleSwitch,
      'Update While Dragging',
    );

    expect(minimum, findsOneWidget);
    expect(maximum, findsOneWidget);
    expect(divisions, findsOneWidget);
    expect(updateWhileDragging, findsOneWidget);

    await widgetTester.enterText(minimum, '-1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(numberSliderModel.minValue, -1);

    await widgetTester.enterText(maximum, '1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(numberSliderModel.maxValue, 1);

    await widgetTester.enterText(divisions, '10');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(numberSliderModel.divisions, 10);

    await widgetTester.enterText(divisions, '1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(numberSliderModel.divisions, 10);

    await widgetTester.tap(
      find.descendant(of: updateWhileDragging, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();

    expect(numberSliderModel.updateContinuously, true);
  });
}
