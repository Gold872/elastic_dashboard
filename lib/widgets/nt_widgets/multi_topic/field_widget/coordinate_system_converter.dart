import 'dart:math';

import 'package:flutter/material.dart';

import 'package:elastic_dashboard/services/field_images.dart';

class CoordinateSystemConverter {
  /// Entry point to convert any CoordinateSystem to the internal mapping
  static (double x, double y, double angle) convertToInternal(
    CoordinateSystem system,
    double rawX,
    double rawY,
    double rawAngleRadians,
    Field field,
  ) {
    switch (system) {
      case CoordinateSystem.wallBlue:
        return wallBlueToInternal(rawX, rawY, rawAngleRadians, field);
      case CoordinateSystem.centerRotated:
        return centerRotatedToInternal(rawX, rawY, rawAngleRadians, field);
      case CoordinateSystem.center:
        return centerToInternal(rawX, rawY, rawAngleRadians, field);
    }
  }

  /// Standard WPILib coordinate system pre-2027
  /// Origin at blue alliance corner, positive X going towards the left of the image,
  /// positive Y going towards the bottom of image
  ///
  /// The [rawAngleRadians] is expected to follow WPILib convention:
  /// 0 is towards +X, CCW is positive rotation.
  static (double x, double y, double angle) wallBlueToInternal(
    double rawX,
    double rawY,
    double rawAngleRadians,
    Field field,
  ) {
    // rawX: 0 is Blue, fieldWidthMeters is Red.
    // internalX: 0 is center, +X is Blue.
    double internalX = (field.fieldWidthMeters / 2) - rawX;

    // rawY: 0 is non-scoring table, fieldHeightMeters is scoring table.
    // internalY: 0 is center, +Y is Top (away from scoring table in WallBlue).
    // So flipped mapping applies.
    double internalY = (field.fieldHeightMeters / 2) - rawY;

    // E.g., Angle 0 (towards Red) is inverted to 180 (since +X is now Blue)
    double internalAngleRadians = rawAngleRadians + pi;

    return (internalX, internalY, internalAngleRadians);
  }

  /// Standard FTC coordinate system pre-2028
  /// Origin at center of field, positive X going along the red wall towards the bottom
  /// of the image, positive Y going towards the right of the image, away from red wall
  static (double x, double y, double angle) centerRotatedToInternal(
    double rawX,
    double rawY,
    double rawAngleRadians,
    Field field,
  ) => (rawY, -rawX, rawAngleRadians - pi / 2);

  /// Standard WPILib coordinate system 2027+
  /// Origin at center of field, positive X going towards the blue alliance wall (right of image),
  /// positive Y going towards the scoring table (top of image)
  static (double x, double y, double angle) centerToInternal(
    double rawX,
    double rawY,
    double rawAngleRadians,
    Field field,
  ) => (rawX, rawY, rawAngleRadians);

  /// Converts an internal coordinate (origin at center, +X to Blue, +Y to Scoring Table)
  /// into literal screen pixels relative to the field drawing Stack.
  static Offset internalToPixels(
    double internalX,
    double internalY,
    double scaleReduction,
    Field field,
  ) {
    // +X internal goes to Blue (right)
    double xFromCenter =
        internalX * field.pixelsPerMeterHorizontal * scaleReduction;

    // +Y internal goes Up. Flutter stack +Y goes Down, so we negate internalY.
    double yFromCenter =
        -internalY * field.pixelsPerMeterVertical * scaleReduction;

    return Offset(xFromCenter, yFromCenter);
  }
}
