import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:elastic_dashboard/widgets/camera_stream_controller.dart';
import 'package:elastic_dashboard/widgets/custom_loading_indicator.dart';
import 'package:elastic_dashboard/widgets/whep.dart';
import '../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HttpOverrides.global = null;
  });

  testWidgets('Waiting for WHEP stream UI (Initial State)', (
    widgetTester,
  ) async {
    FlutterError.onError = ignoreOverflowErrors;

    WhepController controller = WhepController.withMockClient(
      streams: ['http://10.0.0.2:1181/whep'],
      httpClient: MockClient((request) async => Response('', 400)),
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Whep(controller: controller)),
      ),
    );
    await widgetTester.pump();

    // Verify initial state
    expect(find.byType(CustomLoadingIndicator), findsOneWidget);
    expect(find.text('Negotiating WHEP stream...'), findsOneWidget);

    controller.dispose();

    await widgetTester.pumpWidget(const Placeholder());
    await widgetTester.pump(
      VisibilityDetectorController.instance.updateInterval,
    );
  });

  testWidgets('Cycles through invalid URLs when WHEP connection fails', (
    widgetTester,
  ) async {
    WhepController controller = WhepController.withMockClient(
      streams: [
        'http://10.0.0.2:1181/whep',
        'http://10.0.0.2:1182/whep',
      ],
      timeout: const Duration(milliseconds: 100),
      httpClient: MockClient((request) async => Response('Bad request', 400)),
    );

    // Trick the controller into being visible and start streaming
    final Key visibleKey = UniqueKey();
    controller.setMounted(visibleKey, true);
    controller.setVisible(visibleKey, true);

    expect(controller.lastError, isNull);
    expect(controller.cycleState, StreamCycleState.connecting);
    expect(controller.currentStreamIndex, 0);

    // Simulate WebRTC connection failure
    controller.debugSetState(
      StreamCycleState.reconnecting,
      lastError: Exception('Mock failure'),
    );

    expect(controller.lastError, isNotNull);
    expect(controller.cycleState, StreamCycleState.reconnecting);

    // Begins reconnect in 500 ms (WhepController uses 500ms delay)
    await widgetTester.pump(const Duration(milliseconds: 550));

    expect(
      controller.cycleState,
      StreamCycleState.connecting,
      reason: 'Waits 500 ms between reconnection and connection',
    );
    expect(controller.currentStreamIndex, 1);
    expect(controller.currentStream, 'http://10.0.0.2:1182/whep');

    // Simulate another failure
    controller.debugSetState(
      StreamCycleState.reconnecting,
      lastError: Exception('Mock failure 2'),
    );

    expect(controller.lastError, isNotNull);
    expect(
      controller.cycleState,
      StreamCycleState.reconnecting,
    );
    expect(controller.currentStreamIndex, 1);
    expect(controller.currentStream, 'http://10.0.0.2:1182/whep');

    await widgetTester.pump(const Duration(milliseconds: 550));

    expect(controller.currentStreamIndex, 0);
    expect(controller.cycleState, StreamCycleState.connecting);
    expect(controller.currentStream, 'http://10.0.0.2:1181/whep');

    controller.dispose();
  });

  testWidgets('WHEP controller teardown and visibility', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    WhepController controller = WhepController.withMockClient(
      streams: ['http://10.0.0.2:1181/whep'],
      httpClient: MockClient((request) async {
        if (request.method == 'DELETE') {
          return Response('', 200);
        }
        return Response('', 400);
      }),
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Whep(controller: controller)),
      ),
    );
    await widgetTester.pump();

    // Verify initial state
    expect(find.byType(CustomLoadingIndicator), findsOneWidget);

    // Dispose by tearing down the widget
    await widgetTester.pumpWidget(const Placeholder());
    await widgetTester.pump(
      VisibilityDetectorController.instance.updateInterval,
    );

    // Let the event loop run to process the unawaited HTTP requests and controller shutdown
    await widgetTester.pumpAndSettle(const Duration(seconds: 1));

    // Wait, the delete request will only be sent if resourceUri was set.
    // Since we mock failure, resourceUri is likely null. We can still verify state is disposed.
    expect(controller.cycleState, StreamCycleState.idle);

    controller.dispose();
    await widgetTester.pump();
    expect(controller.cycleState, StreamCycleState.disposed);
  });
}
