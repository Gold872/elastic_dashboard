import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/encoder_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> encoderWidgetJson = {
    'topic': 'Test/Encoder',
    'period': 0.100,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Encoder/Distance',
          type: NT4Type.float(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Encoder/Speed',
          type: NT4Type.float(),
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Encoder/Distance': 5.50,
        'Test/Encoder/Speed': -10.0,
      },
    );
  });

  test('Encoder from json', () {
    NTWidgetModel encoderWidgetModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Encoder',
      encoderWidgetJson,
    );

    expect(encoderWidgetModel.type, 'Encoder');
    expect(encoderWidgetModel.runtimeType, EncoderModel);
  });

  test('Encoder alias name', () {
    NTWidgetModel encoderWidgetModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Quadrature Encoder',
      encoderWidgetJson,
    );

    expect(encoderWidgetModel.type, 'Encoder');
    expect(encoderWidgetModel.runtimeType, EncoderModel);
  });

  test('Encoder to json', () {
    EncoderModel encoderWidgetModel = EncoderModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Encoder',
      period: 0.100,
    );

    expect(encoderWidgetModel.toJson(), encoderWidgetJson);
  });

  testWidgets('Encoder widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel encoderWidgetModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Encoder',
      encoderWidgetJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: encoderWidgetModel,
            child: const EncoderWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);

    expect(
      find.descendant(
        of: find.byType(SelectableText),
        matching: find.textContaining('5.50'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SelectableText),
        matching: find.textContaining('-10.00'),
      ),
      findsOneWidget,
    );
  });
}
