import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' show radians;

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/util/test_utils.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/field_widget/field_widget_model.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

extension _SizeUtils on Size {
  Offset get toOffset => Offset(width, height);

  Size rotateBy(double angle) => Size(
    (width * cos(angle) - height * sin(angle)).abs(),
    (height * cos(angle) + width * sin(angle)).abs(),
  );
}

class FieldWidget extends NTWidget {
  static const String widgetType = 'Field';

  const FieldWidget({super.key});

  Widget _getTransformedFieldObject(
    FieldWidgetModel model, {
    required FieldObject object,
    required Offset fieldCenter,
    required double scaleReduction,
    Size? objectSize,
  }) {
    final double x = (object.x.isFinite && !object.x.isNaN) ? object.x : 0;
    final double y = (object.y.isFinite && !object.y.isNaN) ? object.y : 0;
    final double angleRadians = (object.angle.isFinite && !object.angle.isNaN)
        ? object.angle
        : 0;

    double xFromCenter =
        (x * model.field.pixelsPerMeterHorizontal - fieldCenter.dx) *
        scaleReduction;

    double yFromCenter =
        (fieldCenter.dy - (y * model.field.pixelsPerMeterVertical)) *
        scaleReduction;

    double width =
        (objectSize?.width ?? model.otherObjectSize) *
        model.field.pixelsPerMeterHorizontal *
        scaleReduction;

    double length =
        (objectSize?.height ?? model.otherObjectSize) *
        model.field.pixelsPerMeterVertical *
        scaleReduction;

    Matrix4 transform = Matrix4.translationValues(xFromCenter, yFromCenter, 0.0)
      ..rotateZ(-angleRadians);

    Widget otherObject = Container(
      alignment: Alignment.center,
      constraints: const BoxConstraints(minWidth: 4.0, minHeight: 4.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(
          color: model.robotColor,
          width: 0.125 * min(width, length),
        ),
      ),
      width: length,
      height: width,
      child: CustomPaint(
        size: Size(length * 0.275, width * 0.275),
        painter: TrianglePainter(strokeWidth: 0.08 * min(width, length)),
      ),
    );

    return Transform(
      origin: Offset(length, width) / 2,
      transform: transform,
      child: otherObject,
    );
  }

  Offset _getTrajectoryPointOffset(
    FieldWidgetModel model, {
    required double x,
    required double y,
    required Offset fieldCenter,
    required double scaleReduction,
  }) {
    if (!x.isFinite) {
      x = 0;
    }
    if (!y.isFinite) {
      y = 0;
    }
    double xFromCenter =
        (x * model.field.pixelsPerMeterHorizontal - fieldCenter.dx) *
        scaleReduction;

    double yFromCenter =
        (fieldCenter.dy - (y * model.field.pixelsPerMeterVertical)) *
        scaleReduction;

    return Offset(xFromCenter, yFromCenter);
  }

  List<List<Offset>> _getTrajectoryPoints({
    required FieldWidgetModel model,
    required Offset fieldCenter,
    required double scaleReduction,
  }) {
    if (!model.showTrajectories) return [];

    List<List<Offset>> trajectoryPoints = [];

    final trajectories = model.getAllObjects().where(
      (e) => e.type == FieldObjectType.trajectory,
    );

    for (final trajectory in trajectories) {
      trajectoryPoints.add(
        trajectory.poses!
            .map(
              (e) => _getTrajectoryPointOffset(
                model,
                x: e.x,
                y: e.y,
                fieldCenter: fieldCenter,
                scaleReduction: scaleReduction,
              ),
            )
            .toList(),
      );
    }

    return trajectoryPoints;
  }

  List<Widget> _getOtherObjectWidgets({
    required FieldWidgetModel model,
    required Offset fieldCenter,
    required double scaleReduction,
  }) {
    if (!model.showOtherObjects) return [];

    List<Widget> otherObjectsWidgets = [];

    final otherObjects = model.getAllObjects().where(
      (e) => e.type == FieldObjectType.otherObject,
    );

    for (final object in otherObjects) {
      otherObjectsWidgets.add(
        _getTransformedFieldObject(
          model,
          object: object,
          fieldCenter: fieldCenter,
          scaleReduction: scaleReduction,
        ),
      );
    }

    return otherObjectsWidgets;
  }

  Widget _buildRobotOverlay({
    required FieldWidgetModel model,
    required Size size,
    required double scaleReduction,
    required Offset fieldCenter,
    required double rotatedScaleReduction,
    required BoxConstraints constraints,
    required FittedSizes fittedSizes,
    required Offset fittedCenter,
    required TransformationController controller,
  }) {
    final FieldObject robotObject = model.getRobotObject();

    Widget robot = _getTransformedFieldObject(
      model,
      object: robotObject,
      fieldCenter: fieldCenter,
      scaleReduction: scaleReduction,
      objectSize: Size(
        model.robotWidthMeters,
        model.robotLengthMeters,
      ),
    );

    Matrix4 innerTransform = Matrix4.identity()
      ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
      ..scaleByDouble(
        rotatedScaleReduction / scaleReduction,
        rotatedScaleReduction / scaleReduction,
        rotatedScaleReduction / scaleReduction,
        1,
      )
      ..rotateZ(radians(model.fieldRotation))
      ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1);

    final Matrix4 totalTransform = controller.value * innerTransform;

    double xFromCenter =
        (robotObject.x * model.field.pixelsPerMeterHorizontal -
            fieldCenter.dx) *
        scaleReduction;

    double yFromCenter =
        (fieldCenter.dy -
            (robotObject.y * model.field.pixelsPerMeterVertical)) *
        scaleReduction;

    Offset robotInStack =
        size.center(Offset.zero) + Offset(xFromCenter, yFromCenter);

    Offset robotInViewport = MatrixUtils.transformPoint(
      totalTransform,
      robotInStack,
    );

    Widget? indicator;
    if (robotInViewport.dx < 0 ||
        robotInViewport.dx > size.width ||
        robotInViewport.dy < 0 ||
        robotInViewport.dy > size.height) {
      Offset snappedViewport = Offset(
        robotInViewport.dx.clamp(0, size.width),
        robotInViewport.dy.clamp(0, size.height),
      );

      Offset snappedInStack = MatrixUtils.transformPoint(
        Matrix4.inverted(totalTransform),
        snappedViewport,
      );

      Offset indicatorPosition = snappedInStack - size.center(Offset.zero);

      indicator = Transform.translate(
        offset: indicatorPosition,
        child: Container(
          width:
              model.robotWidthMeters *
              model.field.pixelsPerMeterHorizontal *
              scaleReduction /
              totalTransform.getMaxScaleOnAxis(),
          height:
              model.robotLengthMeters *
              model.field.pixelsPerMeterVertical *
              scaleReduction /
              totalTransform.getMaxScaleOnAxis(),
          decoration: BoxDecoration(
            color: model.robotColor,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      );
    }

    return Transform.scale(
      scale: rotatedScaleReduction / scaleReduction,
      child: Transform.rotate(
        angle: radians(model.fieldRotation),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: constraints.maxHeight,
              width: constraints.maxWidth,
            ),
            if (indicator == null || model.showRobotOutsideWidget)
              robot
            else
              indicator,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    FieldWidgetModel model = cast(context.watch<NTWidgetModel>());

    List<NT4Subscription> listeners = [];
    listeners.add(model.robotSubscription);
    if (model.showOtherObjects || model.showTrajectories) {
      listeners.addAll(model.otherObjectSubscriptions);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        Size size = Size(constraints.maxWidth, constraints.maxHeight);
        FittedSizes fittedSizes = applyBoxFit(
          BoxFit.contain,
          model.field.fieldImageSize ?? const Size(0, 0),
          size,
        );
        FittedSizes rotatedFittedSizes = applyBoxFit(
          BoxFit.contain,
          model.field.fieldImageSize?.rotateBy(
                -radians(model.fieldRotation),
              ) ??
              const Size(0, 0),
          size,
        );
        double scaleReduction =
            (fittedSizes.destination.width / fittedSizes.source.width);
        double rotatedScaleReduction =
            (rotatedFittedSizes.destination.width /
            rotatedFittedSizes.source.width);

        if (scaleReduction.isNaN) {
          scaleReduction = 0;
        }
        if (rotatedScaleReduction.isNaN) {
          rotatedScaleReduction = 0;
        }

        Offset fittedCenter = fittedSizes.destination.toOffset / 2;
        Offset fieldCenter = model.field.center;

        model.widgetSize = size;

        if (!model.rendered &&
            model.widgetSize != null &&
            size != const Size(0, 0) &&
            size.width > 100.0 &&
            scaleReduction != 0.0 &&
            fieldCenter != const Offset(0.0, 0.0) &&
            model.field.fieldImageLoaded) {
          model.rendered = true;
        }

        // Try rebuilding again if the image isn't fully rendered
        // Can't do it if it's in a unit test cause it causes issues with timers running
        if (!model.rendered && !isUnitTest) {
          Future.delayed(
            const Duration(milliseconds: 100),
            model.refresh,
          );
        }

        return Stack(
          children: [
            // Pannable field widget
            InteractiveViewer(
              transformationController: model.transformController,
              constrained: true,
              maxScale: 2,
              minScale: 1,
              panAxis: PanAxis.free,
              clipBehavior: Clip.hardEdge,
              trackpadScrollCausesScale: true,
              child: ListenableBuilder(
                listenable: Listenable.merge(listeners),
                builder: (context, child) {
                  List<List<Offset>> trajectoryPoints = _getTrajectoryPoints(
                    model: model,
                    fieldCenter: fieldCenter,
                    scaleReduction: scaleReduction,
                  );

                  List<Widget> otherObjects = _getOtherObjectWidgets(
                    model: model,
                    fieldCenter: fieldCenter,
                    scaleReduction: scaleReduction,
                  );

                  return Transform.scale(
                    scale: rotatedScaleReduction / scaleReduction,
                    child: Transform.rotate(
                      angle: radians(model.fieldRotation),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: constraints.maxHeight,
                            width: constraints.maxWidth,
                            child: model.field.fieldImage,
                          ),
                          for (List<Offset> points in trajectoryPoints)
                            CustomPaint(
                              size: fittedSizes.destination,
                              painter: TrajectoryPainter(
                                center: fittedCenter,
                                color: model.trajectoryColor,
                                points: points,
                                strokeWidth:
                                    model.trajectoryPointSize *
                                    model.field.pixelsPerMeterHorizontal *
                                    scaleReduction,
                              ),
                            ),
                          ...otherObjects,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Robot, trajectories overlay
            IgnorePointer(
              ignoring: true,
              child: InteractiveViewer(
                transformationController: model.transformController,
                clipBehavior: Clip.none,
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    ...listeners,
                    model.transformController,
                  ]),
                  builder: (context, child) => _buildRobotOverlay(
                    model: model,
                    size: size,
                    scaleReduction: scaleReduction,
                    fieldCenter: fieldCenter,
                    rotatedScaleReduction: rotatedScaleReduction,
                    constraints: constraints,
                    fittedSizes: fittedSizes,
                    fittedCenter: fittedCenter,
                    controller: model.transformController,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
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
