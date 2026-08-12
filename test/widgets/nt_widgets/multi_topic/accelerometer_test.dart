import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/accelerometer.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> accelerometerJson = {
    'topic': 'Test/Test Accelerometer',
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
          name: 'Test/Test Accelerometer/Value',
          type: NT4Type.float(),
          properties: {},
        ),
      ],
      virtualValues: {'Test/Test Accelerometer/Value': 0.50},
    );
  });

  test('Creating accelerometer from json', () {
    NTWidgetModel accelerometerModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Accelerometer',
      accelerometerJson,
    );

    expect(accelerometerModel.type, 'Accelerometer');
    expect(accelerometerModel.runtimeType, AccelerometerModel);

    expect(
      (accelerometerModel as AccelerometerModel).valueTopic,
      'Test/Test Accelerometer/Value',
    );
  });

  test('Saving accelerometer to json', () {
    AccelerometerModel accelerometerModel = AccelerometerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Test Accelerometer',
      period: 0.100,
    );

    expect(accelerometerModel.toJson(), accelerometerJson);
  });

  testWidgets('Accelerometer widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel accelerometerModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Accelerometer',
      accelerometerJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: accelerometerModel,
            child: const AccelerometerWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('0.50 g'), findsOneWidget);
  });
}
