import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/generated/protobuf_commands.pb.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/command_scheduler_v3.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> schedulerJson = {
    'topic': 'Test/Scheduler',
    'data_type': NT4Type.proto('wpi.proto.Scheduler').serialize(),
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
          name: 'Test/Scheduler',
          type: NT4Type.proto('wpi.proto.ProtobufScheduler'),
          properties: {},
        ),
      ],
    );
  });

  test('Command scheduler v3 from json', () {
    NTWidgetModel schedulerV3Model = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'SchedulerV3',
      schedulerJson,
    );

    expect(schedulerV3Model.type, 'SchedulerV3');
    expect(schedulerV3Model.runtimeType, SingleTopicNTWidgetModel);
  });

  test('Command scheduler v3 to json', () {
    NTWidgetModel schedulerViewModel = SingleTopicNTWidgetModel.createDefault(
      ntConnection: ntConnection,
      preferences: preferences,
      type: 'SchedulerV3',
      topic: 'Test/Scheduler',
      dataType: NT4Type.proto('wpi.proto.Scheduler'),
      period: 0.100,
    );

    expect(schedulerViewModel.toJson(), schedulerJson);
  });

  testWidgets('CommandSchedulerV3 widget test', (
    tester,
  ) async {
    // Create protobuf data: Root 1 has two parallel leaf children (Leaf 1, Leaf 2)
    final scheduler = ProtobufScheduler(
      lastTimeMs: 20.0,
      runningCommands: [
        ProtobufCommand(
          id: 1,
          name: 'Root 1',
          lastTimeMs: 5.0,
          totalTimeMs: 100.0,
        ),
        ProtobufCommand(
          id: 2,
          parentId: 1,
          name: 'Leaf 1',
          lastTimeMs: 2.0,
          totalTimeMs: 50.0,
        ),
        ProtobufCommand(
          id: 3,
          parentId: 1,
          name: 'Leaf 2',
          lastTimeMs: 1.0,
          totalTimeMs: 25.0,
        ),
        ProtobufCommand(
          id: 4,
          name: 'Solo Root',
          lastTimeMs: 10.0,
          totalTimeMs: 200.0,
        ),
      ],
    );

    final model = SingleTopicNTWidgetModel.createDefault(
      ntConnection: createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
            name: 'Test/Scheduler',
            type: NT4Type.proto('wpi.proto.ProtobufScheduler'),
            properties: {},
          ),
        ],
        virtualValues: {
          'Test/Scheduler': scheduler.writeToBuffer(),
        },
      ),
      preferences: preferences,
      type: CommandSchedulerV3.widgetType,
      topic: 'Test/Scheduler',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: model,
            child: const CommandSchedulerV3(),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.textContaining('Loop Time: 20.000 ms'), findsOneWidget);

    // Verify Root 1 and its two leaves
    expect(find.text('Root 1'), findsOneWidget);
    expect(find.text('Leaf 1'), findsOneWidget);
    expect(find.text('Leaf 2'), findsOneWidget);

    expect(find.text('Solo Root'), findsOneWidget);
  });
}
