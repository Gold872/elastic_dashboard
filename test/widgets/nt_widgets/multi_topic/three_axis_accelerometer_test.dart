import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/three_axis_accelerometer.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> threeAxisAccelerometerJson = {
    'topic': 'Test/Three Axis Accelerometer',
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
          name: 'Test/Three Axis Accelerometer/X',
          type: NT4Type.float(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Three Axis Accelerometer/Y',
          type: NT4Type.float(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Three Axis Accelerometer/Z',
          type: NT4Type.float(),
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Three Axis Accelerometer/X': 0.100,
        'Test/Three Axis Accelerometer/Y': 0.200,
        'Test/Three Axis Accelerometer/Z': 0.300,
      },
    );
  });

  test('Three axis accelerometer from json', () {
    NTWidgetModel threeAxisAccelerometerModel =
        NTWidgetRegistry.buildNTModelFromJson(
          ntConnection,
          preferences,
          '3-Axis Accelerometer',
          threeAxisAccelerometerJson,
        );

    expect(threeAxisAccelerometerModel.type, '3-Axis Accelerometer');
    expect(
      threeAxisAccelerometerModel.runtimeType,
      ThreeAxisAccelerometerModel,
    );
  });

  test('Three axis accelerometer from alias name', () {
    NTWidgetModel threeAxisAccelerometerModel =
        NTWidgetRegistry.buildNTModelFromJson(
          ntConnection,
          preferences,
          '3AxisAccelerometer',
          threeAxisAccelerometerJson,
        );

    expect(threeAxisAccelerometerModel.type, '3-Axis Accelerometer');
    expect(
      threeAxisAccelerometerModel.runtimeType,
      ThreeAxisAccelerometerModel,
    );
  });

  test('Three axis accelerometer to json', () {
    ThreeAxisAccelerometerModel threeAxisAccelerometerModel =
        ThreeAxisAccelerometerModel(
          ntConnection: ntConnection,
          preferences: preferences,
          topic: 'Test/Three Axis Accelerometer',
          period: 0.100,
        );

    expect(threeAxisAccelerometerModel.toJson(), threeAxisAccelerometerJson);
  });

  testWidgets('Three axis accelerometer widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel threeAxisAccelerometerModel =
        NTWidgetRegistry.buildNTModelFromJson(
          ntConnection,
          preferences,
          '3-Axis Accelerometer',
          threeAxisAccelerometerJson,
        );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: threeAxisAccelerometerModel,
            child: const ThreeAxisAccelerometer(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('0.10 g'), findsOneWidget);
    expect(find.text('0.20 g'), findsOneWidget);
    expect(find.text('0.30 g'), findsOneWidget);
  });
}
