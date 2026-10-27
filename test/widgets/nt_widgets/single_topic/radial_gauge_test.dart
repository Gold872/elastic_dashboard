import 'package:flutter_test/flutter_test.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/radial_gauge.dart';

import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> radialGaugeJson = {
    'topic': 'Test/Double Value',
    'data_type': NT4Type.double().serialize(),
    'period': 0.100,
    'start_angle': -140.0,
    'end_angle': 140.0,
    'min_value': -1.0,
    'max_value': 1.0,
    'number_of_labels': 10,
    'wrap_value': false,
    'show_pointer': true,
    'show_ticks': true,
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
      virtualValues: {'Test/Double Value': -0.50},
    );
  });

  test('Radial gauge from json', () {
    NTWidgetModel radialGaugeModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Radial Gauge',
      radialGaugeJson,
    );

    expect(radialGaugeModel.type, 'Radial Gauge');
    expect(radialGaugeModel.runtimeType, RadialGaugeModel);
    expect(
      radialGaugeModel.getAvailableDisplayTypes(),
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

    if (radialGaugeModel is! RadialGaugeModel) {
      return;
    }

    expect(radialGaugeModel.startAngle, -140.0);
    expect(radialGaugeModel.endAngle, 140.0);
    expect(radialGaugeModel.minValue, -1.0);
    expect(radialGaugeModel.maxValue, 1.0);
    expect(radialGaugeModel.numberOfLabels, 10);
    expect(radialGaugeModel.wrapValue, isFalse);
    expect(radialGaugeModel.showPointer, isTrue);
    expect(radialGaugeModel.showTicks, isTrue);
  });

  test('Radial gauge from alias name', () {
    NTWidgetModel radialGaugeModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Simple Dial',
      radialGaugeJson,
    );

    expect(radialGaugeModel.type, 'Radial Gauge');
    expect(radialGaugeModel.runtimeType, RadialGaugeModel);
    expect(
      radialGaugeModel.getAvailableDisplayTypes(),
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

    if (radialGaugeModel is! RadialGaugeModel) {
      return;
    }

    expect(radialGaugeModel.startAngle, -140.0);
    expect(radialGaugeModel.endAngle, 140.0);
    expect(radialGaugeModel.minValue, -1.0);
    expect(radialGaugeModel.maxValue, 1.0);
    expect(radialGaugeModel.numberOfLabels, 10);
    expect(radialGaugeModel.wrapValue, isFalse);
    expect(radialGaugeModel.showPointer, isTrue);
    expect(radialGaugeModel.showTicks, isTrue);
  });

  test('Radial gauge to json', () {
    RadialGaugeModel radialGaugeModel = RadialGaugeModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Double Value',
      dataType: NT4Type.double(),
      period: 0.100,
      startAngle: -140.0,
      endAngle: 140.0,
      minValue: -1.0,
      maxValue: 1.0,
      numberOfLabels: 10,
      wrapValue: false,
      showPointer: true,
      showTicks: true,
    );

    expect(radialGaugeModel.toJson(), radialGaugeJson);
  });

  testWidgets('Radial gauge widget test with pointer', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    RadialGaugeModel radialGaugeModel = RadialGaugeModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Double Value',
      dataType: NT4Type.double(),
      period: 0.100,
      startAngle: -140.0,
      endAngle: 140.0,
      minValue: -1.0,
      maxValue: 1.0,
      numberOfLabels: 10,
      wrapValue: false,
      showPointer: true,
      showTicks: true,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: radialGaugeModel,
            child: const RadialGaugeWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(RadialGauge), findsOneWidget);
    expect(find.text('-0.50'), findsOneWidget);
    expect(find.byType(NeedlePointer), findsOneWidget);
  });

  testWidgets('Radial gauge widget test integer', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTConnection ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(name: 'Test/Int Value', type: NT4Type.int(), properties: {}),
      ],
      virtualValues: {'Test/Int Value': -1},
    );

    RadialGaugeModel radialGaugeModel = RadialGaugeModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Int Value',
      dataType: NT4Type.int(),
      period: 0.100,
      startAngle: -140.0,
      endAngle: 140.0,
      minValue: -1.0,
      maxValue: 1.0,
      numberOfLabels: 10,
      wrapValue: false,
      showPointer: true,
      showTicks: true,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: radialGaugeModel,
            child: const RadialGaugeWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(RadialGauge), findsOneWidget);
    expect(find.text('-1.00'), findsNothing);
    expect(find.text('-1'), findsOneWidget);
    expect(find.byType(NeedlePointer), findsOneWidget);
  });

  testWidgets('Radial gauge widget test no pointer', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    RadialGaugeModel radialGaugeModel = RadialGaugeModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Double Value',
      dataType: NT4Type.double(),
      period: 0.100,
      startAngle: -140.0,
      endAngle: 140.0,
      minValue: -1.0,
      maxValue: 1.0,
      numberOfLabels: 10,
      wrapValue: false,
      showPointer: false,
      showTicks: false,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: radialGaugeModel,
            child: const RadialGaugeWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(RadialGauge), findsOneWidget);
    expect(find.text('-0.50'), findsOneWidget);
    expect(find.byType(NeedlePointer), findsNothing);
  });

  testWidgets('Radial gauge edit properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    RadialGaugeModel radialGaugeModel = RadialGaugeModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Double Value',
      dataType: NT4Type.double(),
      period: 0.100,
      startAngle: -140.0,
      endAngle: 140.0,
      minValue: -1.0,
      maxValue: 1.0,
      numberOfLabels: 10,
      wrapValue: false,
      showPointer: true,
      showTicks: true,
    );

    NTWidgetContainerModel ntContainerModel = NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.zero,
      title: 'Radial Gauge',
      childModel: radialGaugeModel,
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

    final startAngle = find.widgetWithText(
      DialogTextInput,
      'Start Angle (CW+)',
    );
    final endAngle = find.widgetWithText(DialogTextInput, 'End Angle (CW+)');
    final minimum = find.widgetWithText(DialogTextInput, 'Min Value');
    final maximum = find.widgetWithText(DialogTextInput, 'Max Value');
    final wrapValue = find.widgetWithText(DialogToggleSwitch, 'Wrap Value');
    final labels = find.widgetWithText(DialogTextInput, 'Number of Labels');
    final showPointer = find.widgetWithText(DialogToggleSwitch, 'Show Pointer');
    final showTicks = find.widgetWithText(DialogToggleSwitch, 'Show Ticks');

    expect(startAngle, findsOneWidget);
    expect(endAngle, findsOneWidget);
    expect(minimum, findsOneWidget);
    expect(maximum, findsOneWidget);
    expect(wrapValue, findsOneWidget);
    expect(labels, findsOneWidget);
    expect(showPointer, findsOneWidget);
    expect(showTicks, findsOneWidget);

    await widgetTester.enterText(startAngle, '-90');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(radialGaugeModel.startAngle, -90);

    await widgetTester.enterText(endAngle, '90');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(radialGaugeModel.endAngle, 90);

    await widgetTester.enterText(minimum, '-1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(radialGaugeModel.minValue, -1);

    await widgetTester.enterText(maximum, '1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(radialGaugeModel.maxValue, 1);

    await widgetTester.ensureVisible(wrapValue);
    await widgetTester.tap(
      find.descendant(of: wrapValue, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();

    expect(radialGaugeModel.wrapValue, true);

    await widgetTester.enterText(labels, '10');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(radialGaugeModel.numberOfLabels, 10);

    await widgetTester.tap(
      find.descendant(of: showPointer, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();

    expect(radialGaugeModel.showPointer, false);

    await widgetTester.tap(
      find.descendant(of: showTicks, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();

    expect(radialGaugeModel.showTicks, false);
  });
}
