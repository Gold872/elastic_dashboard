import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/struct_schemas/pose2d_struct.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show radians;

class RobotPainter extends CustomPainter {
  final Offset center;
  final Field field;
  final Offset robotPose;
  final double robotAngle;
  final Size robotSize;
  final Color robotColor;
  final ui.Image? robotImage;
  final double scale;

  RobotPainter({
    required this.center,
    required this.field,
    required this.robotPose,
    required this.robotAngle,
    required this.robotSize,
    required this.robotColor,
    required this.robotImage,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double x = robotPose.dx;
    double y = robotPose.dy;
    double angle = robotAngle;

    if (!x.isFinite || x.isNaN) x = 0;
    if (!y.isFinite || y.isNaN) y = 0;
    if (!angle.isFinite || angle.isNaN) angle = 0;

    double xFromCenter =
        (x * field.pixelsPerMeterHorizontal - field.center.dx) * scale;
    double yFromCenter =
        (field.center.dy - (y * field.pixelsPerMeterVertical)) * scale;

    double width = robotSize.width * field.pixelsPerMeterHorizontal * scale;
    double length = robotSize.height * field.pixelsPerMeterVertical * scale;

    canvas.save();
    canvas.translate(center.dx + xFromCenter, center.dy + yFromCenter);
    canvas.rotate(-angle);

    if (robotImage != null) {
      final ui.Rect outputRect = Rect.fromCenter(
        center: Offset.zero,
        width: length,
        height: width,
      );
      final Size imageSize = Size(
        robotImage!.width.toDouble(),
        robotImage!.height.toDouble(),
      );
      final FittedSizes fittedSizes = applyBoxFit(
        BoxFit.cover,
        imageSize,
        outputRect.size,
      );
      final Rect sourceRect = Alignment.center.inscribe(
        fittedSizes.source,
        Offset.zero & imageSize,
      );
      canvas.drawImageRect(robotImage!, sourceRect, outputRect, Paint());
    } else {
      // Fallback to drawing a shape if no image is provided
      final Paint paint = Paint()
        ..color = robotColor
        ..style = PaintingStyle.fill;
      final Rect robotRect = Rect.fromCenter(
        center: Offset.zero,
        width: length,
        height: width,
      );
      canvas.drawRect(robotRect, paint);

      // Draw a triangle for heading
      final Paint trianglePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final Path trianglePath = Path()
        ..moveTo(length / 2, 0)
        ..lineTo(length / 4, -width / 4)
        ..lineTo(length / 4, width / 4)
        ..close();
      canvas.drawPath(trianglePath, trianglePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RobotPainter oldDelegate) =>
      oldDelegate.robotPose != robotPose ||
      oldDelegate.robotAngle != robotAngle ||
      oldDelegate.robotSize != robotSize ||
      oldDelegate.robotColor != robotColor ||
      oldDelegate.robotImage != robotImage ||
      oldDelegate.scale != scale;
}

class VisionPainter extends CustomPainter {
  final Offset center;
  final Field field;
  final List<Offset> poses;
  final List<List<bool>> statuses;
  final Color color;
  final double markerSize;
  final double scale;

  VisionPainter({
    required this.center,
    required this.field,
    required this.poses,
    required this.statuses,
    required this.color,
    required this.markerSize,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < poses.length; i++) {
      final Offset pose = poses[i];
      final bool locationAligned = statuses[i][0];
      final bool headingAligned = statuses[i][1];

      double xFromCenter =
          (pose.dx * field.pixelsPerMeterHorizontal - field.center.dx) * scale;
      double yFromCenter =
          (field.center.dy - (pose.dy * field.pixelsPerMeterVertical)) * scale;

      final Offset markerCenter = Offset(
        center.dx + xFromCenter,
        center.dy + yFromCenter,
      );

      if (locationAligned) {
        if (headingAligned) {
          // Triangle
          final Path trianglePath = Path()
            ..moveTo(markerCenter.dx, markerCenter.dy - markerSize / 2)
            ..lineTo(
              markerCenter.dx + markerSize / 2,
              markerCenter.dy + markerSize / 2,
            )
            ..lineTo(
              markerCenter.dx - markerSize / 2,
              markerCenter.dy + markerSize / 2,
            )
            ..close();
          canvas.drawPath(trianglePath, paint);
        } else {
          // Circle
          canvas.drawCircle(markerCenter, markerSize / 2, paint);
        }
      } else {
        // Rectangle
        final Rect rect = Rect.fromCenter(
          center: markerCenter,
          width: markerSize,
          height: markerSize,
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant VisionPainter oldDelegate) =>
      oldDelegate.poses != poses ||
      oldDelegate.statuses != statuses ||
      oldDelegate.color != color;
}

class GamePiecePainter extends CustomPainter {
  final Offset center;
  final Field field;
  final List<Offset> gamePieces;
  final Color gamePieceColor;
  final Color bestGamePieceColor;
  final double markerSize;
  final double scale;

  GamePiecePainter({
    required this.center,
    required this.field,
    required this.gamePieces,
    required this.gamePieceColor,
    required this.bestGamePieceColor,
    required this.markerSize,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < gamePieces.length; i++) {
      final Offset piece = gamePieces[i];
      final bool isBest = i == 0;

      paint.color = isBest ? bestGamePieceColor : gamePieceColor;
      paint.strokeWidth = isBest ? 5 : 2;

      double xFromCenter =
          (piece.dx * field.pixelsPerMeterHorizontal - field.center.dx) * scale;
      double yFromCenter =
          (field.center.dy - (piece.dy * field.pixelsPerMeterVertical)) * scale;

      final Offset markerCenter = Offset(
        center.dx + xFromCenter,
        center.dy + yFromCenter,
      );
      canvas.drawCircle(markerCenter, markerSize / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GamePiecePainter oldDelegate) =>
      oldDelegate.gamePieces != gamePieces ||
      oldDelegate.gamePieceColor != gamePieceColor ||
      oldDelegate.bestGamePieceColor != bestGamePieceColor;
}

class TrianglePainter extends CustomPainter {
  final Color strokeColor;
  final PaintingStyle paintingStyle;
  final double strokeWidth;

  TrianglePainter({
    this.strokeColor = Colors.white,
    this.strokeWidth = 3,
    this.paintingStyle = PaintingStyle.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..style = paintingStyle;

    canvas.drawPath(getTrianglePath(size.width, size.height), paint);
  }

  Path getTrianglePath(double x, double y) => Path()
    ..moveTo(0, 0)
    ..lineTo(x, y / 2)
    ..lineTo(0, y)
    ..lineTo(0, 0)
    ..lineTo(x, y / 2);

  @override
  bool shouldRepaint(TrianglePainter oldDelegate) =>
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.paintingStyle != paintingStyle ||
      oldDelegate.strokeWidth != strokeWidth;
}

class TrajectoryPainter extends CustomPainter {
  final Offset center;
  final List<Offset> points;
  final double strokeWidth;
  final Color color;

  TrajectoryPainter({
    required this.center,
    required this.points,
    required this.strokeWidth,
    this.color = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }
    Paint trajectoryPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    Path trajectoryPath = Path();

    trajectoryPath.moveTo(points[0].dx + center.dx, points[0].dy + center.dy);

    for (Offset point in points) {
      trajectoryPath.lineTo(point.dx + center.dx, point.dy + center.dy);
    }
    canvas.drawPath(trajectoryPath, trajectoryPaint);
  }

  @override
  bool shouldRepaint(TrajectoryPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.color != color;
}

class OtherObjectsPainter extends CustomPainter {
  final Offset center;
  final Field field;
  final List<NT4Subscription> subscriptions;
  final bool Function(String) isPoseStruct;
  final bool Function(String) isPoseArrayStruct;
  final Color robotColor;
  final double objectSize;
  final double scale;

  OtherObjectsPainter({
    required this.center,
    required this.field,
    required this.subscriptions,
    required this.isPoseStruct,
    required this.isPoseArrayStruct,
    required this.robotColor,
    required this.objectSize,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (NT4Subscription objectSubscription in subscriptions) {
      List<Object?>? objectPositionRaw = objectSubscription.value
          ?.tryCast<List<Object?>>();

      if (objectPositionRaw == null) {
        continue;
      }

      bool isTrajectory = objectSubscription.topic.toLowerCase().endsWith(
        'trajectory',
      );
      bool isStructArray = isPoseArrayStruct(objectSubscription.topic);
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
        continue;
      }

      if (isStructObject) {
        List<int> structBytes = objectPositionRaw.whereType<int>().toList();
        if (isStructArray) {
          List<Pose2dStruct> poses = Pose2dStruct.listFromBytes(
            Uint8List.fromList(structBytes),
          );
          for (Pose2dStruct pose in poses) {
            _drawObject(canvas, pose.x, pose.y, pose.angle);
          }
        } else {
          Pose2dStruct pose = Pose2dStruct.valueFromBytes(
            Uint8List.fromList(structBytes),
          );
          _drawObject(canvas, pose.x, pose.y, pose.angle);
        }
      } else {
        List<double> objectPosition = objectPositionRaw
            .whereType<double>()
            .toList();
        for (int i = 0; i < objectPosition.length - 2; i += 3) {
          _drawObject(
            canvas,
            objectPosition[i],
            objectPosition[i + 1],
            radians(objectPosition[i + 2]),
          );
        }
      }
    }
  }

  void _drawObject(Canvas canvas, double x, double y, double angle) {
    if (!x.isFinite || x.isNaN) x = 0;
    if (!y.isFinite || y.isNaN) y = 0;
    if (!angle.isFinite || angle.isNaN) angle = 0;

    double xFromCenter =
        (x * field.pixelsPerMeterHorizontal - field.center.dx) * scale;
    double yFromCenter =
        (field.center.dy - (y * field.pixelsPerMeterVertical)) * scale;

    double width = objectSize * field.pixelsPerMeterHorizontal * scale;
    double length = objectSize * field.pixelsPerMeterVertical * scale;

    canvas.save();
    canvas.translate(center.dx + xFromCenter, center.dy + yFromCenter);
    canvas.rotate(-angle);

    final Paint paint = Paint()
      ..color = robotColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final Rect rect = Rect.fromCenter(
      center: Offset.zero,
      width: length,
      height: width,
    );
    canvas.drawRect(rect, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant OtherObjectsPainter oldDelegate) =>
      oldDelegate.subscriptions != subscriptions ||
      oldDelegate.robotColor != robotColor;
}
