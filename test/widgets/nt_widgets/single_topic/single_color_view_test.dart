import 'package:material_ui/material_ui.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/single_color_view.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> singleColorViewJson = {
    'topic': 'Test/String Value',
    'data_type': NT4Type.string().serialize(),
    'period': 0.100,
  };

  Finder findColor(Color color) => find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).color != null &&
        (widget.decoration as BoxDecoration).color!.toARGB32() ==
            color.toARGB32(),
  );

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/String Value',
          type: NT4Type.string(),
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/String Value': Colors.red.toHexString(
          includeHashSign: true,
          enableAlpha: false,
        ),
      },
    );
  });

  test('Single color view from json', () {
    NTWidgetModel singleColorViewModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Single Color View',
      singleColorViewJson,
    );

    expect(singleColorViewModel.type, 'Single Color View');
    expect(singleColorViewModel.runtimeType, SingleTopicNTWidgetModel);
    expect(
      singleColorViewModel.getAvailableDisplayTypes(),
      unorderedEquals([
        'Text Display',
        'Large Text Display',
        'Single Color View',
      ]),
    );
  });

  test('Single color view to json', () {
    NTWidgetModel singleColorViewModel = SingleTopicNTWidgetModel.createDefault(
      ntConnection: ntConnection,
      preferences: preferences,
      type: 'Single Color View',
      topic: 'Test/String Value',
      dataType: NT4Type.string(),
      period: 0.100,
    );

    expect(singleColorViewModel.toJson(), singleColorViewJson);
  });

  testWidgets('Single color view widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel singleColorViewModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Single Color View',
      singleColorViewJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: singleColorViewModel,
            child: const SingleColorView(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(findColor(Colors.red), findsOneWidget);
  });
}
