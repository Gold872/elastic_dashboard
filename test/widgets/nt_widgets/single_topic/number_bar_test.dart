import 'package:material_ui/material_ui.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/number_bar.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> numberBarJson = {
    'topic': 'Test/Double Value',
    'data_type': NT4Type.double().serialize(),
    'period': 0.100,
    'min_value': -5.0,
    'max_value': 5.0,
    'divisions': 5,
    'inverted': false,
    'orientation': 'horizontal',
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

  test('Number bar from json', () {
    NTWidgetModel numberBarModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Number Bar',
      numberBarJson,
    );

    expect(numberBarModel.type, 'Number Bar');
    expect(numberBarModel.runtimeType, NumberBarModel);
    expect(
      numberBarModel.getAvailableDisplayTypes(),
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

    if (numberBarModel is! NumberBarModel) {
      return;
    }

    expect(numberBarModel.minValue, -5.0);
    expect(numberBarModel.maxValue, 5.0);
    expect(numberBarModel.divisions, 5);
    expect(numberBarModel.inverted, isFalse);
    expect(numberBarModel.orientation, 'horizontal');
  });

  test('Number bar to json', () {
    NumberBarModel numberBarModel = NumberBarModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Double Value',
      dataType: NT4Type.double(),
      period: 0.100,
      minValue: -5.0,
      maxValue: 5.0,
      divisions: 5,
      inverted: false,
      orientation: 'horizontal',
    );

    expect(numberBarModel.toJson(), numberBarJson);
  });

  testWidgets('Number bar widget test horizontal', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel numberBarModel = NumberBarModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Double Value',
      dataType: NT4Type.double(),
      period: 0.100,
      minValue: -5.0,
      maxValue: 5.0,
      divisions: 5,
      inverted: false,
      orientation: 'horizontal',
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: numberBarModel,
            child: const NumberBar(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('-1.00'), findsOneWidget);
    expect(find.byType(LinearGauge), findsOneWidget);

    expect(
      (find.byType(LinearGauge).evaluate().first.widget as LinearGauge)
          .gaugeOrientation,
      GaugeOrientation.horizontal,
    );
  });

  testWidgets('Number bar widget test vertical', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel numberBarModel = NumberBarModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Double Value',
      dataType: NT4Type.double(),
      period: 0.100,
      minValue: -5.0,
      maxValue: 5.0,
      divisions: 5,
      inverted: false,
      orientation: 'vertical',
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: numberBarModel,
            child: const NumberBar(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('-1.00'), findsOneWidget);
    expect(find.byType(LinearGauge), findsOneWidget);

    expect(
      (find.byType(LinearGauge).evaluate().first.widget as LinearGauge)
          .gaugeOrientation,
      GaugeOrientation.vertical,
    );
  });

  testWidgets('Number bar widget test integer', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTConnection ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(name: 'Test/Int Value', type: NT4Type.int(), properties: {}),
      ],
      virtualValues: {'Test/Int Value': -1},
    );

    NTWidgetModel numberBarModel = NumberBarModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Int Value',
      dataType: NT4Type.int(),
      period: 0.100,
      minValue: -5.0,
      maxValue: 5.0,
      divisions: 5,
      inverted: false,
      orientation: 'horizontal',
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: numberBarModel,
            child: const NumberBar(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('-1.00'), findsNothing);
    expect(find.text('-1'), findsOneWidget);
    expect(find.byType(LinearGauge), findsOneWidget);
  });

  testWidgets('Number bar widget test with divisions', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel numberBarModel = NumberBarModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Double Value',
      dataType: NT4Type.double(),
      period: 0.100,
      minValue: -5.0,
      maxValue: 5.0,
      divisions: 11,
      inverted: false,
      orientation: 'horizontal',
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: numberBarModel,
            child: const NumberBar(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('-1.00'), findsOneWidget);
    expect(find.byType(LinearGauge), findsOneWidget);

    expect(
      (find.byType(LinearGauge).evaluate().first.widget as LinearGauge).steps,
      1.0,
    );
  });

  testWidgets('Number bar edit properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NumberBarModel numberBarModel = NumberBarModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Double Value',
      dataType: NT4Type.double(),
      period: 0.100,
      minValue: -5.0,
      maxValue: 5.0,
      divisions: 11,
      inverted: false,
      orientation: 'horizontal',
    );

    NTWidgetContainerModel ntContainerModel = NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.zero,
      title: 'Number Bar',
      childModel: numberBarModel,
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

    final orientation = find.text('Orientation');
    final minimum = find.widgetWithText(DialogTextInput, 'Min Value');
    final maximum = find.widgetWithText(DialogTextInput, 'Max Value');
    final divisions = find.widgetWithText(DialogTextInput, 'Divisions');
    final inverted = find.widgetWithText(DialogToggleSwitch, 'Inverted');

    expect(orientation, findsOneWidget);
    expect(minimum, findsOneWidget);
    expect(maximum, findsOneWidget);
    expect(divisions, findsOneWidget);
    expect(inverted, findsOneWidget);

    expect(find.byType(DialogDropdownChooser<String>), findsNWidgets(2));
    await widgetTester.tap(
      find.byWidget(
        find
            .byType(DialogDropdownChooser<String>)
            .evaluate()
            .elementAt(1)
            .widget,
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(find.text('Vertical'), findsOneWidget);
    await widgetTester.tap(find.text('Vertical'));
    await widgetTester.pumpAndSettle();

    expect(numberBarModel.orientation, 'vertical');

    await widgetTester.enterText(minimum, '-1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(numberBarModel.minValue, -1);

    await widgetTester.enterText(maximum, '1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(numberBarModel.maxValue, 1);

    await widgetTester.enterText(divisions, '10');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(numberBarModel.divisions, 10);

    await widgetTester.enterText(divisions, '1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(numberBarModel.divisions, 10);

    await widgetTester.tap(
      find.descendant(of: inverted, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();

    expect(numberBarModel.inverted, true);
  });
}
