import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/graph.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> graphJson = {
    'topic': 'Test/Double Value',
    'data_type': 'double',
    'period': 0.100,
    'time_displayed': 10.0,
    'max_value': 1.0,
    'color': Colors.green.toARGB32(),
    'line_width': 3.0,
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
      virtualValues: {'Test/Double Value': 0.0},
    );
  });

  test('Graph from json', () {
    NTWidgetModel graphModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Graph',
      graphJson,
    );

    expect(graphModel.type, 'Graph');
    expect(graphModel.runtimeType, GraphModel);
    expect(
      graphModel.getAvailableDisplayTypes(),
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

    if (graphModel is! GraphModel) {
      return;
    }

    expect(graphModel.timeDisplayed, 10.0);
    expect(graphModel.minValue, isNull);
    expect(graphModel.maxValue, 1.0);
    expect(graphModel.mainColor, Color(Colors.green.toARGB32()));
    expect(graphModel.lineWidth, 3.0);
  });

  test('Graph model to json', () {
    GraphModel graphModel = GraphModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Double Value',
      dataType: NT4Type.double(),
      period: 0.100,
      timeDisplayed: 10.0,
      maxValue: 1.0,
      mainColor: Colors.green,
      lineWidth: 3.0,
    );

    expect(graphModel.toJson(), graphJson);
  });

  testWidgets('Graph widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel graphModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Graph',
      graphJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: graphModel,
            child: const GraphWidget(),
          ),
        ),
      ),
    );

    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('Graph edit properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    GraphModel graphModel =
        NTWidgetRegistry.buildNTModelFromJson(
              ntConnection,
              preferences,
              'Graph',
              graphJson,
            )
            as GraphModel;

    NTWidgetContainerModel ntContainerModel = NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.zero,
      title: 'Graph',
      childModel: graphModel,
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

    final colorPicker = find.widgetWithText(DialogColorPicker, 'Graph Color');
    final timeDisplayed = find.widgetWithText(
      DialogTextInput,
      'Time Displayed (Seconds)',
    );
    final minimum = find.widgetWithText(DialogTextInput, 'Minimum');
    final maximum = find.widgetWithText(DialogTextInput, 'Maximum');
    final lineWidth = find.widgetWithText(DialogTextInput, 'Line Width');

    expect(colorPicker, findsOneWidget);
    expect(timeDisplayed, findsOneWidget);
    expect(minimum, findsOneWidget);
    expect(maximum, findsOneWidget);
    expect(lineWidth, findsOneWidget);

    await widgetTester.enterText(timeDisplayed, '10');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(graphModel.timeDisplayed, 10.0);

    await widgetTester.enterText(minimum, '0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(graphModel.minValue, 0);

    await widgetTester.enterText(maximum, '');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(graphModel.maxValue, isNull);

    await widgetTester.enterText(lineWidth, '2.5');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(graphModel.lineWidth, 2.5);
  });
}
