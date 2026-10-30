import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/elastic_layout_downloader.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';

import '../test_util.dart';
import '../test_util.mocks.dart';

const Map<String, dynamic> layoutFiles = {
  'dirs': [],
  'files': [
    {'name': 'elastic-layout 1.json', 'size': 1000},
    {'name': 'elastic-layout 2.json', 'size': 1000},
    {'name': 'example.txt', 'size': 1},
  ],
};

const Map<String, dynamic> layoutOne = {
  'version': 1.0,
  'grid_size': 128.0,
  'tabs': [
    {
      'name': 'Test Tab',
      'grid_layout': {
        'layouts': [
          {
            'title': 'Subsystem',
            'x': 384.0,
            'y': 128.0,
            'width': 256.0,
            'height': 384.0,
            'type': 'List Layout',
            'properties': {'label_position': 'TOP'},
            'children': [
              {
                'title': 'ExampleSubsystem',
                'x': 0.0,
                'y': 0.0,
                'width': 256.0,
                'height': 128.0,
                'type': 'Subsystem',
                'properties': {
                  'topic': '/Test Tab/ExampleSubsystem',
                  'period': 0.06,
                },
              },
              {
                'title': 'Gyro',
                'x': 0.0,
                'y': 0.0,
                'width': 256.0,
                'height': 256.0,
                'type': 'Gyro',
                'properties': {
                  'topic': '/Test Tab/Gyro',
                  'period': 0.06,
                  'counter_clockwise_positive': false,
                },
              },
            ],
          },
          {
            'title': 'Empty Layout',
            'x': 640.0,
            'y': 0.0,
            'width': 256.0,
            'height': 256.0,
            'type': 'List Layout',
            'properties': {'label_position': 'TOP'},
            'children': [],
          },
        ],
        'containers': [
          {
            'title': 'Test Widget',
            'x': 128.0,
            'y': 128.0,
            'width': 256.0,
            'height': 256.0,
            'type': 'Gyro',
            'properties': {
              'topic': '/Test Tab/Gyro',
              'period': 0.06,
              'counter_clockwise_positive': false,
            },
          },
        ],
      },
    },
  ],
};

void main() {
  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      PrefKeys.ipAddress: '127.0.0.1',
      PrefKeys.layoutLocked: false,
    });

    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4();
  });

  test('Get list of available layouts', () async {
    Client mockClient = createHttpClient(
      mockGetResponses: {
        'http://127.0.0.1:5800/?format=json': Response(
          jsonEncode(layoutFiles),
          200,
        ),
      },
    );

    ElasticLayoutDownloader layoutDownloader = ElasticLayoutDownloader(
      mockClient,
    );

    LayoutDownloadResponse downloadResponse = await layoutDownloader
        .getAvailableLayouts(
          ntConnection: ntConnection,
          preferences: preferences,
        );

    expect(downloadResponse.successful, isTrue);
    expect(
      downloadResponse.data,
      unorderedEquals(['elastic-layout 1', 'elastic-layout 2']),
    );
  });

  test('Download layout', () async {
    Client mockClient = createHttpClient(
      mockGetResponses: {
        'http://127.0.0.1:5800/${Uri.encodeComponent('elastic-layout 1.json')}':
            Response(jsonEncode(layoutOne), 200),
      },
    );

    ElasticLayoutDownloader layoutDownloader = ElasticLayoutDownloader(
      mockClient,
    );

    LayoutDownloadResponse downloadResponse = await layoutDownloader
        .downloadLayout(
          ntConnection: ntConnection,
          preferences: preferences,
          layoutName: 'elastic-layout 1',
        );

    expect(downloadResponse.successful, isTrue);
    expect(downloadResponse.data, jsonEncode(layoutOne));
  });

  group('Unsuccessful if', () {
    test('network tables is disconnected', () async {
      Client mockClient = createHttpClient(
        mockGetResponses: {
          'http://127.0.0.1:5800/${Uri.encodeComponent('elastic-layout 1.json')}':
              Response(jsonEncode(layoutOne), 200),
        },
      );

      ElasticLayoutDownloader layoutDownloader = ElasticLayoutDownloader(
        mockClient,
      );

      LayoutDownloadResponse downloadResponse = await layoutDownloader
          .downloadLayout(
            ntConnection: createMockOfflineNT4(),
            preferences: preferences,
            layoutName: 'elastic-layout 1',
          );

      expect(downloadResponse.successful, false);
      expect(
        downloadResponse.data,
        'Cannot download a remote layout while disconnected from the robot.',
      );
    });

    test('client response throws an error', () async {
      MockClient mockClient = MockClient();
      when(
        mockClient.get(any),
      ).thenAnswer((_) => throw ClientException('Client Exception'));

      ElasticLayoutDownloader layoutDownloader = ElasticLayoutDownloader(
        mockClient,
      );

      LayoutDownloadResponse downloadResponse = await layoutDownloader
          .downloadLayout(
            ntConnection: createMockOnlineNT4(),
            preferences: preferences,
            layoutName: 'elastic-layout 1',
          );

      expect(downloadResponse.successful, false);
      expect(downloadResponse.data, 'Client Exception');
    });

    test('file is not found', () async {
      Client mockClient = createHttpClient(
        mockGetResponses: {
          'http://127.0.0.1:5800/${Uri.encodeComponent('elastic-layout 1.json')}':
              Response(jsonEncode(layoutOne), 404),
        },
      );

      ElasticLayoutDownloader layoutDownloader = ElasticLayoutDownloader(
        mockClient,
      );

      LayoutDownloadResponse downloadResponse = await layoutDownloader
          .downloadLayout(
            ntConnection: createMockOnlineNT4(),
            preferences: preferences,
            layoutName: 'elastic-layout 1',
          );

      expect(downloadResponse.successful, false);
      expect(
        downloadResponse.data,
        'File "elastic-layout 1.json" was not found',
      );
    });

    test('http request gives invalid status code', () async {
      Client mockClient = createHttpClient(
        mockGetResponses: {
          'http://127.0.0.1:5800/${Uri.encodeComponent('elastic-layout 1.json')}':
              Response(jsonEncode(layoutOne), 353),
        },
      );

      ElasticLayoutDownloader layoutDownloader = ElasticLayoutDownloader(
        mockClient,
      );

      LayoutDownloadResponse downloadResponse = await layoutDownloader
          .downloadLayout(
            ntConnection: createMockOnlineNT4(),
            preferences: preferences,
            layoutName: 'elastic-layout 1',
          );

      expect(downloadResponse.successful, false);
      expect(downloadResponse.data, 'Request returned status code 353');
    });
  });
}
