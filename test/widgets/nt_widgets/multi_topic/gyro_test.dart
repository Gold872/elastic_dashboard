import 'package:material_ui/material_ui.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/gyro.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> gyroJson = {
    'topic': 'Test/Gyro',
    'period': 0.100,
    'counter_clockwise_positive': true,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Gyro/Value',
          type: NT4Type.float(),
          properties: {},
        ),
      ],
      virtualValues: {'Test/Gyro/Value': 183.5},
    );
  });

  test('Gyro from json', () {
    NTWidgetModel gyroModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Gyro',
      gyroJson,
    );

    expect(gyroModel.type, 'Gyro');
    expect(gyroModel.runtimeType, GyroModel);

    if (gyroModel is! GyroModel) {
      return;
    }

    expect(gyroModel.counterClockwisePositive, isTrue);
  });

  test('Gyro to json', () {
    GyroModel gyroModel = GyroModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Gyro',
      period: 0.100,
      counterClockwisePositive: true,
    );

    expect(gyroModel.toJson(), gyroJson);
  });

  testWidgets('Gyro widget', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel gyroModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Gyro',
      gyroJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: gyroModel,
            child: const Gyro(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('176.50'), findsOneWidget);
    expect(find.byType(RadialGauge), findsOneWidget);
  });

  testWidgets('Gyro widget edit properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    GyroModel gyroModel = GyroModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Gyro',
      period: 0.100,
      counterClockwisePositive: true,
    );

    NTWidgetContainerModel ntContainerModel = NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.zero,
      title: 'Gyro',
      childModel: gyroModel,
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

    final ccwPositive = find.widgetWithText(
      DialogToggleSwitch,
      'Counter Clockwise Positive',
    );

    expect(ccwPositive, findsOneWidget);

    await widgetTester.tap(
      find.descendant(of: ccwPositive, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();
    expect(gyroModel.counterClockwisePositive, false);

    await widgetTester.tap(
      find.descendant(of: ccwPositive, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();
    expect(gyroModel.counterClockwisePositive, true);
  });
}
