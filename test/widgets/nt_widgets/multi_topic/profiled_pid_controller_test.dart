import 'package:material_ui/material_ui.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/profiled_pid_controller.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> profiledPIDControllerJson = {
    'topic': 'Test/Profiled PID Controller',
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
          name: 'Test/Profiled PID Controller/p',
          type: NT4Type.float(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Profiled PID Controller/i',
          type: NT4Type.float(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Profiled PID Controller/d',
          type: NT4Type.float(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Profiled PID Controller/goal',
          type: NT4Type.float(),
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Profiled PID Controller/p': 0.0,
        'Test/Profiled PID Controller/i': 0.0,
        'Test/Profiled PID Controller/d': 0.0,
        'Test/Profiled PID Controller/goal': 0.0,
      },
    );
  });

  test('PID controller from json', () {
    NTWidgetModel profiledPIDControllerModel =
        NTWidgetRegistry.buildNTModelFromJson(
          ntConnection,
          preferences,
          'ProfiledPIDController',
          profiledPIDControllerJson,
        );

    expect(profiledPIDControllerModel.type, 'ProfiledPIDController');
    expect(profiledPIDControllerModel.runtimeType, ProfiledPIDControllerModel);
  });

  test('Profiled PID controller to json', () {
    ProfiledPIDControllerModel profiledPIDControllerModel =
        ProfiledPIDControllerModel(
          ntConnection: ntConnection,
          preferences: preferences,
          topic: 'Test/Profiled PID Controller',
          period: 0.100,
        );

    expect(profiledPIDControllerModel.toJson(), profiledPIDControllerJson);
  });

  testWidgets('Profiled PID controller widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel profiledPIDControllerModel =
        NTWidgetRegistry.buildNTModelFromJson(
          ntConnection,
          preferences,
          'ProfiledPIDController',
          profiledPIDControllerJson,
        );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: profiledPIDControllerModel,
            child: const ProfiledPIDControllerWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(4));
    expect(find.widgetWithText(TextField, 'kP'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'kI'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'kD'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Goal'), findsOneWidget);

    await widgetTester.enterText(find.widgetWithText(TextField, 'kP'), '0.100');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    expect(
      ntConnection.getLastAnnouncedValue('Test/Profiled PID Controller/p'),
      0.0,
    );

    await widgetTester.enterText(find.widgetWithText(TextField, 'kI'), '0.100');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    expect(
      ntConnection.getLastAnnouncedValue('Test/Profiled PID Controller/i'),
      0.0,
    );

    await widgetTester.enterText(find.widgetWithText(TextField, 'kD'), '0.100');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    expect(
      ntConnection.getLastAnnouncedValue('Test/Profiled PID Controller/d'),
      0.0,
    );

    await widgetTester.enterText(
      find.widgetWithText(TextField, 'Goal'),
      '0.100',
    );
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    expect(
      ntConnection.getLastAnnouncedValue('Test/Profiled PID Controller/goal'),
      0.0,
    );

    profiledPIDControllerModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(find.byIcon(Icons.priority_high), findsOneWidget);

    expect(
      find.widgetWithText(OutlinedButton, 'Publish Values'),
      findsOneWidget,
    );
    await widgetTester.tap(
      find.widgetWithText(OutlinedButton, 'Publish Values'),
    );

    profiledPIDControllerModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(
      ntConnection.getLastAnnouncedValue('Test/Profiled PID Controller/p'),
      0.1,
    );
    expect(
      ntConnection.getLastAnnouncedValue('Test/Profiled PID Controller/i'),
      0.1,
    );
    expect(
      ntConnection.getLastAnnouncedValue('Test/Profiled PID Controller/d'),
      0.1,
    );
    expect(
      ntConnection.getLastAnnouncedValue('Test/Profiled PID Controller/goal'),
      0.1,
    );

    expect(find.byIcon(Icons.priority_high), findsNothing);
  });
}
