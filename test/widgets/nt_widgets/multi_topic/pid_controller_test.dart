import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/pid_controller.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> pidControllerJson = {
    'topic': 'Test/PID Controller',
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
          name: 'Test/PID Controller/p',
          type: NT4Type.float(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/PID Controller/i',
          type: NT4Type.float(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/PID Controller/d',
          type: NT4Type.float(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/PID Controller/setpoint',
          type: NT4Type.float(),
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/PID Controller/p': 0.0,
        'Test/PID Controller/i': 0.0,
        'Test/PID Controller/d': 0.0,
        'Test/PID Controller/setpoint': 0.0,
      },
    );
  });

  test('PID controller from json', () {
    NTWidgetModel pidControllerModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'PIDController',
      pidControllerJson,
    );

    expect(pidControllerModel.type, 'PIDController');
    expect(pidControllerModel.runtimeType, PIDControllerModel);
  });

  test('PID controller from alias name', () {
    NTWidgetModel pidControllerModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'PID Controller',
      pidControllerJson,
    );

    expect(pidControllerModel.type, 'PIDController');
    expect(pidControllerModel.runtimeType, PIDControllerModel);
  });

  test('PID controller to json', () {
    PIDControllerModel pidControllerModel = PIDControllerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/PID Controller',
      period: 0.100,
    );

    expect(pidControllerModel.toJson(), pidControllerJson);
  });

  testWidgets('PID controller widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel pidControllerModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'PIDController',
      pidControllerJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: pidControllerModel,
            child: const PIDControllerWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(4));
    expect(find.widgetWithText(TextField, 'kP'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'kI'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'kD'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Setpoint'), findsOneWidget);

    await widgetTester.enterText(find.widgetWithText(TextField, 'kP'), '0.100');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    expect(ntConnection.getLastAnnouncedValue('Test/PID Controller/p'), 0.0);

    await widgetTester.enterText(find.widgetWithText(TextField, 'kI'), '0.100');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    expect(ntConnection.getLastAnnouncedValue('Test/PID Controller/i'), 0.0);

    await widgetTester.enterText(find.widgetWithText(TextField, 'kD'), '0.100');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    expect(ntConnection.getLastAnnouncedValue('Test/PID Controller/d'), 0.0);

    await widgetTester.enterText(
      find.widgetWithText(TextField, 'Setpoint'),
      '0.100',
    );
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    expect(
      ntConnection.getLastAnnouncedValue('Test/PID Controller/setpoint'),
      0.0,
    );

    pidControllerModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(find.byIcon(Icons.priority_high), findsOneWidget);

    expect(
      find.widgetWithText(OutlinedButton, 'Publish Values'),
      findsOneWidget,
    );
    await widgetTester.tap(
      find.widgetWithText(OutlinedButton, 'Publish Values'),
    );

    pidControllerModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(ntConnection.getLastAnnouncedValue('Test/PID Controller/p'), 0.1);
    expect(ntConnection.getLastAnnouncedValue('Test/PID Controller/i'), 0.1);
    expect(ntConnection.getLastAnnouncedValue('Test/PID Controller/d'), 0.1);
    expect(
      ntConnection.getLastAnnouncedValue('Test/PID Controller/setpoint'),
      0.1,
    );

    expect(find.byIcon(Icons.priority_high), findsNothing);
  });
}
