import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dot_cast/dot_cast.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/struct_schemas/pose2d_struct.dart';
import 'package:elastic_dashboard/util/test_utils.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/field_widget/field_model.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/field_widget/field_painters.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' show radians;

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

  @override
  Widget build(BuildContext context) {
    FieldWidgetModel model = cast(context.watch<NTWidgetModel>());

    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: Listenable.merge(model.subscriptions),
        child: model.field.fieldImage,
        builder: (context, child) {
          List<Object?> robotPositionRaw = [
            model.robotXSubscription.value,
            model.robotYSubscription.value,
            model.robotHeadingSubscription.value,
          ];

          double robotX = 0;
          double robotY = 0;
          double robotTheta = 0;

          if (model.isPoseStruct(model.robotTopicName)) {
            List<int> poseBytes = robotPositionRaw.whereType<int>().toList();
            Pose2dStruct poseStruct = Pose2dStruct.valueFromBytes(
              Uint8List.fromList(poseBytes),
            );

            robotX = poseStruct.x;
            robotY = poseStruct.y;
            robotTheta = poseStruct.angle;
          } else {
            List<double> robotPosition = robotPositionRaw
                .whereType<double>()
                .toList();

            if (robotPosition.length >= 3) {
              robotX = robotPosition[0];
              robotY = robotPosition[1];
              robotTheta = radians(robotPosition[2]);
            }
          }

          Size size = Size(constraints.maxWidth, constraints.maxHeight);

          model.widgetSize = size;

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

          Offset fittedCenter = fittedSizes.destination.toOffset / 2;
          Offset fieldCenter = model.field.center;

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

          if (!model.rendered &&
              model.widgetSize != null &&
              size != const Size(0, 0) &&
              size.width > 100.0 &&
              scaleReduction != 0.0 &&
              fieldCenter != const Offset(0.0, 0.0) &&
              model.field.fieldImageLoaded) {
            model.rendered = true;
          }

          if (!model.rendered && !isUnitTest) {
            Future.delayed(const Duration(milliseconds: 100), model.refresh);
          }

          List<List<Offset>> trajectoryPoints = [];
          if (model.showTrajectories) {
            for (NT4Subscription objectSubscription
                in model.otherObjectSubscriptions) {
              List<Object?>? objectPositionRaw = objectSubscription.value
                  ?.tryCast<List<Object?>>();

              if (objectPositionRaw == null) {
                continue;
              }

              bool isTrajectory = objectSubscription.topic
                  .toLowerCase()
                  .endsWith('trajectory');

              bool isStructArray = model.isPoseArrayStruct(
                objectSubscription.topic,
              );
              bool isStructObject =
                  model.isPoseStruct(objectSubscription.topic) || isStructArray;

              if (isStructObject) {
                isTrajectory =
                    isTrajectory ||
                    (isStructArray &&
                        objectPositionRaw.length ~/ Pose2dStruct.length > 8);
              } else {
                isTrajectory = isTrajectory || objectPositionRaw.length > 24;
              }

              if (!isTrajectory) {
                continue;
              }

              List<Offset> objectTrajectory = [];

              if (isStructObject) {
                List<int> structArrayBytes = objectPositionRaw
                    .whereType<int>()
                    .toList();
                List<Pose2dStruct> poseArray = Pose2dStruct.listFromBytes(
                  Uint8List.fromList(structArrayBytes),
                );
                for (Pose2dStruct pose in poseArray) {
                  objectTrajectory.add(
                    _getTrajectoryPointOffset(
                      model,
                      x: pose.x,
                      y: pose.y,
                      fieldCenter: fieldCenter,
                      scaleReduction: scaleReduction,
                    ),
                  );
                }
              } else {
                List<double> objectPosition = objectPositionRaw
                    .whereType<double>()
                    .toList();
                for (int i = 0; i < objectPosition.length - 2; i += 3) {
                  objectTrajectory.add(
                    _getTrajectoryPointOffset(
                      model,
                      x: objectPosition[i],
                      y: objectPosition[i + 1],
                      fieldCenter: fieldCenter,
                      scaleReduction: scaleReduction,
                    ),
                  );
                }
              }
              if (objectTrajectory.isNotEmpty) {
                trajectoryPoints.add(objectTrajectory);
              }
            }
          }

          return GestureDetector(
            onTapDown: (details) {
              if (model.ntConnection.isNT4Connected) {
                Offset tapPosition = details.localPosition;

                // 1. Translate tapPosition to be relative to fittedCenter (the center of the *unrotated* field in screen coordinates).
                double xRel = tapPosition.dx - fittedCenter.dx;
                double yRel = tapPosition.dy - fittedCenter.dy;

                // 2. Apply inverse rotation: Rotate (x_rel, y_rel) by -model.fieldRotation to get the coordinates as if the field hadn't been rotated.
                double angle = radians(model.fieldRotation);
                double xUnrotatedRel = xRel * cos(angle) + yRel * sin(angle);
                double yUnrotatedRel = -xRel * sin(angle) + yRel * cos(angle);

                // 3. Apply inverse mirroring (if any): If alliance is red, the rendering mirrors the y-axis. Undo that.
                double yUnrotatedRelMirrored = model.allianceTopic.value
                    ? -yUnrotatedRel
                    : yUnrotatedRel;

                // 4. Scale and Offset to Field Meters: Use the existing conversion logic.
                double realX =
                    xUnrotatedRel /
                        scaleReduction /
                        model.field.pixelsPerMeterHorizontal +
                    model.field.center.dx /
                        model.field.pixelsPerMeterHorizontal;
                double realY =
                    (-yUnrotatedRelMirrored /
                        scaleReduction /
                        model.field.pixelsPerMeterVertical) +
                    model.field.center.dy / model.field.pixelsPerMeterVertical;

                model.commanderTopics.set(Offset(realX, realY));
              }
            },
                        child: SizedBox(
                          width: rotatedFittedSizes.destination.width,
                          height: rotatedFittedSizes.destination.height,
                          child: Center(
                            child: Transform.rotate(
                              angle: radians(model.fieldRotation),
                              child: Transform(
                                transform: Matrix4.diagonal3Values(
                                  1,
                                  model.allianceTopic.value ? -1 : 1,
                                  1,
                                ),
                                alignment: Alignment.center,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: fittedSizes.destination.width,
                                      height: fittedSizes.destination.height,
                                      child: child!,
                                    ),
                                    if (model.showTrajectories)
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
                                    if (model.showGamePieces)
                                      CustomPaint(
                                        size: fittedSizes.destination,
                                        painter: GamePiecePainter(
                                          center: fittedCenter,
                                          field: model.field,
                                          gamePieces: model.gamePieceTopics.value,
                                          gamePieceColor: model.gamePieceColor,
                                          bestGamePieceColor: model.bestGamePieceColor,
                                          markerSize: model.gamePieceMarkerSize,
                                          scale: scaleReduction,
                                        ),
                                      ),
                                    if (model.showVisionTargets)
                                      CustomPaint(
                                        size: fittedSizes.destination,
                                        painter: VisionPainter(
                                          center: fittedCenter,
                                          field: model.field,
                                          poses: [
                                            model.visionTopics.closeCamPose,
                                            model.visionTopics.farCamPose,
                                            model.visionTopics.leftCamPose,
                                            model.visionTopics.rightCamPose,
                                          ],
                                          statuses: [
                                            [
                                              model.visionTopics.closeCamLocation.value,
                                              model.visionTopics.closeCamHeading.value,
                                            ],
                                            [
                                              model.visionTopics.farCamLocation.value,
                                              model.visionTopics.farCamHeading.value,
                                            ],
                                            [
                                              model.visionTopics.leftCamLocation.value,
                                              model.visionTopics.leftCamHeading.value,
                                            ],
                                            [
                                              model.visionTopics.rightCamLocation.value,
                                              model.visionTopics.rightCamHeading.value,
                                            ],
                                          ],
                                          color: model.visionTargetColor,
                                          markerSize: model.visionMarkerSize,
                                          scale: scaleReduction,
                                        ),
                                      ),
                                    if (model.showOtherObjects)
                                      CustomPaint(
                                        size: fittedSizes.destination,
                                        painter: OtherObjectsPainter(
                                          center: fittedCenter,
                                          field: model.field,
                                          subscriptions: model.otherObjectSubscriptions,
                                          isPoseStruct: model.isPoseStruct,
                                          isPoseArrayStruct: model.isPoseArrayStruct,
                                          robotColor: model.robotColor,
                                          objectSize: model.otherObjectSize,
                                          scale: scaleReduction,
                                        ),
                                      ),
                                    CustomPaint(
                                      size: fittedSizes.destination,
                                      painter: RobotPainter(
                                        center: fittedCenter,
                                        field: model.field,
                                        robotPose: Offset(robotX, robotY),
                                        robotAngle: robotTheta,
                                        robotSize: Size(
                                          model.robotWidthMeters,
                                          model.robotLengthMeters,
                                        ),
                                        robotColor: model.robotColor,
                                        robotImage: model.robotImage,
                                        scale: scaleReduction,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),          );
        },
      ),
    );
  }
}
