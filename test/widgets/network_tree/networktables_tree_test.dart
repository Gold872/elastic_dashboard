import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/struct_schemas/nt_struct.dart';
import 'package:elastic_dashboard/widgets/network_tree/networktables_tree.dart';
import '../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  setUp(() async {
    FlutterError.onError = ignoreOverflowErrors;
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  testWidgets('Network Tables Tree with leading slashes', (widgetTester) async {
    NTConnection ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(name: '/Testing/Integer', type: NT4Type.int(), properties: {}),
        NT4Topic(
          name: '/Testing/Double',
          type: NT4Type.double(),
          properties: {},
        ),
        NT4Topic(
          name: '/Testing/SubTable/String',
          type: NT4Type.string(),
          properties: {},
        ),
      ],
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NetworkTableTree(
            ntConnection: ntConnection,
            preferences: preferences,
            hideMetadata: false,
          ),
        ),
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(find.text('Testing'), findsOneWidget);
    await widgetTester.tap(find.text('Testing'));
    await widgetTester.pumpAndSettle();

    expect(find.text('Integer'), findsOneWidget);
    expect(find.text('int'), findsOneWidget);

    expect(find.text('Double'), findsOneWidget);
    expect(find.text('double'), findsOneWidget);

    expect(find.text('String'), findsNothing);
    expect(find.text('string'), findsNothing);
    expect(find.text('SubTable'), findsOneWidget);

    await widgetTester.tap(find.text('SubTable'));
    await widgetTester.pumpAndSettle();

    expect(find.text('String'), findsOneWidget);
    expect(find.text('string'), findsOneWidget);
  });

  testWidgets('Network Tables Tree without leading slashes', (
    widgetTester,
  ) async {
    NTConnection ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(name: 'Testing/Integer', type: NT4Type.int(), properties: {}),
        NT4Topic(
          name: 'Testing/Double',
          type: NT4Type.double(),
          properties: {},
        ),
        NT4Topic(
          name: 'Testing/SubTable/String',
          type: NT4Type.string(),
          properties: {},
        ),
      ],
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NetworkTableTree(
            ntConnection: ntConnection,
            preferences: preferences,
            hideMetadata: false,
          ),
        ),
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(find.text('Testing'), findsOneWidget);
    await widgetTester.tap(find.text('Testing'));
    await widgetTester.pumpAndSettle();

    expect(find.text('Integer'), findsOneWidget);
    expect(find.text('int'), findsOneWidget);

    expect(find.text('Double'), findsOneWidget);
    expect(find.text('double'), findsOneWidget);

    expect(find.text('String'), findsNothing);
    expect(find.text('string'), findsNothing);
    expect(find.text('SubTable'), findsOneWidget);

    await widgetTester.tap(find.text('SubTable'));
    await widgetTester.pumpAndSettle();

    expect(find.text('String'), findsOneWidget);
    expect(find.text('string'), findsOneWidget);
  });

  testWidgets('Network Tables Tree searching', (widgetTester) async {
    NTConnection ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(name: '/Testing/Integer', type: NT4Type.int(), properties: {}),
        NT4Topic(
          name: '/Testing/Double',
          type: NT4Type.double(),
          properties: {},
        ),
        NT4Topic(
          name: '/Testing/SubTable/String',
          type: NT4Type.string(),
          properties: {},
        ),
      ],
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NetworkTableTree(
            ntConnection: ntConnection,
            preferences: preferences,
            hideMetadata: false,
            searchQuery: 'Double',
          ),
        ),
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(find.text('Testing'), findsOneWidget);
    await widgetTester.tap(find.text('Testing'));
    await widgetTester.pumpAndSettle();

    expect(find.text('Integer'), findsNothing);
    expect(find.text('int'), findsNothing);

    expect(find.text('Double'), findsOneWidget);
    expect(find.text('double'), findsOneWidget);

    expect(find.text('String'), findsNothing);
    expect(find.text('string'), findsNothing);
    expect(find.text('SubTable'), findsNothing);
  });

  testWidgets('Network Tables Tree structs', (widgetTester) async {
    final SchemaManager schemaManager = SchemaManager();

    schemaManager.processNewSchema(
      'Pose2d',
      utf8.encode('Translation2d translation;Rotation2d rotation'),
    );
    schemaManager.processNewSchema(
      'Translation2d',
      utf8.encode('double x;double y'),
    );
    schemaManager.processNewSchema('Rotation2d', utf8.encode('double value'));

    NTConnection ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: '/Testing/Pose',
          type: NT4Type.struct('Pose2d'),
          properties: {},
        ),
      ],
      schemaManager: schemaManager,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NetworkTableTree(
            ntConnection: ntConnection,
            preferences: preferences,
            hideMetadata: false,
          ),
        ),
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(find.text('Testing'), findsOneWidget);

    await widgetTester.tap(find.text('Testing'));
    await widgetTester.pumpAndSettle();

    expect(find.text('Pose'), findsOneWidget);
    expect(find.text('translation'), findsNothing);
    expect(find.text('rotation'), findsNothing);

    await widgetTester.tap(find.text('Pose'));
    await widgetTester.pumpAndSettle();

    expect(find.text('translation'), findsOneWidget);
    expect(find.text('rotation'), findsOneWidget);
  });
}
