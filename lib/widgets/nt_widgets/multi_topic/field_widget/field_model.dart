import 'dart:async';
import 'dart:ui' as ui;

import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/field_widget/field_topics.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class FieldWidgetModel extends MultiTopicNTWidgetModel {
  @override
  String type = 'Field';

  String get robotTopicName => '$topic/Robot';
  late NT4Subscription robotXSubscription;
  late NT4Subscription robotYSubscription;
  late NT4Subscription robotHeadingSubscription;
  ui.Image? _robotImage;

  final List<String> otherObjectTopics = [];
  final List<NT4Subscription> otherObjectSubscriptions = [];

  late final VisionTopics visionTopics;
  late final GamePieceTopics gamePieceTopics;
  late final AllianceTopic allianceTopic;
  late final CommanderTopics commanderTopics;

  @override
  List<NT4Subscription> get subscriptions => [
    robotXSubscription,
    robotYSubscription,
    robotHeadingSubscription,
    ...otherObjectSubscriptions,
    ...visionTopics.listenables.whereType<NT4Subscription>(),
    ...gamePieceTopics.listenables.whereType<NT4Subscription>(),
    ...allianceTopic.listenables.whereType<NT4Subscription>(),
  ];

  bool rendered = false;

  late Function(NT4Topic topic) topicAnnounceListener;

  static const String _defaultGame = 'Reefscape';
  String _fieldGame = _defaultGame;
  late Field _field;

  String? _robotImagePath;
  double _robotWidthMeters = 0.85;
  double _robotLengthMeters = 0.85;

  bool _showOtherObjects = true;
  bool _showTrajectories = true;

  bool _showVisionTargets = false;
  bool _showGamePieces = false;

  double _fieldRotation = 0.0;

  Color _robotColor = Colors.red;
  Color _trajectoryColor = Colors.white;
  Color _visionTargetColor = Colors.green;
  Color _gamePieceColor = Colors.yellow;
  Color _bestGamePieceColor = Colors.orange;

  final double _otherObjectSize = 0.55;
  final double _trajectoryPointSize = 0.08;
  final double _visionMarkerSize = 15.0;
  final double _gamePieceMarkerSize = 15.0;

  Size? widgetSize;

  ui.Image? get robotImage => _robotImage;

  String? get robotImagePath => _robotImagePath;

  set robotImagePath(String? value) {
    _robotImagePath = value;
    _loadImage();
    refresh();
  }

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

  bool get showVisionTargets => _showVisionTargets;

  set showVisionTargets(bool value) {
    _showVisionTargets = value;
    refresh();
  }

  bool get showGamePieces => _showGamePieces;

  set showGamePieces(bool value) {
    _showGamePieces = value;
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

  Color get visionTargetColor => _visionTargetColor;

  set visionTargetColor(Color value) {
    _visionTargetColor = value;
    refresh();
  }

  Color get gamePieceColor => _gamePieceColor;

  set gamePieceColor(Color value) {
    _gamePieceColor = value;
    refresh();
  }

  Color get bestGamePieceColor => _bestGamePieceColor;

  set bestGamePieceColor(Color value) {
    _bestGamePieceColor = value;
    refresh();
  }

  double get otherObjectSize => _otherObjectSize;

  double get trajectoryPointSize => _trajectoryPointSize;

  double get visionMarkerSize => _visionMarkerSize;

  double get gamePieceMarkerSize => _gamePieceMarkerSize;

  Field get field => _field;

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
    String? robotImagePath,
    bool showOtherObjects = true,
    bool showTrajectories = true,
    bool showVisionTargets = false,
    bool showGamePieces = false,
    double robotWidthMeters = 0.85,
    double robotLengthMeters = 0.85,
    double fieldRotation = 0.0,
    Color robotColor = Colors.red,
    Color trajectoryColor = Colors.white,
    Color visionTargetColor = Colors.green,
    Color gamePieceColor = Colors.yellow,
    Color bestGamePieceColor = Colors.orange,
    super.period,
  }) : _showTrajectories = showTrajectories,
       _showOtherObjects = showOtherObjects,
       _showVisionTargets = showVisionTargets,
       _showGamePieces = showGamePieces,
       _robotImagePath = robotImagePath,
       _robotWidthMeters = robotWidthMeters,
       _robotLengthMeters = robotLengthMeters,
       _fieldRotation = fieldRotation,
       _robotColor = robotColor,
       _trajectoryColor = trajectoryColor,
       _visionTargetColor = visionTargetColor,
       _gamePieceColor = gamePieceColor,
       _bestGamePieceColor = bestGamePieceColor,
       super() {
    if (!FieldImages.hasField(_fieldGame)) {
      _fieldGame = _defaultGame;
    }

    final Field? field = FieldImages.getFieldFromGame(_fieldGame);

    if (field == null) {
      if (FieldImages.fields.isNotEmpty) {
        _field = FieldImages.fields.first;
      } else {
        throw Exception('No field images loaded, cannot create Field Widget');
      }
    } else {
      _field = field;
    }

    visionTopics = VisionTopics(ntConnection: ntConnection, period: period);
    gamePieceTopics = GamePieceTopics(
      ntConnection: ntConnection,
      period: period,
    );
    allianceTopic = AllianceTopic(ntConnection: ntConnection, period: period);
    commanderTopics = CommanderTopics(ntConnection: ntConnection);
  }

  FieldWidgetModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    visionTopics = VisionTopics(
      ntConnection: ntConnection,
      period: super.period,
    );
    gamePieceTopics = GamePieceTopics(
      ntConnection: ntConnection,
      period: super.period,
    );
    allianceTopic = AllianceTopic(
      ntConnection: ntConnection,
      period: super.period,
    );
    commanderTopics = CommanderTopics(ntConnection: ntConnection);

    _fieldGame = tryCast(jsonData['field_game']) ?? _fieldGame;

    _robotImagePath = tryCast(jsonData['robot_image_path']);
    _robotWidthMeters = tryCast(jsonData['robot_width']) ?? 0.85;
    _robotLengthMeters =
        tryCast(jsonData['robot_length']) ??
        tryCast(jsonData['robot_height']) ??
        0.85;

    _showOtherObjects = tryCast(jsonData['show_other_objects']) ?? true;
    _showTrajectories = tryCast(jsonData['show_trajectories']) ?? true;
    _showVisionTargets = tryCast(jsonData['show_vision_targets']) ?? false;
    _showGamePieces = tryCast(jsonData['show_game_pieces']) ?? false;

    _fieldRotation = tryCast(jsonData['field_rotation']) ?? 0.0;

    _robotColor = Color(
      tryCast(jsonData['robot_color']) ?? Colors.red.toARGB32(),
    );
    _trajectoryColor = Color(
      tryCast(jsonData['trajectory_color']) ?? Colors.white.toARGB32(),
    );
    _visionTargetColor = Color(
      tryCast(jsonData['vision_target_color']) ?? Colors.green.toARGB32(),
    );
    _gamePieceColor = Color(
      tryCast(jsonData['game_piece_color']) ?? Colors.yellow.toARGB32(),
    );
    _bestGamePieceColor = Color(
      tryCast(jsonData['best_game_piece_color']) ?? Colors.orange.toARGB32(),
    );

    if (!FieldImages.hasField(_fieldGame)) {
      _fieldGame = _defaultGame;
    }

    final Field? field = FieldImages.getFieldFromGame(_fieldGame);

    if (field == null) {
      if (FieldImages.fields.isNotEmpty) {
        _field = FieldImages.fields.first;
      } else {
        throw Exception('No field images loaded, cannot create Field Widget');
      }
    } else {
      _field = field;
    }
  }

  @override
  void init() {
    super.init();
    _loadImage();

    topicAnnounceListener = (nt4Topic) {
      if (nt4Topic.name.startsWith(topic) &&
          !nt4Topic.name.endsWith('Robot') &&
          !nt4Topic.name.contains('.') &&
          !otherObjectTopics.contains(nt4Topic.name)) {
        otherObjectTopics.add(nt4Topic.name);
        otherObjectSubscriptions.add(
          ntConnection.subscribe(nt4Topic.name, super.period),
        );
        refresh();
      }
    };

    ntConnection.addTopicAnnounceListener(topicAnnounceListener);
  }

  Future<void> _loadImage() async {
    if (_robotImagePath == null || _robotImagePath!.isEmpty) {
      _robotImage = null;
      return;
    }

    try {
      final Image assetImage = Image.asset(_robotImagePath!);

      final Completer<ui.Image> completer = Completer<ui.Image>();
      assetImage.image
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener((info, _) {
              completer.complete(info.image);
            }),
          );

      _robotImage = await completer.future;
      refresh();
    } catch (e) {
      _robotImage = null;
    }
  }

  @override
  void initializeSubscriptions() {
    otherObjectSubscriptions.clear();

    robotXSubscription = ntConnection.subscribe(
      '${robotTopicName}X',
      super.period,
    );
    robotYSubscription = ntConnection.subscribe(
      '${robotTopicName}Y',
      super.period,
    );
    robotHeadingSubscription = ntConnection.subscribe(
      '${robotTopicName}Heading',
      super.period,
    );

    visionTopics.initialize();
    gamePieceTopics.initialize();
    allianceTopic.initialize();
  }

  @override
  void resetSubscription() {
    otherObjectTopics.clear();

    super.resetSubscription();

    visionTopics.dispose();
    gamePieceTopics.dispose();
    allianceTopic.dispose();
    commanderTopics.unpublish();

    ntConnection.removeTopicAnnounceListener(topicAnnounceListener);
    ntConnection.addTopicAnnounceListener(topicAnnounceListener);
  }

  @override
  void softDispose({bool deleting = false}) async {
    super.softDispose(deleting: deleting);

    if (deleting) {
      await _field.dispose();
      ntConnection.removeTopicAnnounceListener(topicAnnounceListener);
      visionTopics.dispose();
      gamePieceTopics.dispose();
      allianceTopic.dispose();
      commanderTopics.unpublish();
    }

    widgetSize = null;
    rendered = false;
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'field_game': _fieldGame,
    'robot_image_path': _robotImagePath,
    'robot_width': _robotWidthMeters,
    'robot_length': _robotLengthMeters,
    'show_other_objects': _showOtherObjects,
    'show_trajectories': _showTrajectories,
    'show_vision_targets': _showVisionTargets,
    'show_game_pieces': _showGamePieces,
    'field_rotation': _fieldRotation,
    'robot_color': robotColor.toARGB32(),
    'trajectory_color': trajectoryColor.toARGB32(),
    'vision_target_color': _visionTargetColor.toARGB32(),
    'game_piece_color': _gamePieceColor.toARGB32(),
    'best_game_piece_color': _bestGamePieceColor.toARGB32(),
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
    DialogTextInput(
      onSubmit: (value) {
        robotImagePath = value;
      },
      label: 'Robot Image Path',
      initialText: _robotImagePath ?? '',
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
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          child: DialogToggleSwitch(
            label: 'Show Vision Targets',
            initialValue: _showVisionTargets,
            onToggle: (value) {
              showVisionTargets = value;
            },
          ),
        ),
        Flexible(
          child: DialogToggleSwitch(
            label: 'Show Game Pieces',
            initialValue: _showGamePieces,
            onToggle: (value) {
              showGamePieces = value;
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
              label: 'Robot',
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
              label: 'Trajectory',
              initialColor: trajectoryColor,
              defaultColor: Colors.white,
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
                visionTargetColor = color;
              },
              label: 'Vision',
              initialColor: _visionTargetColor,
              defaultColor: Colors.green,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: DialogColorPicker(
              onColorPicked: (color) {
                gamePieceColor = color;
              },
              label: 'Gamepiece',
              initialColor: _gamePieceColor,
              defaultColor: Colors.yellow,
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 10),
    Row(
      children: [
        const Spacer(),
        DialogColorPicker(
          onColorPicked: (color) {
            bestGamePieceColor = color;
          },
          label: 'Best Gamepiece',
          initialColor: _bestGamePieceColor,
          defaultColor: Colors.orange,
        ),
        const Spacer(),
      ],
    ),
  ];
}
