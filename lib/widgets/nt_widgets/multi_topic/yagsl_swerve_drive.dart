import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' show radians;

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class YAGSLSwerveDriveModel extends MultiTopicNTWidgetModel {
  @override
  String type = YAGSLSwerveDrive.widgetType;

  String get measuredStatesTopic => '$topic/measuredStates';
  String get desiredStatesTopic => '$topic/desiredStates';
  String get robotRotationTopic => '$topic/robotRotation';
  String get maxSpeedTopic => '$topic/maxSpeed';
  String get robotWidthTopic => '$topic/sizeLeftRight';
  String get robotLengthTopic => '$topic/sizeFrontBack';
  String get rotationUnitTopic => '$topic/rotationUnit';

  NT4Subscription? measuredStatesSubscription;
  NT4Subscription? desiredStatesSubscription;
  NT4Subscription? robotRotationSubscription;
  NT4Subscription? maxSpeedSubscription;
  NT4Subscription? robotWidthSubscription;
  NT4Subscription? robotLengthSubscription;
  NT4Subscription? rotationUnitSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    ?measuredStatesSubscription,
    ?desiredStatesSubscription,
    ?robotRotationSubscription,
    ?maxSpeedSubscription,
    ?robotWidthSubscription,
    ?robotLengthSubscription,
    ?rotationUnitSubscription,
  ];

  bool _showRobotRotation = true;
  bool _showDesiredStates = true;
  double _angleOffset =
      0; // Modifiable angle offset to allow all kinds of swerve libraries setups

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

  YAGSLSwerveDriveModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    bool showRobotRotation = true,
    bool showDesiredStates = true,
    double angleOffset = 0.0,
    super.period,
  }) : _showDesiredStates = showDesiredStates,
       _showRobotRotation = showRobotRotation,
       _angleOffset = angleOffset,
       super();

  YAGSLSwerveDriveModel.fromJson({
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
    if (topic == null) {
      measuredStatesSubscription = null;
      desiredStatesSubscription = null;
      robotRotationSubscription = null;
      maxSpeedSubscription = null;
      robotWidthSubscription = null;
      robotLengthSubscription = null;
      rotationUnitSubscription = null;
      return;
    }

    measuredStatesSubscription = ntConnection.subscribe(
      measuredStatesTopic,
      super.period,
    );
    desiredStatesSubscription = ntConnection.subscribe(
      desiredStatesTopic,
      super.period,
    );
    robotRotationSubscription = ntConnection.subscribe(
      robotRotationTopic,
      super.period,
    );
    maxSpeedSubscription = ntConnection.subscribe(maxSpeedTopic, super.period);
    robotWidthSubscription = ntConnection.subscribe(
      robotWidthTopic,
      super.period,
    );
    robotLengthSubscription = ntConnection.subscribe(
      robotLengthTopic,
      super.period,
    );
    rotationUnitSubscription = ntConnection.subscribe(
      rotationUnitTopic,
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

class YAGSLSwerveDrive extends NTWidget {
  static const String widgetType = 'YAGSL Swerve Drive';

  const YAGSLSwerveDrive({super.key});

  @override
  Widget build(BuildContext context) {
    YAGSLSwerveDriveModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge(model.subscriptions),
      builder: (context, snapshot) {
        List<Object?> measuredStatesRaw =
            tryCast(model.measuredStatesSubscription?.value) ?? [];
        List<Object?> desiredStatesRaw =
            tryCast(model.desiredStatesSubscription?.value) ?? [];

        List<double> measuredStates = measuredStatesRaw
            .whereType<double>()
            .toList();
        List<double> desiredStates = desiredStatesRaw
            .whereType<double>()
            .toList();

        double width = tryCast(model.robotWidthSubscription?.value) ?? 1.0;
        double length = tryCast(model.robotLengthSubscription?.value) ?? width;

        if (width <= 0.0) {
          width = 1.0;
        }
        if (length <= 0.0) {
          length = 0.0;
        }

        double sizeRatio = min(length, width) / max(length, width);
        double lengthWidthRatio = length / width;

        String rotationUnit =
            tryCast(model.rotationUnitSubscription?.value) ?? 'radians';

        double robotAngle =
            tryCast(model.robotRotationSubscription?.value) ?? 0.0;

        if (rotationUnit == 'degrees') {
          robotAngle = radians(robotAngle);
        } else if (rotationUnit == 'rotations') {
          robotAngle *= 2 * pi;
        }

        robotAngle -= radians(model.angleOffset);

        double maxSpeed = tryCast(model.maxSpeedSubscription?.value) ?? 4.5;

        if (maxSpeed <= 0.0) {
          maxSpeed = 4.5;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            double maxSideLength =
                min(constraints.maxWidth, constraints.maxHeight) *
                0.9 *
                sizeRatio;
            return Transform.rotate(
              angle: (model.showRobotRotation) ? -robotAngle : 0.0,
              child: SizedBox(
                width: maxSideLength / lengthWidthRatio,
                height: maxSideLength * lengthWidthRatio,
                child: CustomPaint(
                  painter: SwerveDrivePainter(
                    rotationUnit: rotationUnit,
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
  final List<double> moduleStates;
  final List<double> desiredStates;
  final String rotationUnit;
  final double maxSpeed;

  const SwerveDrivePainter({
    required this.moduleStates,
    required this.desiredStates,
    required this.rotationUnit,
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

    if (desiredStates.length >= 8) {
      drawMotionArrows(
        canvas,
        size * robotFrameScale,
        Offset(
              size.width - size.width * robotFrameScale,
              size.height - size.height * robotFrameScale,
            ) /
            2,
        const Color.fromARGB(255, 0, 0, 255),
        frontLeftAngle: desiredStates[0],
        frontLeftVelocity: desiredStates[1],
        frontRightAngle: desiredStates[2],
        frontRightVelocity: desiredStates[3],
        backLeftAngle: desiredStates[4],
        backLeftVelocity: desiredStates[5],
        backRightAngle: desiredStates[6],
        backRightVelocity: desiredStates[7],
        drawXIfZero: false,
      );
    }

    if (moduleStates.length < 8) {
      moduleStates.addAll(
        Iterable.generate(8 - moduleStates.length, (_) => 0.0),
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
      frontLeftAngle: moduleStates[0],
      frontLeftVelocity: moduleStates[1],
      frontRightAngle: moduleStates[2],
      frontRightVelocity: moduleStates[3],
      backLeftAngle: moduleStates[4],
      backLeftVelocity: moduleStates[5],
      backRightAngle: moduleStates[6],
      backRightVelocity: moduleStates[7],
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
    double frontLeftAngle = 0.0,
    double frontLeftVelocity = 0.0,
    double frontRightAngle = 0.0,
    double frontRightVelocity = 0.0,
    double backLeftAngle = 0.0,
    double backLeftVelocity = 0.0,
    double backRightAngle = 0.0,
    double backRightVelocity = 0.0,
    bool drawXIfZero = true,
  }) {
    if (rotationUnit == 'degrees') {
      frontLeftAngle = radians(frontLeftAngle);
      frontRightAngle = radians(frontRightAngle);
      backLeftAngle = radians(backLeftAngle);
      backRightAngle = radians(backRightAngle);
    }
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
      -(frontLeftAngle + radians(22.5)) - pi / 2,
      radians(45),
      false,
      anglePaint,
    );

    // Front left vector arrow
    if (frontLeftVelocity.abs() >= 0.05) {
      frontLeftAngle += pi / 2;
      frontLeftAngle *= -1;

      if (frontLeftVelocity < 0) {
        frontLeftAngle -= pi;
      }

      double frontLeftArrowLength = frontLeftVelocity.abs() * pixelsPerMPS;
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
      -(frontRightAngle + radians(22.5)) - pi / 2,
      radians(45),
      false,
      anglePaint,
    );

    // Front right vector arrow
    if (frontRightVelocity.abs() >= 0.05) {
      frontRightAngle += pi / 2;
      frontRightAngle *= -1;

      if (frontRightVelocity < 0) {
        frontRightAngle -= pi;
      }

      double frontRightArrowLength = frontRightVelocity.abs() * pixelsPerMPS;
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
        frontRightAngle,
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
      -(backLeftAngle + radians(22.5)) - pi / 2,
      radians(45),
      false,
      anglePaint,
    );

    // Back left vector arrow
    if (backLeftVelocity.abs() >= 0.05) {
      backLeftAngle += pi / 2;
      backLeftAngle *= -1;

      if (backLeftVelocity < 0) {
        backLeftAngle -= pi;
      }

      double backLeftArrowLength = backLeftVelocity.abs() * pixelsPerMPS;
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
      -(backRightAngle + radians(22.5)) - pi / 2,
      radians(45),
      false,
      anglePaint,
    );

    // Back right vector arrow
    if (backRightVelocity.abs() >= 0.05) {
      backRightAngle += pi / 2;
      backRightAngle *= -1;

      if (backRightVelocity < 0) {
        backRightAngle -= pi;
      }

      double backRightArrowLength = backRightVelocity.abs() * pixelsPerMPS;
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
