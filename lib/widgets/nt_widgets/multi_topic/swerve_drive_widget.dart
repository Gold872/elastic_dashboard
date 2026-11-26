import 'dart:math';
import 'dart:typed_data';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' show radians;

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/struct_schemas/swerve_module_state_struct.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class SwerveDriveWidgetModel extends MultiTopicNTWidgetModel {
  @override
  String type = SwerveDriveWidget.widgetType;

  String get measuredStatesTopic => '$topic/states/current';
  String get desiredStatesTopic => '$topic/states/desired';
  String get rotationTopic => '$topic/rotation';
  String get maxModuleVelocityTopic => '$topic/maxModuleVelocity';

  late NT4Subscription measuredStatesSubscription;
  late NT4Subscription desiredStatesSubscription;
  late NT4Subscription rotationSubscription;
  late NT4Subscription maxModuleVelocitySubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    measuredStatesSubscription,
    desiredStatesSubscription,
    rotationSubscription,
    maxModuleVelocitySubscription,
  ];

  bool _showRobotRotation = true;
  bool _showDesiredStates = true;
  double _angleOffset = 0; // Modifiable angle offset to allow all kinds of swerve libraries setups

  bool get showRobotRotation => _showRobotRotation;

  set showRobotRotation(bool value) {
    _showRobotRotation = value;
    refresh();
  }

  bool get showDesiredStates => _showDesiredStates;

  set showDesiredStates(bool value) {
    _showDesiredStates = value;
    refresh();
  }

  double get angleOffset => _angleOffset;

  set angleOffset(double value) {
    _angleOffset = value;
    refresh();
  }

  SwerveDriveWidgetModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    this._showRobotRotation = true,
    this._showDesiredStates = true,
    this._angleOffset = 0.0,
    super.period,
  }) : super();

  SwerveDriveWidgetModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _showRobotRotation = tryCast(jsonData['show_robot_rotation']) ?? true;
    _showDesiredStates = tryCast(jsonData['show_desired_states']) ?? true;
    _angleOffset = tryCast(jsonData['angle_offset']) ?? 0.0;
  }

  @override
  void initializeSubscriptions() {
    measuredStatesSubscription = ntConnection.subscribe(
      measuredStatesTopic,
      super.period,
    );
    desiredStatesSubscription = ntConnection.subscribe(
      desiredStatesTopic,
      super.period,
    );
    rotationSubscription = ntConnection.subscribe(rotationTopic, super.period);
    maxModuleVelocitySubscription = ntConnection.subscribe(
      maxModuleVelocityTopic,
      super.period,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'show_robot_rotation': _showRobotRotation,
    'show_desired_states': _showDesiredStates,
    'angle_offset': _angleOffset,
  };

  static List<SwerveModuleStateStruct> moduleStatesFromValue(Object? value) {
    List<Object?> raw = tryCast(value) ?? [];
    return SwerveModuleStateStruct.listFromBytes(
      Uint8List.fromList(raw.whereType<int>().toList()),
    );
  }

  static double rotationFromValue(Object? value) {
    List<Object?> raw = tryCast(value) ?? [];
    Uint8List rawBytes = Uint8List.fromList(raw.whereType<int>().toList());

    ByteData view = ByteData.view(rawBytes.buffer);

    if (rawBytes.length < 8) {
      return 0;
    }

    return view.getFloat64(0, Endian.little);
  }

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    Row(
      children: [
        Flexible(
          child: DialogToggleSwitch(
            initialValue: _showRobotRotation,
            label: 'Show Robot Rotation',
            onToggle: (value) {
              showRobotRotation = value;
            },
          ),
        ),
        Flexible(
          child: DialogToggleSwitch(
            initialValue: _showDesiredStates,
            label: 'Show Desired States',
            onToggle: (value) {
              showDesiredStates = value;
            },
          ),
        ),
      ],
    ),
    const SizedBox(height: 5),
    Row(
      children: [
        Flexible(
          child: DialogTextInput(
            initialText: angleOffset.toString(),
            label: 'Angle Offset (Degrees)',
            onSubmit: (String value) {
              double? doubleValue = double.tryParse(value);

              if (doubleValue != null) {
                angleOffset = doubleValue;
              }
            },
            formatter: TextFormatterBuilder.decimalTextFormatter(
              allowNegative: true,
            ),
          ),
        ),
      ],
    ),
  ];
}

class SwerveDriveWidget extends NTWidget {
  static const String widgetType = 'SwerveDrive';

  const SwerveDriveWidget({super.key});

  @override
  Widget build(BuildContext context) {
    SwerveDriveWidgetModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge(model.subscriptions),
      builder: (context, snapshot) {
        List<SwerveModuleStateStruct> measuredStates =
            SwerveDriveWidgetModel.moduleStatesFromValue(
              model.measuredStatesSubscription.value,
            );
        List<SwerveModuleStateStruct> desiredStates =
            SwerveDriveWidgetModel.moduleStatesFromValue(
              model.desiredStatesSubscription.value,
            );

        double rotation = SwerveDriveWidgetModel.rotationFromValue(
          model.rotationSubscription.value,
        );
        double robotAngle = rotation - radians(model.angleOffset);

        double maxSpeed =
            tryCast(model.maxModuleVelocitySubscription.value) ?? 4.5;

        if (maxSpeed <= 0.0) {
          maxSpeed = 4.5;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            double sideLength =
                min(constraints.maxWidth, constraints.maxHeight) * 0.9;
            return Transform.rotate(
              angle: (model.showRobotRotation) ? -robotAngle : 0.0,
              child: SizedBox(
                width: sideLength,
                height: sideLength,
                child: CustomPaint(
                  painter: SwerveDrivePainter(
                    maxSpeed: maxSpeed,
                    moduleStates: measuredStates,
                    desiredStates: (model.showDesiredStates)
                        ? desiredStates
                        : [],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class SwerveDrivePainter extends CustomPainter {
  final List<SwerveModuleStateStruct> moduleStates;
  final List<SwerveModuleStateStruct> desiredStates;
  final double maxSpeed;

  const SwerveDrivePainter({
    required this.moduleStates,
    required this.desiredStates,
    required this.maxSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double robotFrameScale = 0.75;
    const double arrowScale = robotFrameScale * 0.45;

    drawRobotFrame(
      canvas,
      size * robotFrameScale,
      Offset(
            size.width - size.width * robotFrameScale,
            size.height - size.height * robotFrameScale,
          ) /
          2,
    );

    drawRobotDirectionArrow(
      canvas,
      size * arrowScale,
      Offset(
            size.width - size.width * arrowScale,
            size.height - size.height * arrowScale,
          ) /
          2,
    );

    if (desiredStates.length >= 4) {
      drawMotionArrows(
        canvas,
        size * robotFrameScale,
        Offset(
              size.width - size.width * robotFrameScale,
              size.height - size.height * robotFrameScale,
            ) /
            2,
        const Color.fromARGB(255, 0, 0, 255),
        frontLeft: desiredStates[0],
        frontRight: desiredStates[1],
        backLeft: desiredStates[2],
        backRight: desiredStates[3],
        drawXIfZero: false,
      );
    }

    if (moduleStates.length < 4) {
      moduleStates.addAll(
        Iterable.generate(
          4 - moduleStates.length,
          (_) => SwerveModuleStateStruct(),
        ),
      );
    }

    drawMotionArrows(
      canvas,
      size * robotFrameScale,
      Offset(
            size.width - size.width * robotFrameScale,
            size.height - size.height * robotFrameScale,
          ) /
          2,
      Colors.red,
      frontLeft: moduleStates[0],
      frontRight: moduleStates[1],
      backLeft: moduleStates[2],
      backRight: moduleStates[3],
    );
  }

  void drawRobotFrame(Canvas canvas, Size size, Offset offset) {
    final double scaleFactor = min(size.width, size.height) / 128.95 / 0.9;
    final double circleRadius = min(size.width, size.height) / 8;

    Paint framePainter = Paint()
      ..strokeWidth = 1.75 * scaleFactor
      ..color = Colors.grey
      ..style = PaintingStyle.stroke;

    // Front left circle
    canvas.drawCircle(
      Offset(circleRadius, circleRadius) + offset,
      circleRadius,
      framePainter,
    );

    // Front right circle
    canvas.drawCircle(
      Offset(size.width - circleRadius, circleRadius) + offset,
      circleRadius,
      framePainter,
    );

    // Back left circle
    canvas.drawCircle(
      Offset(circleRadius, size.height - circleRadius) + offset,
      circleRadius,
      framePainter,
    );

    // Back right circle
    canvas.drawCircle(
      Offset(
        offset.dx + size.width - circleRadius,
        offset.dy + size.height - circleRadius,
      ),
      circleRadius,
      framePainter,
    );

    // Top line
    canvas.drawLine(
      Offset(circleRadius * 2, circleRadius) + offset,
      Offset(size.width - circleRadius * 2, circleRadius) + offset,
      framePainter,
    );

    // Right line
    canvas.drawLine(
      Offset(size.width - circleRadius, circleRadius * 2) + offset,
      Offset(size.width - circleRadius, size.height - circleRadius * 2) +
          offset,
      framePainter,
    );

    // Bottom line
    canvas.drawLine(
      Offset(circleRadius * 2, size.height - circleRadius) + offset,
      Offset(size.width - circleRadius * 2, size.height - circleRadius) +
          offset,
      framePainter,
    );

    // Left line
    canvas.drawLine(
      Offset(circleRadius, circleRadius * 2) + offset,
      Offset(circleRadius, size.height - circleRadius * 2) + offset,
      framePainter,
    );
  }

  void drawMotionArrows(
    Canvas canvas,
    Size size,
    Offset offset,
    Color color, {
    SwerveModuleStateStruct frontLeft = const SwerveModuleStateStruct(),
    SwerveModuleStateStruct frontRight = const SwerveModuleStateStruct(),
    SwerveModuleStateStruct backLeft = const SwerveModuleStateStruct(),
    SwerveModuleStateStruct backRight = const SwerveModuleStateStruct(),
    bool drawXIfZero = true,
  }) {
    final double circleRadius = min(size.width, size.height) / 8;
    const double arrowAngle = 40 * pi / 180;

    final double scaleFactor = min(size.width, size.height) / 128.95 / 0.9;

    final double pixelsPerMPS = (7.0 / 1.0) * scaleFactor * (4.5 / maxSpeed);

    final double minArrowBase = 6.5 * scaleFactor;
    final double maxArrowBase = 16.0 * scaleFactor;

    Paint arrowPaint = Paint()
      ..strokeWidth = 2 * scaleFactor
      ..color = color
      ..style = PaintingStyle.stroke;

    Paint anglePaint = Paint()
      ..strokeWidth = 3.5 * scaleFactor
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Front left angle indicator thing
    Rect frontLeftWheel = Rect.fromCenter(
      center: Offset(circleRadius, circleRadius) + offset,
      width: circleRadius * 2,
      height: circleRadius * 2,
    );

    canvas.drawArc(
      frontLeftWheel,
      -(frontLeft.angle + radians(22.5)) - pi / 2,
      radians(45),
      false,
      anglePaint,
    );

    // Front left vector arrow
    double frontLeftAngle = frontLeft.angle;
    if (frontLeft.speed.abs() >= 0.05) {
      frontLeftAngle += pi / 2;
      frontLeftAngle *= -1;

      if (frontLeft.speed < 0) {
        frontLeftAngle -= pi;
      }

      double frontLeftArrowLength = frontLeft.speed.abs() * pixelsPerMPS;
      double frontLeftArrowBase = (frontLeftArrowLength / 3.0).clamp(
        minArrowBase,
        maxArrowBase,
      );

      canvas.drawLine(
        Offset(circleRadius, circleRadius) + offset,
        Offset(
              frontLeftArrowLength * cos(frontLeftAngle),
              frontLeftArrowLength * sin(frontLeftAngle),
            ) +
            Offset(circleRadius, circleRadius) +
            offset,
        arrowPaint,
      );

      drawArrowHead(
        canvas,
        Offset(circleRadius, circleRadius) / 2 + offset,
        frontLeftArrowLength * cos(frontLeftAngle) + circleRadius / 2,
        frontLeftArrowLength * sin(frontLeftAngle) + circleRadius / 2,
        frontLeftAngle,
        arrowAngle,
        frontLeftArrowBase,
        arrowPaint,
      );
    } else if (drawXIfZero) {
      // Draw an X
      drawX(
        canvas,
        Offset(circleRadius, circleRadius) + offset,
        circleRadius,
        arrowPaint,
      );
    }

    // Front right angle indicator thing
    Rect frontRightWheel = Rect.fromCenter(
      center: Offset(size.width - circleRadius, circleRadius) + offset,
      width: circleRadius * 2,
      height: circleRadius * 2,
    );

    canvas.drawArc(
      frontRightWheel,
      -(frontRight.angle + radians(22.5)) - pi / 2,
      radians(45),
      false,
      anglePaint,
    );

    // Front right vector arrow
    double frontRightAngle = frontRight.angle;
    if (frontRight.speed.abs() >= 0.05) {
      frontRightAngle += pi / 2;
      frontRightAngle *= -1;

      if (frontRight.speed < 0) {
        frontRightAngle -= pi;
      }

      double frontRightArrowLength = frontRight.speed.abs() * pixelsPerMPS;
      double frontRightArrowBase = (frontRightArrowLength / 3.0).clamp(
        minArrowBase,
        maxArrowBase,
      );

      canvas.drawLine(
        Offset(size.width - circleRadius, circleRadius) + offset,
        Offset(
              frontRightArrowLength * cos(frontRightAngle),
              frontRightArrowLength * sin(frontRightAngle),
            ) +
            Offset(size.width - circleRadius, circleRadius) +
            offset,
        arrowPaint,
      );

      drawArrowHead(
        canvas,
        Offset(size.width - circleRadius / 2, circleRadius / 2) + offset,
        frontRightArrowLength * cos(frontRightAngle) - circleRadius / 2,
        frontRightArrowLength * sin(frontRightAngle) + circleRadius / 2,
        frontRight.angle,
        arrowAngle,
        frontRightArrowBase,
        arrowPaint,
      );
    } else if (drawXIfZero) {
      // Draw an X
      drawX(
        canvas,
        Offset(size.width - circleRadius, circleRadius) + offset,
        circleRadius,
        arrowPaint,
      );
    }

    // Back left angle indicator thing
    Rect backLeftWheel = Rect.fromCenter(
      center: Offset(circleRadius, size.height - circleRadius) + offset,
      width: circleRadius * 2,
      height: circleRadius * 2,
    );

    canvas.drawArc(
      backLeftWheel,
      -(backLeft.angle + radians(22.5)) - pi / 2,
      radians(45),
      false,
      anglePaint,
    );

    // Back left vector arrow
    double backLeftAngle = backLeft.angle;
    if (backLeft.speed.abs() >= 0.05) {
      backLeftAngle += pi / 2;
      backLeftAngle *= -1;

      if (backLeft.speed < 0) {
        backLeftAngle -= pi;
      }

      double backLeftArrowLength = backLeft.speed.abs() * pixelsPerMPS;
      double backLeftArrowBase = (backLeftArrowLength / 3.0).clamp(
        minArrowBase,
        maxArrowBase,
      );

      canvas.drawLine(
        Offset(circleRadius, size.height - circleRadius) + offset,
        Offset(
              backLeftArrowLength * cos(backLeftAngle),
              backLeftArrowLength * sin(backLeftAngle),
            ) +
            Offset(circleRadius, size.height - circleRadius) +
            offset,
        arrowPaint,
      );

      drawArrowHead(
        canvas,
        Offset(circleRadius / 2, size.height - circleRadius / 2) + offset,
        backLeftArrowLength * cos(backLeftAngle) + circleRadius / 2,
        backLeftArrowLength * sin(backLeftAngle) - circleRadius / 2,
        backLeftAngle,
        arrowAngle,
        backLeftArrowBase,
        arrowPaint,
      );
    } else if (drawXIfZero) {
      // Draw an X
      drawX(
        canvas,
        Offset(circleRadius, size.height - circleRadius) + offset,
        circleRadius,
        arrowPaint,
      );
    }

    // Back right angle indicator thing
    Rect backRightWheel = Rect.fromCenter(
      center:
          Offset(size.width - circleRadius, size.height - circleRadius) +
          offset,
      width: circleRadius * 2,
      height: circleRadius * 2,
    );

    canvas.drawArc(
      backRightWheel,
      -(backRight.angle + radians(22.5)) - pi / 2,
      radians(45),
      false,
      anglePaint,
    );

    // Back right vector arrow
    double backRightAngle = backRight.angle;
    if (backRight.speed.abs() >= 0.05) {
      backRightAngle += pi / 2;
      backRightAngle *= -1;

      if (backRight.speed < 0) {
        backRightAngle -= pi;
      }

      double backRightArrowLength = backRight.speed.abs() * pixelsPerMPS;
      double backRightArrowBase = (backRightArrowLength / 3.0).clamp(
        minArrowBase,
        maxArrowBase,
      );

      canvas.drawLine(
        Offset(size.width - circleRadius, size.height - circleRadius) + offset,
        Offset(
              backRightArrowLength * cos(backRightAngle),
              backRightArrowLength * sin(backRightAngle),
            ) +
            Offset(size.width - circleRadius, size.height - circleRadius) +
            offset,
        arrowPaint,
      );

      drawArrowHead(
        canvas,
        Offset(size.width - circleRadius / 2, size.height - circleRadius / 2) +
            offset,
        backRightArrowLength * cos(backRightAngle) - circleRadius / 2,
        backRightArrowLength * sin(backRightAngle) - circleRadius / 2,
        backRightAngle,
        arrowAngle,
        backRightArrowBase,
        arrowPaint,
      );
    } else if (drawXIfZero) {
      // Draw an X
      drawX(
        canvas,
        Offset(size.width - circleRadius, size.height - circleRadius) + offset,
        circleRadius,
        arrowPaint,
      );
    }
  }

  void drawX(Canvas canvas, Offset offset, double circleRadius, Paint xPaint) {
    canvas.drawLine(
      Offset(circleRadius / 2, circleRadius / 2) * 0.75 + offset,
      -Offset(circleRadius / 2, circleRadius / 2) * 0.75 + offset,
      xPaint,
    );

    canvas.drawLine(
      -Offset(-circleRadius / 2, circleRadius / 2) * 0.75 + offset,
      Offset(-circleRadius / 2, circleRadius / 2) * 0.75 + offset,
      xPaint,
    );
  }

  void drawArrowHead(
    Canvas canvas,
    Offset center,
    double tipX,
    double tipY,
    double arrowRotation,
    double arrowAngle,
    double base,
    Paint arrowPaint,
  ) {
    Path arrowPath = Path()
      ..moveTo(
        center.dx + tipX - base * cos(arrowRotation - arrowAngle),
        center.dy + tipY - base * sin(arrowRotation - arrowAngle),
      )
      ..lineTo(center.dx + tipX, center.dy + tipY)
      ..lineTo(
        center.dx + tipX - base * cos(arrowRotation + arrowAngle),
        center.dy + tipY - base * sin(arrowRotation + arrowAngle),
      );

    canvas.drawPath(arrowPath, arrowPaint);
  }

  void drawRobotDirectionArrow(Canvas canvas, Size size, Offset offset) {
    final double scaleFactor = size.width / 58.0 / 0.9;

    const double arrowAngle = 40 * pi / 180;
    final double base = size.width * 0.45;
    const double arrowRotation = -pi / 2;
    const double tipX = 0;
    final double tipY = -size.height / 2;

    Offset center = Offset(size.width, size.height) / 2 + offset;

    Paint arrowPainter = Paint()
      ..strokeWidth = 3.5 * scaleFactor
      ..color = Colors.red
      ..style = PaintingStyle.stroke;

    Path arrowHead = Path()
      ..moveTo(
        center.dx + tipX - base * cos(arrowRotation - arrowAngle),
        center.dy + tipY - base * sin(arrowRotation - arrowAngle),
      )
      ..lineTo(center.dx + tipX, center.dy + tipY)
      ..lineTo(
        center.dx + tipX - base * cos(arrowRotation + arrowAngle),
        center.dy + tipY - base * sin(arrowRotation + arrowAngle),
      );

    canvas.drawPath(arrowHead, arrowPainter);
    canvas.drawLine(
      Offset(tipX, tipY) + center,
      Offset(tipX, -tipY) + center,
      arrowPainter,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
