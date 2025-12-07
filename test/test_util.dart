import 'dart:io';

import 'package:flutter/material.dart';

import 'package:http/http.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/struct_schemas/nt_struct.dart';
import 'package:elastic_dashboard/services/update_checker.dart';
import 'test_util.mocks.dart';

@GenerateNiceMocks([
  MockSpec<NTConnection>(),
  MockSpec<NT4Client>(),
  MockSpec<NT4Subscription>(),
])
MockNTConnection createMockOfflineNT4() {
  HttpOverrides.global = null;

  final mockNT4Connection = MockNTConnection();
  final mockSubscription = MockNT4Subscription();

  when(mockNT4Connection.schemaManager).thenReturn(SchemaManager());

  when(mockNT4Connection.announcedTopics()).thenReturn({});

  when(mockSubscription.periodicStream()).thenAnswer((_) => Stream.value(null));

  when(mockSubscription.listen(any)).thenAnswer((invocation) {});

  when(mockNT4Connection.ntConnected).thenReturn(ValueNotifier(false));
  when(mockNT4Connection.isNT4Connected).thenReturn(false);

  when(mockNT4Connection.serverTime).thenReturn(0);

  when(
    mockNT4Connection.connectionStatus(),
  ).thenAnswer((_) => Stream.value(false));

  when(mockNT4Connection.dsConnected).thenReturn(ValueNotifier(false));
  when(mockNT4Connection.isDSConnected).thenReturn(false);
  when(mockNT4Connection.dsHeight).thenReturn(ValueNotifier(null));
  when(mockNT4Connection.dsIpAddress).thenReturn(ValueNotifier(null));

  when(mockNT4Connection.latencyStream()).thenAnswer((_) => Stream.value(0));

  when(mockNT4Connection.getLastAnnouncedValue(any)).thenReturn(null);

  when(
    mockNT4Connection.subscribeWithOptions(any, any),
  ).thenReturn(mockSubscription);

  when(mockNT4Connection.subscribe(any, any)).thenReturn(mockSubscription);

  when(mockNT4Connection.subscribe(any)).thenReturn(mockSubscription);

  when(mockNT4Connection.subscribeAll(any, any)).thenReturn(mockSubscription);

  when(mockNT4Connection.getTopicFromName(any)).thenReturn(null);

  return mockNT4Connection;
}

MockNTConnection createMockOnlineNT4({
  List<NT4Topic>? virtualTopics,
  Map<String, dynamic>? virtualValues,
  int serverTime = 0,
  SchemaManager? schemaManager,
}) {
  HttpOverrides.global = null;

  final mockNT4Connection = MockNTConnection();
  final mockSubscription = MockNT4Subscription();

  virtualTopics ??= [
    NT4Topic(
      name: '/SmartDashboard/Test Value 1',
      type: NT4Type.int(),
      properties: {},
    ),
    NT4Topic(
      name: '/SmartDashboard/Test Value 2',
      type: NT4Type.float(),
      properties: {},
    ),
  ];

  virtualValues ??= {};

  schemaManager ??= SchemaManager();

  when(mockNT4Connection.schemaManager).thenReturn(schemaManager);

  Map<int, NT4Topic> virtualTopicsMap = {};

  for (int i = 0; i < virtualTopics.length; i++) {
    virtualTopicsMap.addAll({i + 1: virtualTopics[i]});
  }

  List<NT4Topic> publishedTopics = [];

  when(mockNT4Connection.announcedTopics()).thenReturn(virtualTopicsMap);

  when(mockNT4Connection.addTopicAnnounceListener(any)).thenAnswer((
    invocation,
  ) {
    for (NT4Topic topic in virtualTopics!) {
      invocation.positionalArguments[0].call(topic);
    }
  });

  when(mockSubscription.periodicStream()).thenAnswer((_) => Stream.value(null));

  when(mockSubscription.listen(any)).thenAnswer((_) {});

  when(mockNT4Connection.ntConnected).thenReturn(ValueNotifier(true));
  when(mockNT4Connection.isNT4Connected).thenReturn(true);

  when(mockNT4Connection.serverTime).thenReturn(serverTime);

  when(
    mockNT4Connection.connectionStatus(),
  ).thenAnswer((_) => Stream.value(true));

  when(mockNT4Connection.dsConnected).thenReturn(ValueNotifier(true));
  when(mockNT4Connection.isDSConnected).thenReturn(true);
  when(mockNT4Connection.dsHeight).thenReturn(ValueNotifier(null));
  when(mockNT4Connection.dsIpAddress).thenReturn(ValueNotifier(null));

  when(mockNT4Connection.latencyStream()).thenAnswer((_) => Stream.value(0));

  when(mockNT4Connection.getLastAnnouncedValue(any)).thenReturn(null);

  when(
    mockNT4Connection.subscribeWithOptions(any, any),
  ).thenReturn(mockSubscription);

  when(mockNT4Connection.subscribe(any, any)).thenReturn(mockSubscription);

  when(mockNT4Connection.subscribe(any)).thenReturn(mockSubscription);

  when(mockNT4Connection.subscribeAll(any, any)).thenReturn(mockSubscription);

  when(mockNT4Connection.getTopicFromName(any)).thenReturn(null);

  when(
    mockNT4Connection.publishNewTopic(
      any,
      any,
      properties: anyNamed('properties'),
    ),
  ).thenAnswer((invocation) {
    NT4Topic newTopic = NT4Topic(
      name: invocation.positionalArguments[0],
      type: invocation.positionalArguments[1],
      properties: invocation.positionalArguments.length >= 3
          ? invocation.positionalArguments[2]
          : {},
    );

    virtualTopicsMap[virtualTopicsMap.length] = newTopic;
    publishedTopics.add(newTopic);
    return newTopic;
  });

  when(mockNT4Connection.publishTopic(any)).thenAnswer((invocation) {
    publishedTopics.add(invocation.positionalArguments[0]);
  });

  when(mockNT4Connection.unpublishTopic(any)).thenAnswer((invocation) {
    publishedTopics.remove(invocation.positionalArguments[0]);
  });

  when(mockNT4Connection.isTopicPublished(any)).thenAnswer(
    (invocation) => publishedTopics.contains(invocation.positionalArguments[0]),
  );

  when(mockNT4Connection.updateDataFromTopic(any, any)).thenAnswer((
    invocation,
  ) {
    NT4Topic topic = invocation.positionalArguments[0];
    Object? data = invocation.positionalArguments[1];

    virtualValues![topic.name] = data;
  });

  when(mockNT4Connection.updateDataFromTopicName(any, any)).thenAnswer((
    invocation,
  ) {
    String topic = invocation.positionalArguments[0];
    Object? data = invocation.positionalArguments[1];

    virtualValues![topic] = data;
  });

  for (NT4Topic topic in virtualTopics) {
    List<Function(Object?, int)> subscriptionListeners = [];
    List<void Function()> subscriptionNotifiers = [];

    MockNT4Subscription topicSubscription = MockNT4Subscription();

    when(topicSubscription.topic).thenReturn(topic.name);

    when(topicSubscription.value).thenAnswer((_) => virtualValues![topic.name]);

    when(topicSubscription.value = any).thenAnswer((invocation) {
      virtualValues![topic.name] = invocation.positionalArguments[0];
      for (var notifier in subscriptionNotifiers) {
        notifier.call();
      }
    });

    when(topicSubscription.addListener(any)).thenAnswer((invocation) {
      subscriptionNotifiers.add(invocation.positionalArguments[0]);
    });

    when(topicSubscription.removeListener(any)).thenAnswer((invocation) {
      subscriptionNotifiers.remove(invocation.positionalArguments[0]);
    });

    when(mockNT4Connection.updateDataFromTopic(topic, any)).thenAnswer((
      invocation,
    ) {
      virtualValues![topic.name] = invocation.positionalArguments[1];
      topicSubscription.updateValue(invocation.positionalArguments[1], 0);
    });

    when(mockNT4Connection.updateDataFromTopicName(topic.name, any)).thenAnswer(
      (invocation) {
        virtualValues![topic.name] = invocation.positionalArguments[1];
        topicSubscription.updateValue(invocation.positionalArguments[1], 0);
      },
    );

    when(
      mockNT4Connection.updateDataFromSubscription(topicSubscription, any),
    ).thenAnswer((invocation) {
      virtualValues![topic.name] = invocation.positionalArguments[1];
      topicSubscription.updateValue(invocation.positionalArguments[1], 0);
    });

    when(mockNT4Connection.getTopicFromName(topic.name)).thenReturn(topic);

    when(
      topicSubscription.periodicStream(yieldAll: anyNamed('yieldAll')),
    ).thenAnswer((_) => Stream.value(virtualValues![topic.name]));

    when(topicSubscription.listen(any)).thenAnswer((invocation) {
      subscriptionListeners.add(invocation.positionalArguments[0]);
    });

    when(topicSubscription.updateValue(any, any)).thenAnswer((invocation) {
      virtualValues![topic.name] = invocation.positionalArguments[0];
      for (var value in subscriptionListeners) {
        value.call(
          invocation.positionalArguments[0],
          invocation.positionalArguments[1],
        );
      }
      topicSubscription.value = invocation.positionalArguments[0];
    });

    when(
      mockNT4Connection.getLastAnnouncedValue(topic.name),
    ).thenAnswer((_) => virtualValues![topic.name]);

    when(
      mockNT4Connection.subscribeWithOptions(topic.name, any),
    ).thenAnswer((_) => topicSubscription);

    when(
      mockNT4Connection.subscribe(topic.name, any),
    ).thenAnswer((_) => topicSubscription);

    when(
      mockNT4Connection.subscribeAll(topic.name, any),
    ).thenAnswer((_) => topicSubscription);
  }

  return mockNT4Connection;
}

@GenerateNiceMocks([MockSpec<UpdateChecker>()])
MockUpdateChecker createMockUpdateChecker({
  bool updateAvailable = false,
  String latestVersion = '0.0.0.0',
}) {
  MockUpdateChecker updateChecker = MockUpdateChecker();

  when(updateChecker.isUpdateAvailable()).thenAnswer(
    (_) => Future.value(
      UpdateCheckerResponse(
        updateAvailable: updateAvailable,
        error: false,
        latestVersion: latestVersion,
      ),
    ),
  );

  return updateChecker;
}

@GenerateNiceMocks([MockSpec<Client>()])
MockClient createHttpClient({Map<String, Response>? mockGetResponses}) {
  MockClient mockClient = MockClient();

  if (mockGetResponses != null) {
    for (MapEntry<String, Response> mockRequest in mockGetResponses.entries) {
      when(
        mockClient.get(Uri.parse(mockRequest.key)),
      ).thenAnswer((_) => Future.value(mockRequest.value));
    }
  }
  return mockClient;
}

void ignoreOverflowErrors(
  FlutterErrorDetails details, {
  bool forceReport = false,
}) {
  // ---

  bool ifIsOverflowError = false;
  bool isUnableToLoadAsset = false;

  // Detect overflow error.
  var exception = details.exception;
  if (exception is FlutterError) {
    ifIsOverflowError = !exception.diagnostics.any(
      (e) => e.value.toString().startsWith('A RenderFlex overflowed by'),
    );
    isUnableToLoadAsset = !exception.diagnostics.any(
      (e) => e.value.toString().startsWith('Unable to load asset'),
    );
  }

  // Ignore if is overflow error.
  if (ifIsOverflowError || isUnableToLoadAsset) {
    return;
  } else {
    FlutterError.dumpErrorToConsole(details, forceReport: forceReport);
    // exit(1);
  }
}
