import 'package:material_ui/material_ui.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/large_text_display.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> largeTextDisplayJson = {
    'topic': 'Test/Large Text',
    'data_type': 'string',
    'period': 0.100,
  };

  late NTConnection ntConnection;
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Large Text',
          type: NT4Type.string(),
          properties: {},
        ),
      ],
      virtualValues: {'Test/Large Text': 'Large Text!'},
    );
  });

  test('Large text display from json', () {
    NTWidgetModel largeTextModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Large Text Display',
      largeTextDisplayJson,
    );

    expect(largeTextModel.type, 'Large Text Display');
    expect(largeTextModel.runtimeType, SingleTopicNTWidgetModel);
    expect(
      largeTextModel.getAvailableDisplayTypes(),
      unorderedEquals([
        'Text Display',
        'Large Text Display',
        'Single Color View',
      ]),
    );
  });

  test('Large text display to json', () {
    NTWidgetModel largeTextDisplayModel =
        SingleTopicNTWidgetModel.createDefault(
          ntConnection: ntConnection,
          preferences: preferences,
          type: 'Large Text Display',
          topic: 'Test/Large Text',
          dataType: NT4Type.string(),
          period: 0.100,
        );

    expect(largeTextDisplayModel.toJson(), largeTextDisplayJson);
  });

  testWidgets('Large text display widget', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel largeTextDisplayModel =
        SingleTopicNTWidgetModel.createDefault(
          ntConnection: ntConnection,
          preferences: preferences,
          type: 'Large Text Display',
          topic: 'Test/Large Text',
          dataType: NT4Type.string(),
          period: 0.100,
        );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: largeTextDisplayModel,
            child: const LargeTextDisplay(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Large Text!'), findsOneWidget);
  });
}
