import 'dart:convert';

import 'package:dot_cast/dot_cast.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';

class ElasticLibListener {
  bool _alertFirstRun = true;
  final NTConnection ntConnection;
  final Function(
    String title,
    String description,
    Icon icon,
    Duration displayTime,
    double width,
    double? height,
  )
  onNotification;
  final Function(Object tabIdentifier) onTabSelected;

  ElasticLibListener({
    required this.ntConnection,
    required this.onNotification,
    required this.onTabSelected,
  });

  void listen() {
    var notifications = ntConnection.subscribeAll(
      '/Elastic/RobotNotifications',
      0.2,
    );
    notifications.listen((alertData, alertTimestamp) {
      if (alertData == null) {
        return;
      }
      _onAlert(alertData, alertTimestamp);
    });

    var tabSelection = ntConnection.subscribe('/Elastic/SelectedTab', 0.2);
    tabSelection.listen((tabData, _) {
      if (tabData == null || tabData is! String) {
        return;
      }
      onTabSelected(int.tryParse(tabData) ?? tabData);
    });

    ntConnection.addDisconnectedListener(() => _alertFirstRun = true);
  }

  void _onAlert(Object alertData, int timestamp) {
    // prevent showing a notification when we connect to NT
    if (_alertFirstRun) {
      _alertFirstRun = false;

      // If the alert existed 3 or more seconds before the client connected, ignore it
      Duration serverTime = Duration(microseconds: ntConnection.serverTime);
      Duration alertTime = Duration(microseconds: timestamp);
      // In theory if you had high enough latency and there was no existing data,
      // this would not work as intended. However, if you find yourself with 3
      // seconds of latency you have a much more serious issue to deal with as you
      // cannot control your robot with that much network latency, not to mention
      // that this code wouldn't even be executing since the RTT timestamp delay
      // would be so high that it would automatically disconnect from NT
      if ((serverTime - alertTime).inSeconds > 3) {
        return;
      }
    }

    Map<String, dynamic> data;
    Duration displayTime = const Duration(seconds: 3);
    double width = 350;
    double? height;
    try {
      data = jsonDecode(alertData.toString());
    } catch (e) {
      return;
    }

    if (!data.containsKey('level')) {
      return;
    }

    if (data.containsKey('displayTime')) {
      displayTime = Duration(
        milliseconds: (tryCast(data['displayTime']) ?? 3000),
      );
    }

    if (data.containsKey('width')) {
      width = tryCast(data['width']) ?? 350;
    }
    if (data.containsKey('height')) {
      height = tryCast(data['height']) ?? -1;

      if (height < 0) {
        height = null;
      }
    }

    Icon icon;

    if (data['level'] == 'INFO') {
      icon = const Icon(Icons.info);
    } else if (data['level'] == 'WARNING') {
      icon = const Icon(Icons.warning_amber, color: Colors.orange);
    } else if (data['level'] == 'ERROR') {
      icon = const Icon(Icons.error, color: Colors.red);
    } else {
      icon = const Icon(Icons.question_mark);
    }
    String? title = tryCast(data['title']);
    String? description = tryCast(data['description']);

    if (title == null || description == null) {
      return;
    }

    onNotification(title, description, icon, displayTime, width, height);
  }
}
