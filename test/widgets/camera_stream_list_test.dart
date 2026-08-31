import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/camera_stream_list.dart';
import '../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  setUp(() async {
    FlutterError.onError = ignoreOverflowErrors;
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  testWidgets('Camera Stream List', (widgetTester) async {
    NTConnection ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: '/CameraPublisher/Camera 1/streams',
          type: NT4Type.array(NT4Type.string()),
          properties: {},
        ),
        NT4Topic(
          name: 'CameraPublisher/Camera 2/streams',
          type: NT4Type.array(NT4Type.string()),
          properties: {},
        ),
        NT4Topic(
          name: '/SomeOtherTopic',
          type: NT4Type.int(),
          properties: {},
        ),
      ],
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CameraStreamList(
            ntConnection: ntConnection,
            preferences: preferences,
          ),
        ),
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(find.text('Camera 1'), findsOneWidget);
    expect(find.text('Camera 2'), findsOneWidget);
    expect(find.text('SomeOtherTopic'), findsNothing);
  });

  testWidgets('Camera Stream List with Search', (widgetTester) async {
    NTConnection ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: '/CameraPublisher/Camera 1/streams',
          type: NT4Type.array(NT4Type.string()),
          properties: {},
        ),
        NT4Topic(
          name: 'CameraPublisher/Camera 2/streams',
          type: NT4Type.array(NT4Type.string()),
          properties: {},
        ),
        NT4Topic(
          name: '/SomeOtherTopic',
          type: NT4Type.int(),
          properties: {},
        ),
      ],
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CameraStreamList(
            ntConnection: ntConnection,
            preferences: preferences,
            searchQuery: '2',
          ),
        ),
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(find.text('Camera 1'), findsNothing);
    expect(find.text('Camera 2'), findsOneWidget);
    expect(find.text('SomeOtherTopic'), findsNothing);
  });
}
