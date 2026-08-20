import 'package:collection/collection.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/multi_color_view.dart';

import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> multiColorViewJson = {
    'topic': 'Test/String Array',
    'data_type': 'string[]',
    'period': 0.100,
  };

  Finder findGradient(List<Color> expectedColors) => find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).gradient != null &&
        (widget.decoration as BoxDecoration).gradient!.colors.equals(
          expectedColors,
        ),
  );

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/String Array',
          type: NT4Type.array(NT4Type.string()),
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/String Array': [
          Colors.red.toHexString(includeHashSign: true),
          Colors.orange.toHexString(includeHashSign: true),
          Colors.yellow.toHexString(includeHashSign: true),
          Colors.green.toHexString(includeHashSign: true),
          Colors.blue.toHexString(includeHashSign: true),
          Colors.purple.toHexString(includeHashSign: true),
        ],
      },
    );
  });

  test('Multi color view from json', () {
    NTWidgetModel multiColorViewModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Multi Color View',
      multiColorViewJson,
    );

    expect(multiColorViewModel.type, 'Multi Color View');
    expect(multiColorViewModel.runtimeType, SingleTopicNTWidgetModel);
    expect(
      multiColorViewModel.getAvailableDisplayTypes(),
      unorderedEquals([
        'Multi Color View',
        'Text Display',
        'Large Text Display',
      ]),
    );
  });

  test('Multi color view to json', () {
    NTWidgetModel multiColorViewModel = SingleTopicNTWidgetModel.createDefault(
      ntConnection: ntConnection,
      preferences: preferences,
      type: 'Multi Color View',
      topic: 'Test/String Array',
      dataType: NT4Type.array(NT4Type.string()),
      period: 0.100,
    );

    expect(multiColorViewModel.toJson(), multiColorViewJson);
  });

  testWidgets('Multi color view widget test full gradient', (
    widgetTester,
  ) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel multiColorViewModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Multi Color View',
      multiColorViewJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: multiColorViewModel,
            child: const MultiColorView(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    List<Color> expectedColors = [
      Color(Colors.red.toARGB32()),
      Color(Colors.orange.toARGB32()),
      Color(Colors.yellow.toARGB32()),
      Color(Colors.green.toARGB32()),
      Color(Colors.blue.toARGB32()),
      Color(Colors.purple.toARGB32()),
    ];

    expect(findGradient(expectedColors), findsOneWidget);
  });

  testWidgets('Multi color view widget test one color', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel multiColorViewModel = NTWidgetRegistry.buildNTModelFromJson(
      createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
            name: 'Test/String Array',
            type: NT4Type.array(NT4Type.string()),
            properties: {},
          ),
        ],
        virtualValues: {
          'Test/String Array': [Colors.red.toHexString(includeHashSign: true)],
        },
      ),
      preferences,
      'Multi Color View',
      multiColorViewJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: multiColorViewModel,
            child: const MultiColorView(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(
      findGradient([
        Color(Colors.red.toARGB32()),
        Color(Colors.red.toARGB32()),
      ]),
      findsOneWidget,
    );
  });

  testWidgets('Multi color view widget test no colors', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel multiColorViewModel = NTWidgetRegistry.buildNTModelFromJson(
      createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
            name: 'Test/String Array',
            type: NT4Type.array(NT4Type.string()),
            properties: {},
          ),
        ],
        virtualValues: {'Test/String Array': []},
      ),
      preferences,
      'Multi Color View',
      multiColorViewJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: multiColorViewModel,
            child: const MultiColorView(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(
      findGradient([
        Color(Colors.transparent.toARGB32()),
        Color(Colors.transparent.toARGB32()),
      ]),
      findsOneWidget,
    );
  });
}
