import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/robot_preferences.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

import '../../../test_util.dart';
import '../../../test_util.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> robotPreferencesJson = {
    'topic': 'Test/Preferences',
    'period': 0.100,
  };

  late SharedPreferences preferences;
  late MockNTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Preferences/Test Preference',
          type: NT4Type.int(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Preferences/Preference 1',
          type: NT4Type.float(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Preferences/Preference 2',
          type: NT4Type.boolean(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Preferences/Preference 3',
          type: NT4Type.string(),
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Preferences/Test Preference': 0,
        'Test/Preferences/Preference 1': 0.100,
        'Test/Preferences/Preference 2': false,
        'Test/Preferences/Preference 3': 'Original String',
      },
    );
  });

  test('Robot preferences from json', () {
    NTWidgetModel preferencesModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'RobotPreferences',
      robotPreferencesJson,
    );

    expect(preferencesModel.type, 'RobotPreferences');
    expect(preferencesModel.runtimeType, RobotPreferencesModel);
  });

  test('Robot preferences to json', () {
    RobotPreferencesModel preferencesModel = RobotPreferencesModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Preferences',
      period: 0.100,
    );

    expect(preferencesModel.toJson(), robotPreferencesJson);
  });

  testWidgets('Robot preferences widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel preferencesModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'RobotPreferences',
      robotPreferencesJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: preferencesModel,
            child: const RobotPreferences(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(5));

    expect(find.widgetWithText(TextField, 'Test Preference'), findsOneWidget);
    await widgetTester.enterText(
      find.widgetWithText(TextField, 'Test Preference'),
      '1',
    );
    // Focusing on the text field should publish the topic
    verify(ntConnection.publishTopic(any)).called(1);

    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    expect(
      ntConnection.getLastAnnouncedValue('Test/Preferences/Test Preference'),
      1,
    );

    // After submitting topic should be unpublished
    verify(ntConnection.unpublishTopic(any)).called(1);

    clearInteractions(ntConnection);

    expect(find.widgetWithText(TextField, 'Preference 1'), findsOneWidget);
    await widgetTester.enterText(
      find.widgetWithText(TextField, 'Preference 1'),
      '0.250',
    );
    // Focusing on the text field should publish the topic
    verify(ntConnection.publishTopic(any)).called(1);

    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    expect(
      ntConnection.getLastAnnouncedValue('Test/Preferences/Preference 1'),
      0.250,
    );

    // After submitting topic should be unpublished
    verify(ntConnection.unpublishTopic(any)).called(1);

    clearInteractions(ntConnection);

    expect(find.widgetWithText(TextField, 'Preference 2'), findsOneWidget);
    await widgetTester.enterText(
      find.widgetWithText(TextField, 'Preference 2'),
      'true',
    );
    // Focusing on the text field should publish the topic
    verify(ntConnection.publishTopic(any)).called(1);

    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    expect(
      ntConnection.getLastAnnouncedValue('Test/Preferences/Preference 2'),
      isTrue,
    );

    // After submitting topic should be unpublished
    verify(ntConnection.unpublishTopic(any)).called(1);

    clearInteractions(ntConnection);

    expect(find.widgetWithText(TextField, 'Preference 3'), findsOneWidget);
    await widgetTester.enterText(
      find.widgetWithText(TextField, 'Preference 3'),
      'Edited String',
    );
    // Focusing on the text field should publish the topic
    verify(ntConnection.publishTopic(any)).called(1);

    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    expect(
      ntConnection.getLastAnnouncedValue('Test/Preferences/Preference 3'),
      'Edited String',
    );
    // After submitting topic should be unpublished
    verify(ntConnection.unpublishTopic(any)).called(1);

    clearInteractions(ntConnection);

    // Searching
    final searchField = find.widgetWithText(TextField, 'Search');
    expect(searchField, findsOneWidget);

    await widgetTester.enterText(searchField, 'Preference');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(5));

    await widgetTester.enterText(searchField, 'Test');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2));
  });
}
