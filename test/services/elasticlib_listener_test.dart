import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:elastic_dashboard/services/elasticlib_listener.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import '../test_util.dart';
import '../test_util.mocks.dart';

class MockNotificationCallback extends Mock {
  void call(
    String? title,
    String? description,
    Icon? icon,
    Duration time,
    double width,
    double? height,
  );
}

class MockTabChangeCallback extends Mock {
  void call(Object? tabIdentifier);
}

void main() {
  group('[Robot Notifications]:', () {
    group('Initial connection', () {
      test('no existing data', () {
        MockNTConnection mockConnection = createMockOnlineNT4();

        // Create a mock for the onNotification callback
        MockNotificationCallback mockOnNotification =
            MockNotificationCallback();

        MockTabChangeCallback mockTabChange = MockTabChangeCallback();

        ElasticLibListener notifications = ElasticLibListener(
          ntConnection: mockConnection,
          onNotification: mockOnNotification.call,
          onTabSelected: mockTabChange.call,
        );

        notifications.listen();

        // Verify that subscribeAll was called with the specific parameters
        verify(
          mockConnection.subscribeAll('/Elastic/RobotNotifications', 0.2),
        ).called(1);
        verify(mockConnection.subscribe('/Elastic/SelectedTab', 0.2)).called(1);
        verify(mockConnection.addDisconnectedListener(any)).called(1);

        // Verify that no other interactions have been made with the mockConnection
        verifyNoMoreInteractions(mockConnection);

        // Verify that the onNotification callback was never called
        verifyNever(
          mockOnNotification.call(
            any,
            any,
            any,
            const Duration(seconds: 3),
            350,
            300.0,
          ),
        );
      });

      test('old existing data', () {
        MockNTConnection mockConnection = createMockOnlineNT4(
          serverTime: 5000000,
        );
        MockNT4Subscription mockSub = MockNT4Subscription();

        Map<String, dynamic> data = {
          'title': 'Title1',
          'description': 'Description1',
          'level': 'Info',
          'width': 300.0,
          'height': 300.0,
          'displayTime': 3000,
        };

        List<Function(Object?, int)> listeners = [];
        when(mockSub.listen(any)).thenAnswer((realInvocation) {
          listeners.add(realInvocation.positionalArguments[0]);
          mockSub.updateValue(jsonEncode(data), 0);
        });

        when(mockSub.updateValue(any, any)).thenAnswer((invoc) {
          for (var value in listeners) {
            value.call(
              invoc.positionalArguments[0],
              invoc.positionalArguments[1],
            );
          }
        });

        when(mockConnection.subscribeAll(any, any)).thenAnswer((
          realInvocation,
        ) {
          mockSub.updateValue(jsonEncode(data), 0);
          return mockSub;
        });

        // Create a mock for the onNotification callback
        MockNotificationCallback mockOnNotification =
            MockNotificationCallback();

        MockTabChangeCallback mockTabChange = MockTabChangeCallback();

        ElasticLibListener notifications = ElasticLibListener(
          ntConnection: mockConnection,
          onNotification: mockOnNotification.call,
          onTabSelected: mockTabChange.call,
        );

        notifications.listen();

        // Verify that subscribeAll was called with the specific parameters
        verify(
          mockConnection.subscribeAll('/Elastic/RobotNotifications', 0.2),
        ).called(1);
        verify(mockConnection.addDisconnectedListener(any)).called(1);

        // Verify that the onNotification callback was never called
        verifyNever(
          mockOnNotification(
            any,
            any,
            any,
            const Duration(seconds: 3),
            350,
            any,
          ),
        );

        // Publish some data and expect an update
        data['title'] = 'Title2';
        data['description'] = 'Description2';
        data['level'] = 'INFO';
        mockSub.updateValue(jsonEncode(data), 2);

        verify(
          mockOnNotification(
            data['title'],
            data['description'],
            any,
            Duration(milliseconds: data['displayTime']),
            data['width'],
            data['height'],
          ),
        );

        // Try malformed data
        data['title'] = null;
        data['description'] = null;
        data['level'] = 'malformedlevel';

        mockSub.updateValue(jsonEncode(data), 3);
        clearInteractions(mockOnNotification);
        verifyNever(
          mockOnNotification(
            any,
            any,
            any,
            const Duration(seconds: 3),
            350,
            any,
          ),
        );

        // Try with missing data
        data.remove('level');
        data['title'] = null;
        data['description'] = null;
        data['height'] = null;

        mockSub.updateValue(jsonEncode(data), 4);
        clearInteractions(mockOnNotification);
        verifyNever(
          mockOnNotification(
            any,
            any,
            any,
            const Duration(seconds: 3),
            350,
            any,
          ),
        );
      });

      test('newer existing data', () {
        MockNTConnection mockConnection = createMockOnlineNT4(
          serverTime: 5000000,
        );
        MockNT4Subscription mockSub = MockNT4Subscription();

        Map<String, dynamic> data = {
          'title': 'Title1',
          'description': 'Description1',
          'level': 'Info',
          'width': 300.0,
          'height': null,
          'displayTime': 3000,
        };

        List<Function(Object?, int)> listeners = [];
        when(mockSub.listen(any)).thenAnswer((realInvocation) {
          listeners.add(realInvocation.positionalArguments[0]);
          mockSub.updateValue(jsonEncode(data), 5000000);
        });

        when(mockSub.updateValue(any, any)).thenAnswer((invoc) {
          for (var value in listeners) {
            value.call(
              invoc.positionalArguments[0],
              invoc.positionalArguments[1],
            );
          }
        });

        when(mockConnection.subscribeAll(any, any)).thenAnswer((
          realInvocation,
        ) {
          mockSub.updateValue(jsonEncode(data), 0);
          return mockSub;
        });

        // Create a mock for the onNotification callback
        MockNotificationCallback mockOnNotification =
            MockNotificationCallback();

        MockTabChangeCallback mockTabChange = MockTabChangeCallback();

        ElasticLibListener notifications = ElasticLibListener(
          ntConnection: mockConnection,
          onNotification: mockOnNotification.call,
          onTabSelected: mockTabChange.call,
        );

        notifications.listen();

        // Verify that subscribeAll was called with the specific parameters
        verify(
          mockConnection.subscribeAll('/Elastic/RobotNotifications', 0.2),
        ).called(1);
        verify(mockConnection.addDisconnectedListener(any)).called(1);

        // Verify that the onNotification callback was called
        verify(
          mockOnNotification(
            any,
            any,
            any,
            Duration(milliseconds: data['displayTime']),
            data['width'],
            any,
          ),
        );
      });
    });
  });

  group('[Tab Selection]:', () {
    test('passing in index', () {
      MockNTConnection mockConnection = createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
            name: '/Elastic/SelectedTab',
            type: NT4Type.string(),
            properties: {},
          ),
        ],
      );

      MockNotificationCallback mockOnNotification = MockNotificationCallback();

      MockTabChangeCallback mockTabChange = MockTabChangeCallback();

      ElasticLibListener notifications = ElasticLibListener(
        ntConnection: mockConnection,
        onNotification: mockOnNotification.call,
        onTabSelected: mockTabChange.call,
      );

      notifications.listen();

      verify(mockConnection.subscribe('/Elastic/SelectedTab', 0.2)).called(1);
      verifyNever(mockTabChange(any));
      clearInteractions(mockTabChange);

      mockConnection.updateDataFromTopicName('/Elastic/SelectedTab', '2');
      verify(mockTabChange(2));
      mockConnection.updateDataFromTopicName('/Elastic/SelectedTab', '136');
      verify(mockTabChange(136));
    });

    test('passing in name', () {
      MockNTConnection mockConnection = createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
            name: '/Elastic/SelectedTab',
            type: NT4Type.string(),
            properties: {},
          ),
        ],
      );

      MockNotificationCallback mockOnNotification = MockNotificationCallback();

      MockTabChangeCallback mockTabChange = MockTabChangeCallback();

      ElasticLibListener notifications = ElasticLibListener(
        ntConnection: mockConnection,
        onNotification: mockOnNotification.call,
        onTabSelected: mockTabChange.call,
      );

      notifications.listen();

      verify(mockConnection.subscribe('/Elastic/SelectedTab', 0.2)).called(1);
      verifyNever(mockTabChange(any));
      clearInteractions(mockTabChange);

      mockConnection.updateDataFromTopicName('/Elastic/SelectedTab', 'tab 1');
      verify(mockTabChange('tab 1'));
      mockConnection.updateDataFromTopicName('/Elastic/SelectedTab', 'tab 2');
      verify(mockTabChange('tab 2'));
    });

    test('passing in invalid data', () {
      MockNTConnection mockConnection = createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
            name: '/Elastic/SelectedTab',
            type: NT4Type.string(),
            properties: {},
          ),
        ],
      );

      MockNotificationCallback mockOnNotification = MockNotificationCallback();

      MockTabChangeCallback mockTabChange = MockTabChangeCallback();

      ElasticLibListener notifications = ElasticLibListener(
        ntConnection: mockConnection,
        onNotification: mockOnNotification.call,
        onTabSelected: mockTabChange.call,
      );

      notifications.listen();

      verify(mockConnection.subscribe('/Elastic/SelectedTab', 0.2)).called(1);
      verifyNever(mockTabChange(any));
      clearInteractions(mockTabChange);

      mockConnection.updateDataFromTopicName('/Elastic/SelectedTab', 1.0);
      verifyNever(mockTabChange(any));
      mockConnection.updateDataFromTopicName('/Elastic/SelectedTab', [1, 2, 3]);
      verifyNever(mockTabChange(any));
    });
  });
}
