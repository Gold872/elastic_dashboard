import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/ultrasonic.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> ultrasonicJson = {
    'topic': 'Test/Ultrasonic',
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
          name: 'Test/Ultrasonic/Value',
          type: NT4Type.float(),
          properties: {},
        ),
      ],
      virtualValues: {'Test/Ultrasonic/Value': 0.12},
    );
  });

  test('Ultrasonic from json', () {
    NTWidgetModel ultrasonicModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Ultrasonic',
      ultrasonicJson,
    );

    expect(ultrasonicModel.type, 'Ultrasonic');
    expect(ultrasonicModel.runtimeType, UltrasonicModel);
  });

  test('Ultrasonic to json', () {
    UltrasonicModel ultrasonicModel = UltrasonicModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Ultrasonic',
      period: 0.100,
    );

    expect(ultrasonicModel.toJson(), ultrasonicJson);
  });

  testWidgets('Ultrasonic widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel ultrasonicModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Ultrasonic',
      ultrasonicJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: ultrasonicModel,
            child: const Ultrasonic(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Range'), findsOneWidget);
    expect(find.text('0.12000 in'), findsOneWidget);
  });
}
