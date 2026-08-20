import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/command_scheduler.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> commandSchedulerJson = {
    'topic': 'Test/Command Scheduler',
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
          name: 'Test/Command Scheduler/Names',
          type: NT4Type.array(NT4Type.string()),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Command Scheduler/Ids',
          type: NT4Type.array(NT4Type.int()),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Command Scheduler/Cancel',
          type: NT4Type.array(NT4Type.int()),
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Command Scheduler/Names': ['Command 1', 'Command 2'],
        'Test/Command Scheduler/Ids': [1, 2],
      },
    );
  });

  test('Command scheduler from json', () {
    NTWidgetModel commandSchedulerModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Scheduler',
      commandSchedulerJson,
    );

    expect(commandSchedulerModel.type, 'Scheduler');
    expect(commandSchedulerModel.runtimeType, CommandSchedulerModel);
  });

  test('Command scheduler to json', () {
    CommandSchedulerModel commandSchedulerModel = CommandSchedulerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Command Scheduler',
      period: 0.100,
    );

    expect(commandSchedulerModel.toJson(), commandSchedulerJson);
  });

  testWidgets('Command scheduler widget', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel commandSchedulerModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Scheduler',
      commandSchedulerJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: commandSchedulerModel,
            child: const CommandSchedulerWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));

    expect(find.text('Command 1'), findsOneWidget);
    expect(find.text('Command 2'), findsOneWidget);

    expect(find.text('ID: 1'), findsOneWidget);
    expect(find.text('ID: 2'), findsOneWidget);

    expect(find.byIcon(Icons.cancel_outlined), findsNWidgets(2));

    await widgetTester.tap(find.byIcon(Icons.cancel_outlined).first);
    await widgetTester.pumpAndSettle();

    expect(
      ntConnection.getLastAnnouncedValue('Test/Command Scheduler/Cancel'),
      [1],
    );

    ntConnection.updateDataFromTopicName('Test/Command Scheduler/Ids', [2]);
    ntConnection.updateDataFromTopicName('Test/Command Scheduler/Names', [
      'Command 2',
    ]);

    commandSchedulerModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('Command 1'), findsNothing);
    expect(find.text('ID: 1'), findsNothing);

    await widgetTester.tap(find.byIcon(Icons.cancel_outlined));
    await widgetTester.pumpAndSettle();

    expect(
      ntConnection.getLastAnnouncedValue('Test/Command Scheduler/Cancel'),
      [1, 2],
    );
  });
}
