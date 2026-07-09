import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class DifferentialDriveModel extends MultiTopicNTWidgetModel {
  @override
  String type = DifferentialDrive.widgetType;

  String get leftSpeedTopicName => '$topic/Left Motor Speed';
  String get rightSpeedTopicName => '$topic/Right Motor Speed';

  NT4Subscription? leftSpeedSubscription;
  NT4Subscription? rightSpeedSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    ?leftSpeedSubscription,
    ?rightSpeedSubscription,
  ];

  NT4Topic? leftSpeedTopic;
  NT4Topic? rightSpeedTopic;

  double leftSpeedPreviousValue = 0.0;
  double rightSpeedPreviousValue = 0.0;

  ValueNotifier<double> leftSpeedCurrentValue = ValueNotifier<double>(0.0);
  ValueNotifier<double> rightSpeedCurrentValue = ValueNotifier<double>(0.0);

  DifferentialDriveModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
  }) : super();

  DifferentialDriveModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    if (topic == null) {
      leftSpeedSubscription = null;
      rightSpeedSubscription = null;
      return;
    }
    leftSpeedSubscription = ntConnection.subscribe(
      leftSpeedTopicName,
      super.period,
    );
    rightSpeedSubscription = ntConnection.subscribe(
      rightSpeedTopicName,
      super.period,
    );
  }

  @override
  void resetSubscription() {
    leftSpeedTopic = null;
    rightSpeedTopic = null;

    leftSpeedPreviousValue = 0.0;
    leftSpeedCurrentValue.value = 0.0;

    rightSpeedPreviousValue = 0.0;
    rightSpeedCurrentValue.value = 0.0;

    super.resetSubscription();
  }
}

class DifferentialDrive extends NTWidget {
  static const String widgetType = 'DifferentialDrive';

  const DifferentialDrive({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    DifferentialDriveModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge([
        ...model.subscriptions,
        model.leftSpeedCurrentValue,
        model.rightSpeedCurrentValue,
      ]),
      builder: (context, child) {
        double leftSpeed = tryCast(model.leftSpeedSubscription?.value) ?? 0.0;
        double rightSpeed = tryCast(model.rightSpeedSubscription?.value) ?? 0.0;

        if (leftSpeed != model.leftSpeedPreviousValue) {
          model.leftSpeedCurrentValue.value = leftSpeed;
        }
        model.leftSpeedPreviousValue = leftSpeed;

        if (rightSpeed != model.rightSpeedPreviousValue) {
          model.rightSpeedCurrentValue.value = rightSpeed;
        }
        model.rightSpeedPreviousValue = rightSpeed;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left speed gauge
            LinearGauge(
              rulers: RulerStyle(
                rulerPosition: RulerPosition.right,
                showLabel: true,
                textStyle: Theme.of(context).textTheme.bodySmall,
                primaryRulerColor: Colors.grey,
                secondaryRulerColor: Colors.grey,
                labelOffset: 5,
              ),
              extendLinearGauge: 1,
              linearGaugeBoxDecoration: const LinearGaugeBoxDecoration(
                backgroundColor: Color.fromRGBO(87, 87, 87, 1),
                thickness: 7.5,
                borderRadius: 10,
              ),
              pointers: [
                Pointer(
                  key: UniqueKey(),
                  enableAnimation: false,
                  value: model.leftSpeedCurrentValue.value.clamp(-1.0, 1.0),
                  shape: PointerShape.triangle,
                  color: Theme.of(context).colorScheme.primary,
                  pointerPosition: PointerPosition.left,
                  width: 12.5,
                  height: 12.5,
                  isInteractive: true,
                  onChanged: (value) {
                    model.leftSpeedCurrentValue.value = value;
                  },
                  onChangeEnd: () {
                    bool publishTopic = model.leftSpeedTopic == null;

                    model.leftSpeedTopic ??= model.ntConnection
                        .getTopicFromName(model.leftSpeedTopicName);

                    if (model.leftSpeedTopic == null) {
                      return;
                    }

                    if (publishTopic) {
                      model.ntConnection.publishTopic(model.leftSpeedTopic!);
                    }

                    model.ntConnection.updateDataFromTopic(
                      model.leftSpeedTopic!,
                      model.leftSpeedCurrentValue,
                    );

                    model.leftSpeedPreviousValue =
                        model.leftSpeedCurrentValue.value;
                  },
                ),
              ],
              gaugeOrientation: GaugeOrientation.vertical,
              start: -1.0,
              end: 1.0,
              steps: 0.5,
              enableGaugeAnimation: false,
            ),
            const SizedBox(width: 15),
            // Robot
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double sideLength = min(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );

                  return SizedBox(
                    width: sideLength,
                    height: sideLength,
                    child: CustomPaint(
                      painter: _DifferentialDrivePainter(
                        leftSpeed: model.leftSpeedCurrentValue.value.clamp(
                          -1.0,
                          1.0,
                        ),
                        rightSpeed: model.rightSpeedCurrentValue.value.clamp(
                          -1.0,
                          1.0,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 15),
            // Right speed gauge
            LinearGauge(
              rulers: RulerStyle(
                rulerPosition: RulerPosition.left,
                showLabel: true,
                textStyle: Theme.of(context).textTheme.bodySmall,
                primaryRulerColor: Colors.grey,
                secondaryRulerColor: Colors.grey,
                labelOffset: 5,
              ),
              extendLinearGauge: 1,
              linearGaugeBoxDecoration: const LinearGaugeBoxDecoration(
                backgroundColor: Color.fromRGBO(87, 87, 87, 1),
                thickness: 7.5,
                borderRadius: 10,
              ),
              pointers: [
                Pointer(
                  key: UniqueKey(),
                  enableAnimation: false,
                  value: model.rightSpeedCurrentValue.value.clamp(-1.0, 1.0),
                  shape: PointerShape.triangle,
                  color: Theme.of(context).colorScheme.primary,
                  pointerPosition: PointerPosition.right,
                  width: 12.5,
                  height: 12.5,
                  isInteractive: true,
                  onChanged: (value) {
                    model.rightSpeedCurrentValue.value = value;
                  },
                  onChangeEnd: () {
                    bool publishTopic = model.rightSpeedTopic == null;

                    model.rightSpeedTopic ??= model.ntConnection
                        .getTopicFromName(model.rightSpeedTopicName);

                    if (model.rightSpeedTopic == null) {
                      return;
                    }

                    if (publishTopic) {
                      model.ntConnection.publishTopic(model.rightSpeedTopic!);
                    }

                    model.ntConnection.updateDataFromTopic(
                      model.rightSpeedTopic!,
                      model.rightSpeedCurrentValue,
                    );

                    model.rightSpeedPreviousValue =
                        model.rightSpeedCurrentValue.value;
                  },
                ),
              ],
              gaugeOrientation: GaugeOrientation.vertical,
              start: -1.0,
              end: 1.0,
              steps: 0.5,
              enableGaugeAnimation: false,
            ),
          ],
        );
      },
    );
  }
}

class _DifferentialDrivePainter extends CustomPainter {
  final double leftSpeed;
  final double rightSpeed;

  _DifferentialDrivePainter({
    required this.leftSpeed,
    required this.rightSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawRobotFrame(canvas, size);
    _drawMotionVector(
      canvas,
      size * 7 / 8,
      Offset(size.width / 2, size.height / 2),
    );
  }

  void _drawRobotFrame(Canvas canvas, Size size) {
    final double scaleFactor = size.width / 108.15;

    Paint outlinePainter = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2 * scaleFactor
      ..style = PaintingStyle.stroke;

    double wheelWidth = size.width / 8;
    double wheelHeight = size.height / 3.25;

    Rect frontLeftWheel = Rect.fromCenter(
      center: Offset(wheelWidth / 2, wheelHeight / 2),
      width: wheelWidth,
      height: wheelHeight,
    );

    Rect frontRightWheel = Rect.fromCenter(
      center: Offset(size.width - wheelWidth / 2, wheelHeight / 2),
      width: wheelWidth,
      height: wheelHeight,
    );

    Rect backLeftWheel = Rect.fromCenter(
      center: Offset(wheelWidth / 2, size.height - wheelHeight / 2),
      width: wheelWidth,
      height: wheelHeight,
    );

    Rect backRightWheel = Rect.fromCenter(
      center: Offset(
        size.width - wheelWidth / 2,
        size.height - wheelHeight / 2,
      ),
      width: wheelWidth,
      height: wheelHeight,
    );

    Rect body = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width - wheelWidth * 2,
      height: size.height,
    );

    canvas.drawRect(frontLeftWheel, outlinePainter);
    canvas.drawRect(frontRightWheel, outlinePainter);
    canvas.drawRect(backLeftWheel, outlinePainter);
    canvas.drawRect(backRightWheel, outlinePainter);
    canvas.drawRect(body, outlinePainter);
  }

  void _drawMotionVector(Canvas canvas, Size size, Offset center) {
    final double scaleFactor = size.width / 94.6;

    Paint vectorArc = Paint()
      ..color = Colors.red
      ..strokeWidth = 2 * scaleFactor
      ..style = PaintingStyle.stroke;

    final double forwardSpeed = (leftSpeed + rightSpeed) / 2;
    final double turnSpeed = (leftSpeed - rightSpeed) / 2;

    // Math calculations taken from WPILib's Shuffleboard
    if (forwardSpeed.abs() < 0.05 && turnSpeed.abs() < 0.05) {
      // Draw an X since the robot isn't really moving
      Size xSize = size / 3;

      Path xPath = Path()
        ..moveTo(center.dx, center.dy)
        ..relativeMoveTo(-xSize.width / 2, -xSize.height / 2)
        ..relativeLineTo(xSize.width, xSize.height)
        ..relativeMoveTo(0, -xSize.height)
        ..relativeLineTo(-xSize.width, xSize.height);

      canvas.drawPath(xPath, vectorArc);
      return;
    }

    const double arrowSize = 16.0;
    const double arrowAngle = 40 * pi / 180;
    final double maxRadius = min(size.width, size.height) / 2 - arrowSize;

    final double moment = (rightSpeed - leftSpeed) / 2;
    final double avgSpeed = (leftSpeed + rightSpeed) / 2;
    final double turnRadius = avgSpeed / moment;

    // Mostly forward/backward with a bit of turn
    if (turnRadius.abs() >= 1) {
      final double arcSign = -(turnRadius.sign);
      double radius = (turnRadius * maxRadius).abs();

      final double forwardSpeedSign = forwardSpeed.sign;

      double vectorX = forwardSpeedSign * turnSpeed * maxRadius;
      double vectorY = -forwardSpeed * maxRadius;

      if (vectorX.abs() > maxRadius || vectorY.abs() > maxRadius) {
        double vectorMax = max(vectorX.abs(), vectorY.abs());

        vectorX /= vectorMax;
        vectorY /= vectorMax;

        vectorX *= maxRadius;
        vectorY *= maxRadius;
      }

      Path vectorPath = Path()
        ..moveTo(center.dx, center.dy)
        ..relativeArcToPoint(
          Offset(vectorX, vectorY),
          radius: (radius != double.infinity)
              ? Radius.circular(radius)
              : Radius.zero,
          clockwise: arcSign * forwardSpeedSign == 1,
        );

      canvas.drawPath(vectorPath, vectorArc);

      // Draw curved arrow
      final double arcLength = sqrt(vectorX * vectorX + vectorY * vectorY);

      final double arrowScaleFactor =
          (7.50 * arcLength / maxRadius).clamp(0.0, 1.1) * scaleFactor;

      final double base = arrowScaleFactor * arrowSize / 2;

      final double arrowRotation =
          atan2(vectorY, vectorX) +
          forwardSpeedSign * arcSign * arcLength / radius;

      drawArrowHead(
        canvas,
        center,
        vectorX,
        vectorY,
        arrowRotation,
        arrowAngle,
        base,
      );
    } else {
      final double turnSign = (leftSpeed - rightSpeed).sign;

      // Turning from the center of the robot
      if (turnRadius == 0) {
        double radius = max(leftSpeed, rightSpeed) * maxRadius;
        double angle = turnSign * pi;
        double startAngle = (moment < 0) ? pi : 0;

        Rect arcOval = Rect.fromCenter(
          center: center,
          width: radius,
          height: radius,
        );

        canvas.drawArc(arcOval, startAngle, angle, false, vectorArc);

        final double arrowScaleFactor =
            (2.0 * angle.abs() * radius / maxRadius).clamp(0.75, 1.1) *
            scaleFactor;

        final double base = arrowScaleFactor * arrowSize / 2;

        const double arrowRotation = pi / 2;

        drawArrowHead(
          canvas,
          center,
          turnSign * radius / 2,
          0,
          arrowRotation,
          arrowAngle,
          base,
        );
      } else {
        // Turning from inside the robot
        double dominant = turnRadius < 0 ? leftSpeed : rightSpeed;
        double secondary = turnRadius < 0 ? rightSpeed : leftSpeed;
        double radius = dominant.abs() * maxRadius;
        double angle = turnSign * _map(secondary / dominant, 0, -1, 0.5, pi);
        double startAngle = turnRadius < 0 ? pi : 0;

        Rect arcOval = Rect.fromCenter(
          center: center,
          width: radius,
          height: radius,
        );

        canvas.drawArc(arcOval, startAngle, angle, false, vectorArc);

        final double arrowScaleFactor =
            (2.0 * angle.abs() * radius / maxRadius).clamp(0.75, 1.1) *
            scaleFactor;

        final double base = arrowScaleFactor * arrowSize / 2;

        double tipX = 0.5 * radius * cos(angle + startAngle);
        double tipY = 0.5 * radius * sin(angle + startAngle);

        double arrowRotation = angle + startAngle + (pi / 2) * turnSign;

        drawArrowHead(
          canvas,
          center,
          tipX,
          tipY,
          arrowRotation,
          arrowAngle,
          base,
        );
      }
    }
  }

  void drawArrowHead(
    Canvas canvas,
    Offset center,
    double tipX,
    double tipY,
    double arrowRotation,
    double arrowAngle,
    double base,
  ) {
    Paint arrowHead = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;

    double triangleHeight = base / (2 * tan(arrowAngle / 2));

    double xOffset = cos(arrowRotation) * triangleHeight / 2;
    double yOffset = sin(arrowRotation) * triangleHeight / 2;

    Path arrowPath = Path()
      ..moveTo(
        center.dx + tipX + xOffset - base * cos(arrowRotation - arrowAngle),
        center.dy + tipY + yOffset - base * sin(arrowRotation - arrowAngle),
      )
      ..lineTo(center.dx + tipX + xOffset, center.dy + tipY + yOffset)
      ..lineTo(
        center.dx + tipX + xOffset - base * cos(arrowRotation + arrowAngle),
        center.dy + tipY + yOffset - base * sin(arrowRotation + arrowAngle),
      )
      ..close();

    canvas.drawPath(arrowPath, arrowHead);
  }

  double _map(
    double x,
    double minInput,
    double maxInput,
    double minOutput,
    double maxOutput,
  ) =>
      (x - minInput) * (maxOutput - minOutput) / (maxInput - minInput) +
      minOutput;

  @override
  bool shouldRepaint(_DifferentialDrivePainter oldDelegate) =>
      oldDelegate.leftSpeed != leftSpeed ||
      oldDelegate.rightSpeed != rightSpeed;
}
