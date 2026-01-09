import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vector_math/vector_math_64.dart' show radians;

import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/struct_schemas/pose2d_struct.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

enum FieldObjectType { robot, trajectory, otherObject }

class FieldObject {
  FieldObjectType type;
  Pose2dStruct? pose;
  List<Pose2dStruct>? poses;

  double get x => pose!.x;
  double get y => pose!.y;
  double get angle => pose!.angle;

  FieldObject({required this.type, this.pose, this.poses})
    : assert(pose != null || poses != null);
}

class FieldWidgetModel extends MultiTopicNTWidgetModel {
  @override
  String type = 'Field';

  String get robotTopicName => '$topic/Robot';
  late NT4Subscription robotSubscription;

  final List<String> _otherObjectTopics = [];
  final List<NT4Subscription> _otherObjectSubscriptions = [];

  @override
  List<NT4Subscription> get subscriptions => [
    robotSubscription,
    ..._otherObjectSubscriptions,
  ];

  List<NT4Subscription> get otherObjectSubscriptions =>
      _otherObjectSubscriptions;

  late Function(NT4Topic topic) topicAnnounceListener;

  static const String _defaultGame = 'Rebuilt';
  String _fieldGame = _defaultGame;
  late Field _field;

  double _robotWidthMeters = 0.85;
  double _robotLengthMeters = 0.85;

  bool _showOtherObjects = true;
  bool _showTrajectories = true;

  double _fieldRotation = 0.0;

  Color _robotColor = Colors.red;
  Color _trajectoryColor = Colors.white;

  bool _showRobotOutsideWidget = true;

  final double _otherObjectSize = 0.55;
  final double _trajectoryPointSize = 0.08;

  double get robotWidthMeters => _robotWidthMeters;

  set robotWidthMeters(double value) {
    _robotWidthMeters = value;
    refresh();
  }

  double get robotLengthMeters => _robotLengthMeters;

  set robotLengthMeters(double value) {
    _robotLengthMeters = value;
    refresh();
  }

  bool get showOtherObjects => _showOtherObjects;

  set showOtherObjects(bool value) {
    _showOtherObjects = value;
    refresh();
  }

  bool get showTrajectories => _showTrajectories;

  set showTrajectories(bool value) {
    _showTrajectories = value;
    refresh();
  }

  double get fieldRotation => _fieldRotation;

  set fieldRotation(double value) {
    _fieldRotation = value;
    refresh();
  }

  Color get robotColor => _robotColor;

  set robotColor(Color value) {
    _robotColor = value;
    refresh();
  }

  Color get trajectoryColor => _trajectoryColor;

  set trajectoryColor(Color value) {
    _trajectoryColor = value;
    refresh();
  }

  set showRobotOutsideWidget(bool value) {
    _showRobotOutsideWidget = value;
    refresh();
  }

  bool get showRobotOutsideWidget => _showRobotOutsideWidget;

  double get otherObjectSize => _otherObjectSize;

  double get trajectoryPointSize => _trajectoryPointSize;

  Field get field => _field;

  final TransformationController transformController =
      TransformationController();

  Size? widgetSize;

  bool rendered = false;

  FieldObject getRobotObject() {
    List<Object?> robotPositionRaw =
        robotSubscription.value?.tryCast<List<Object?>>() ?? [];

    if (isPoseStruct(robotTopicName)) {
      List<int> poseBytes = robotPositionRaw.whereType<int>().toList();
      Pose2dStruct poseStruct = Pose2dStruct.valueFromBytes(
        Uint8List.fromList(poseBytes),
      );

      return FieldObject(type: FieldObjectType.robot, pose: poseStruct);
    } else {
      List<double> robotPosition = robotPositionRaw
          .whereType<double>()
          .toList();

      double robotX = 0;
      double robotY = 0;
      double robotTheta = 0;

      if (robotPosition.length >= 3) {
        robotX = robotPosition[0];
        robotY = robotPosition[1];
        robotTheta = radians(robotPosition[2]);
      }
      return FieldObject(
        type: FieldObjectType.robot,
        pose: Pose2dStruct(x: robotX, y: robotY, angle: robotTheta),
      );
    }
  }

  List<FieldObject> getAllObjects() {
    List<FieldObject> objects = [];

    for (NT4Subscription objectSubscription in otherObjectSubscriptions) {
      List<Object?>? objectPositionRaw = objectSubscription.value
          ?.tryCast<List<Object?>>();

      if (objectPositionRaw == null) {
        continue;
      }

      bool isTrajectory = objectSubscription.topic.toLowerCase().endsWith(
        'trajectory',
      );

      bool isStructArray = isPoseArrayStruct(
        objectSubscription.topic,
      );

      bool isStructObject =
          isPoseStruct(objectSubscription.topic) || isStructArray;

      if (isStructObject) {
        isTrajectory =
            isTrajectory ||
            (isStructArray &&
                objectPositionRaw.length ~/ Pose2dStruct.length > 8);
      } else {
        isTrajectory = isTrajectory || objectPositionRaw.length > 24;
      }

      if (isTrajectory) {
        List<Pose2dStruct> objectTrajectory = [];

        if (isStructObject) {
          List<int> structArrayBytes = objectPositionRaw
              .whereType<int>()
              .toList();

          List<Pose2dStruct> poseArray = Pose2dStruct.listFromBytes(
            Uint8List.fromList(structArrayBytes),
          );

          objectTrajectory.addAll(poseArray);
        } else {
          List<double> objectPosition = objectPositionRaw
              .whereType<double>()
              .toList();

          for (int i = 0; i < objectPosition.length - 2; i += 3) {
            objectTrajectory.add(
              Pose2dStruct(
                x: objectPosition[i],
                y: objectPosition[i + 1],
                angle: 0,
              ),
            );
          }
        }

        if (objectTrajectory.isNotEmpty) {
          objects.add(
            FieldObject(
              type: FieldObjectType.trajectory,
              poses: objectTrajectory,
            ),
          );
        }
      } else {
        if (isStructObject) {
          List<int> structBytes = objectPositionRaw.whereType<int>().toList();
          if (isStructArray) {
            List<Pose2dStruct> poses = Pose2dStruct.listFromBytes(
              Uint8List.fromList(structBytes),
            );

            for (Pose2dStruct pose in poses) {
              objects.add(
                FieldObject(type: FieldObjectType.otherObject, pose: pose),
              );
            }
          } else {
            Pose2dStruct pose = Pose2dStruct.valueFromBytes(
              Uint8List.fromList(structBytes),
            );

            objects.add(
              FieldObject(
                type: FieldObjectType.otherObject,
                pose: pose,
              ),
            );
          }
        } else {
          List<double> objectPosition = objectPositionRaw
              .whereType<double>()
              .toList();

          for (int i = 0; i < objectPosition.length - 2; i += 3) {
            List<double> positionArray = objectPosition.sublist(
              i,
              i + 3,
            );
            objects.add(
              FieldObject(
                type: FieldObjectType.otherObject,
                pose: Pose2dStruct(
                  x: positionArray[0],
                  y: positionArray[1],
                  angle: radians(positionArray[2]),
                ),
              ),
            );
          }
        }
      }
    }

    return objects;
  }

  bool isPoseStruct(String topic) =>
      ntConnection.getTopicFromName(topic)?.type.serialize() == 'struct:Pose2d';

  bool isPoseArrayStruct(String topic) =>
      ntConnection.getTopicFromName(topic)?.type.serialize() ==
      'struct:Pose2d[]';

  FieldWidgetModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    String? fieldGame,
    bool showOtherObjects = true,
    bool showTrajectories = true,
    double robotWidthMeters = 0.85,
    double robotLengthMeters = 0.85,
    double fieldRotation = 0.0,
    Color robotColor = Colors.red,
    Color trajectoryColor = Colors.white,
    bool showRobotOutsideWidget = true,
    super.period,
  }) : _showTrajectories = showTrajectories,
       _showOtherObjects = showOtherObjects,
       _robotWidthMeters = robotWidthMeters,
       _robotLengthMeters = robotLengthMeters,
       _fieldRotation = fieldRotation,
       _robotColor = robotColor,
       _trajectoryColor = trajectoryColor,
       _showRobotOutsideWidget = showRobotOutsideWidget,
       super() {
    _fieldGame = fieldGame ?? _fieldGame;

    if (!FieldImages.hasField(_fieldGame)) {
      _fieldGame = _defaultGame;
    }

    _field = FieldImages.getFieldFromGame(_fieldGame)!;
  }

  FieldWidgetModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _fieldGame = tryCast(jsonData['field_game']) ?? _fieldGame;

    _robotWidthMeters = tryCast(jsonData['robot_width']) ?? 0.85;
    _robotLengthMeters =
        tryCast(jsonData['robot_length']) ??
        tryCast(jsonData['robot_height']) ??
        0.85;

    _showOtherObjects = tryCast(jsonData['show_other_objects']) ?? true;
    _showTrajectories = tryCast(jsonData['show_trajectories']) ?? true;

    _fieldRotation = tryCast(jsonData['field_rotation']) ?? 0.0;

    _robotColor = Color(
      tryCast(jsonData['robot_color']) ?? Colors.red.toARGB32(),
    );
    _trajectoryColor = Color(
      tryCast(jsonData['trajectory_color']) ?? Colors.white.toARGB32(),
    );

    _showRobotOutsideWidget =
        tryCast(jsonData['show_robot_outside_widget']) ?? true;

    if (!FieldImages.hasField(_fieldGame)) {
      _fieldGame = _defaultGame;
    }

    _field = FieldImages.getFieldFromGame(_fieldGame)!;
  }

  @override
  void init() {
    super.init();

    topicAnnounceListener = (nt4Topic) {
      if (nt4Topic.name.startsWith(topic) &&
          !nt4Topic.name.endsWith('Robot') &&
          !nt4Topic.name.contains('.') &&
          !_otherObjectTopics.contains(nt4Topic.name)) {
        _otherObjectTopics.add(nt4Topic.name);
        _otherObjectSubscriptions.add(
          ntConnection.subscribe(nt4Topic.name, super.period),
        );
        refresh();
      }
    };

    ntConnection.addTopicAnnounceListener(topicAnnounceListener);
  }

  @override
  void initializeSubscriptions() {
    _otherObjectSubscriptions.clear();

    robotSubscription = ntConnection.subscribe(robotTopicName, super.period);
  }

  @override
  void resetSubscription() {
    _otherObjectTopics.clear();

    super.resetSubscription();

    // If the topic changes the other objects need to be found under the new root table
    ntConnection.removeTopicAnnounceListener(topicAnnounceListener);
    ntConnection.addTopicAnnounceListener(topicAnnounceListener);
  }

  @override
  void softDispose({bool deleting = false}) async {
    super.softDispose(deleting: deleting);

    if (deleting) {
      await _field.dispose();
      ntConnection.removeTopicAnnounceListener(topicAnnounceListener);
    }

    widgetSize = null;
    rendered = false;
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'field_game': _fieldGame,
    'robot_width': _robotWidthMeters,
    'robot_length': _robotLengthMeters,
    'show_other_objects': _showOtherObjects,
    'show_trajectories': _showTrajectories,
    'field_rotation': _fieldRotation,
    'robot_color': robotColor.toARGB32(),
    'trajectory_color': trajectoryColor.toARGB32(),
    'show_robot_outside_widget': showRobotOutsideWidget,
  };

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    Center(
      child: RichText(
        text: TextSpan(
          text: 'Field Image (',
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            WidgetSpan(
              child: Tooltip(
                waitDuration: const Duration(milliseconds: 750),
                richMessage: WidgetSpan(
                  // Builder is used so the message updates when the field image is changed
                  child: Builder(
                    builder: (context) => Text(
                      _field.sourceURL ?? '',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall!.copyWith(color: Colors.black),
                    ),
                  ),
                ),
                child: RichText(
                  text: TextSpan(
                    text: 'Source',
                    style: const TextStyle(color: Colors.blue),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        if (_field.sourceURL == null) {
                          return;
                        }
                        Uri? url = Uri.tryParse(_field.sourceURL!);
                        if (url == null) {
                          return;
                        }
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                  ),
                ),
              ),
            ),
            TextSpan(
              text: ')',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    ),
    DialogDropdownChooser<String?>(
      onSelectionChanged: (value) async {
        if (value == null) {
          return;
        }

        Field? newField = FieldImages.getFieldFromGame(value);

        if (newField == null) {
          return;
        }

        _fieldGame = value;
        await _field.dispose();
        _field = newField;

        widgetSize = null;
        rendered = false;

        refresh();
      },
      choices: FieldImages.fields.map((e) => e.game).toList(),
      initialValue: _field.game,
    ),
    const SizedBox(height: 5),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          child: DialogTextInput(
            onSubmit: (value) {
              double? newWidth = double.tryParse(value);

              if (newWidth == null) {
                return;
              }
              robotWidthMeters = newWidth;
            },
            formatter: TextFormatterBuilder.decimalTextFormatter(),
            label: 'Robot Width (meters)',
            initialText: _robotWidthMeters.toString(),
          ),
        ),
        Flexible(
          child: DialogTextInput(
            onSubmit: (value) {
              double? newLength = double.tryParse(value);

              if (newLength == null) {
                return;
              }
              robotLengthMeters = newLength;
            },
            formatter: TextFormatterBuilder.decimalTextFormatter(),
            label: 'Robot Length (meters)',
            initialText: _robotLengthMeters.toString(),
          ),
        ),
      ],
    ),
    const SizedBox(height: 5),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          child: DialogToggleSwitch(
            label: 'Show Non-Robot Objects',
            initialValue: _showOtherObjects,
            onToggle: (value) {
              showOtherObjects = value;
            },
          ),
        ),
        Flexible(
          child: DialogToggleSwitch(
            label: 'Show Trajectories',
            initialValue: _showTrajectories,
            onToggle: (value) {
              showTrajectories = value;
            },
          ),
        ),
      ],
    ),
    const SizedBox(height: 5),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.0),
                ),
              ),
              label: const Text('Rotate Left'),
              icon: const Icon(Icons.rotate_90_degrees_ccw),
              onPressed: () {
                double newRotation = fieldRotation - 90;
                if (newRotation < -180) {
                  newRotation += 360;
                }
                fieldRotation = newRotation;
                transformController.value = Matrix4.identity();
              },
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.0),
                ),
              ),
              label: const Text('Rotate Right'),
              icon: const Icon(Icons.rotate_90_degrees_cw),
              onPressed: () {
                double newRotation = fieldRotation + 90;
                if (newRotation > 180) {
                  newRotation -= 360;
                }
                fieldRotation = newRotation;
                transformController.value = Matrix4.identity();
              },
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 10),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: DialogColorPicker(
              onColorPicked: (color) {
                robotColor = color;
              },
              label: 'Robot Color',
              initialColor: robotColor,
              defaultColor: Colors.red,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: DialogColorPicker(
              onColorPicked: (color) {
                trajectoryColor = color;
              },
              label: 'Trajectory Color',
              initialColor: trajectoryColor,
              defaultColor: Colors.white,
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 5),
    Row(
      children: [
        Tooltip(
          waitDuration: const Duration(milliseconds: 100),
          message:
              'If turned on, the robot will be able to drive off the field and remain visible.\nIf turned off, a circular indicator will be visible when the robot goes off the field.',
          child: Icon(Icons.help),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: DialogToggleSwitch(
            onToggle: (value) => showRobotOutsideWidget = value,
            initialValue: showRobotOutsideWidget,
            label: 'Show Robot Outside Widget',
          ),
        ),
      ],
    ),
  ];
}
