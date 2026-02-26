import 'dart:convert';

import 'package:dot_cast/dot_cast.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';

typedef LayoutDownloadResponse<T> = ({bool successful, T data});

class ElasticLayoutDownloader {
  final Client client;

  ElasticLayoutDownloader(this.client);

  Future<LayoutDownloadResponse<String>> downloadLayout({
    required NTConnection ntConnection,
    required SharedPreferences preferences,
    required String layoutName,
  }) async {
    if (!ntConnection.isNT4Connected) {
      return (
        successful: false,
        data:
            'Cannot download a remote layout while disconnected from the robot.',
      );
    }
    String layoutPort =
        preferences.getString(PrefKeys.layoutPort) ?? Defaults.layoutPort;
    String robotIP =
        preferences.getString(PrefKeys.ipAddress) ?? Defaults.ipAddress;
    String escapedName = Uri.encodeComponent('$layoutName.json');
    Uri robotUri = Uri.parse('http://$robotIP:$layoutPort/$escapedName');
    Response response;
    try {
      response = await client.get(robotUri);
    } on ClientException catch (e) {
      return (successful: false, data: e.message);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String errorMessage = switch (response.statusCode) {
        404 => 'File "$layoutName.json" was not found',
        _ => 'Request returned status code ${response.statusCode}',
      };

      return (successful: false, data: errorMessage);
    }
    return (successful: true, data: response.body);
  }

  Future<LayoutDownloadResponse<List<String>>> getAvailableLayouts({
    required NTConnection ntConnection,
    required SharedPreferences preferences,
  }) async {
    if (!ntConnection.isNT4Connected) {
      return (
        successful: false,
        data: <String>[
          'Cannot fetch remote layouts while disconnected from the robot',
        ],
      );
    }
    String robotIP =
        preferences.getString(PrefKeys.ipAddress) ?? Defaults.ipAddress;
    String layoutPort =
        preferences.getString(PrefKeys.layoutPort) ?? Defaults.layoutPort;
    Uri robotUri = Uri.parse('http://$robotIP:$layoutPort/?format=json');
    Response response;
    try {
      response = await client.get(robotUri);
    } on ClientException catch (e) {
      return (successful: false, data: [e.message]);
    }
    Map<String, dynamic>? responseJson = tryCast(jsonDecode(response.body));
    if (responseJson == null) {
      return (successful: false, data: ['Response was not a json object']);
    }
    if (!responseJson.containsKey('files')) {
      return (
        successful: false,
        data: ['Response json does not contain files list'],
      );
    }

    List<String> fileNames = [];
    for (Map<String, dynamic> fileData in responseJson['files']) {
      String? name = fileData['name'];
      if (name == null) {
        continue;
      }
      if (name.endsWith('json')) {
        fileNames.add(name.substring(0, name.length - '.json'.length));
      }
    }
    return (successful: true, data: fileNames);
  }
}
