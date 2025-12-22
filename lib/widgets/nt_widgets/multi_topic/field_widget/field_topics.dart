import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:flutter/material.dart';

class SubscribedTopic<T extends Object?> {
  final NTConnection ntConnection;
  final String topic;
  final T defaultValue;
  final double period;

  late NT4Subscription subscription;

  SubscribedTopic({
    required this.ntConnection,
    required this.topic,
    required this.defaultValue,
    this.period = 0.1,
  });

  void subscribe() {
    subscription = ntConnection.subscribe(topic, period);
  }

  void unsubscribe() {
    ntConnection.unSubscribe(subscription);
  }

  T get value {
    final subValue = subscription.value;
    if (subValue is T) {
      return subValue;
    }
    return defaultValue;
  }
}

// Manages all vision-related NT topics.
class VisionTopics {
  final NTConnection ntConnection;
  final double period;

  late final SubscribedTopic<double> closeCamX;
  late final SubscribedTopic<double> closeCamY;
  late final SubscribedTopic<double> farCamX;
  late final SubscribedTopic<double> farCamY;
  late final SubscribedTopic<double> leftCamX;
  late final SubscribedTopic<double> leftCamY;
  late final SubscribedTopic<double> rightCamX;
  late final SubscribedTopic<double> rightCamY;

  late final SubscribedTopic<bool> rightCamLocation;
  late final SubscribedTopic<bool> rightCamHeading;
  late final SubscribedTopic<bool> leftCamLocation;
  late final SubscribedTopic<bool> leftCamHeading;
  late final SubscribedTopic<bool> closeCamLocation;
  late final SubscribedTopic<bool> closeCamHeading;
  late final SubscribedTopic<bool> farCamLocation;
  late final SubscribedTopic<bool> farCamHeading;

  late final List<SubscribedTopic> topics;

  VisionTopics({required this.ntConnection, this.period = 0.1}) {
    closeCamX = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Pose/CloseCamX',
      defaultValue: 0.0,
    );
    closeCamY = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Pose/CloseCamY',
      defaultValue: 0.0,
    );
    farCamX = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Pose/FarCamX',
      defaultValue: 0.0,
    );
    farCamY = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Pose/FarCamY',
      defaultValue: 0.0,
    );
    leftCamX = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Pose/LeftCamX',
      defaultValue: 0.0,
    );
    leftCamY = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Pose/LeftCamY',
      defaultValue: 0.0,
    );
    rightCamX = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Pose/RightCamX',
      defaultValue: 0.0,
    );
    rightCamY = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Pose/RightCamY',
      defaultValue: 0.0,
    );

    rightCamLocation = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Streams/RightLime/Location',
      defaultValue: false,
    );
    rightCamHeading = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Streams/RightLime/Heading',
      defaultValue: false,
    );
    leftCamLocation = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Streams/LeftLime/Location',
      defaultValue: false,
    );
    leftCamHeading = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Streams/LeftLime/Heading',
      defaultValue: false,
    );
    closeCamLocation = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Streams/CloseCam/Location',
      defaultValue: false,
    );
    closeCamHeading = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Streams/CloseCam/Heading',
      defaultValue: false,
    );
    farCamLocation = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Streams/FarCam/Location',
      defaultValue: false,
    );
    farCamHeading = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/Streams/FarCam/Heading',
      defaultValue: false,
    );

    topics = [
      closeCamX,
      closeCamY,
      farCamX,
      farCamY,
      leftCamX,
      leftCamY,
      rightCamX,
      rightCamY,
      rightCamLocation,
      rightCamHeading,
      leftCamLocation,
      leftCamHeading,
      closeCamLocation,
      closeCamHeading,
      farCamLocation,
      farCamHeading,
    ];
  }

  void initialize() {
    for (var topic in topics) {
      topic.subscribe();
    }
  }

  void dispose() {
    for (var topic in topics) {
      topic.unsubscribe();
    }
  }

  List<Listenable> get listenables =>
      topics.map((topic) => topic.subscription).toList();

  Offset get closeCamPose => Offset(closeCamX.value, closeCamY.value);
  Offset get farCamPose => Offset(farCamX.value, farCamY.value);
  Offset get leftCamPose => Offset(leftCamX.value, leftCamY.value);
  Offset get rightCamPose => Offset(rightCamX.value, rightCamY.value);
}

// Manages all game-piece-related NT topics.
class GamePieceTopics {
  final NTConnection ntConnection;
  final double period;

  late final SubscribedTopic<List<Object?>> gamePieces;

  GamePieceTopics({required this.ntConnection, this.period = 0.1}) {
    gamePieces = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/Match/GamePiecePos',
      defaultValue: [],
    );
  }

  void initialize() => gamePieces.subscribe();
  void dispose() => gamePieces.unsubscribe();

  List<Listenable> get listenables => [gamePieces.subscription];

  List<Offset> get value {
    List<String> raw = gamePieces.value.whereType<String>().toList();
    if (raw.isEmpty) {
      return [];
    }

    try {
      return raw
          .map((e) => e.split(' '))
          // In the format: x: 0.0, y: 0.0
          .map((e) => Offset(double.parse(e[1]), double.parse(e[3])))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

// Manages the FMS alliance color topic.
class AllianceTopic {
  final NTConnection ntConnection;
  final double period;

  late final SubscribedTopic<bool> isRedAlliance;

  AllianceTopic({required this.ntConnection, this.period = 0.1}) {
    isRedAlliance = SubscribedTopic(
      ntConnection: ntConnection,
      topic: '/FMSInfo/IsRedAlliance',
      defaultValue: false,
    );
  }

  void initialize() => isRedAlliance.subscribe();
  void dispose() => isRedAlliance.unsubscribe();

  List<Listenable> get listenables => [isRedAlliance.subscription];

  bool get value => isRedAlliance.value;
}

// Manages topics for commanding the robot pose.
class CommanderTopics {
  final NTConnection ntConnection;

  late final NT4Topic robotX;
  late final NT4Topic robotY;
  late final NT4Topic setNewPose;

  CommanderTopics({required this.ntConnection}) {
    robotX = ntConnection.publishNewTopic(
      '/Match/Commander/RobotPosResetX',
      NT4Type.double(),
    );
    robotY = ntConnection.publishNewTopic(
      '/Match/Commander/RobotPosResetY',
      NT4Type.double(),
    );
    setNewPose = ntConnection.publishNewTopic(
      '/Match/Commander/NewPosData',
      NT4Type.boolean(),
    );
  }

  void unpublish() {
    ntConnection.unpublishTopic(robotX);
    ntConnection.unpublishTopic(robotY);
    ntConnection.unpublishTopic(setNewPose);
  }

  void set(Offset pose) {
    ntConnection.updateDataFromTopic(robotX, pose.dx);
    ntConnection.updateDataFromTopic(robotY, pose.dy);
    ntConnection.updateDataFromTopic(setNewPose, true);
  }
}
