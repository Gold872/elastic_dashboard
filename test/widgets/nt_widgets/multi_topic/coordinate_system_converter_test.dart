import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/field_widget/coordinate_system_converter.dart';

void main() {
  group('CoordinateSystemConverter', () {
    late Field field;

    setUp(() {
      // Initialize a standard 16m x 8m field mockup (10 pixels per meter)
      field = Field(
        jsonData: {
          'game': 'Test Coordinate Conversions',
          'source_url': '',
          'program': 'FRC',
          'coordinate_system': 'center',
          'field_size': [16.0, 8.0],
          'field_corners': {
            'top_left': [0, 0],
            'bottom_right': [160, 80],
          },
        },
      );
    });

    test(
      'wallBlueToInternal handles coordinate generation mapped centrally',
      () {
        // Test Origin: Blue wall right boundary maps to 8.0 (width / 2)
        var (internalX, internalY, internalAngle) =
            CoordinateSystemConverter.wallBlueToInternal(0.0, 0.0, 0.0, field);

        expect(internalX, closeTo(8.0, 0.001));
        expect(internalY, closeTo(4.0, 0.001));
        expect(internalAngle, closeTo(pi, 0.001));

        // Test opposing limits: Red wall left boundary maps to -8.0
        var (
          internalX2,
          internalY2,
          internalAngle2,
        ) = CoordinateSystemConverter.wallBlueToInternal(
          16.0,
          8.0,
          pi / 2,
          field,
        );

        expect(internalX2, closeTo(-8.0, 0.001));
        expect(internalY2, closeTo(-4.0, 0.001));
        expect(internalAngle2, closeTo(pi + (pi / 2), 0.001));
      },
    );

    test(
      'centerRotatedToInternal properly assigns swapped inverted constraints',
      () {
        // Test swapped constraints: Y becomes inverted X, X becomes Y
        var (x, y, angle) = CoordinateSystemConverter.centerRotatedToInternal(
          5.0,
          -3.0,
          0,
          field,
        );

        expect(x, closeTo(-3.0, 0.001));
        expect(y, closeTo(-5.0, 0.001));
        expect(angle, closeTo(-pi / 2, 0.001));
      },
    );

    test('centerToInternal honors transparent value retention', () {
      // Test direct 1:1 correlation
      var (x, y, angle) = CoordinateSystemConverter.centerToInternal(
        7.5,
        3.2,
        pi,
        field,
      );

      expect(x, closeTo(7.5, 0.001));
      expect(y, closeTo(3.2, 0.001));
      expect(angle, closeTo(pi, 0.001));
    });

    test(
      'internalToPixels properly maps pixel scaling',
      () {
        // Test right/up bounds (Up maps to negative Y internally)
        Offset result = CoordinateSystemConverter.internalToPixels(
          5.0,
          2.0,
          1.0,
          field,
        );

        expect(result.dx, closeTo(50.0, 0.001));
        expect(result.dy, closeTo(-20.0, 0.001));

        // Test the multiplier reduction
        Offset scaledResult = CoordinateSystemConverter.internalToPixels(
          5.0,
          2.0,
          0.5,
          field,
        );

        expect(scaledResult.dx, closeTo(25.0, 0.001));
        expect(scaledResult.dy, closeTo(-10.0, 0.001));
      },
    );

    test(
      'convertToInternal routing successfully delegates specific enum targets',
      () {
        // Wall-Blue mapped delegate
        var wallBlue = CoordinateSystemConverter.convertToInternal(
          CoordinateSystem.wallBlue,
          0.0,
          0.0,
          0.0,
          field,
        );
        expect(wallBlue.$1, closeTo(8.0, 0.001));

        // Center-Rotated swapped delegate
        var centerRotated = CoordinateSystemConverter.convertToInternal(
          CoordinateSystem.centerRotated,
          5.0,
          -3.0,
          0.0,
          field,
        );
        expect(centerRotated.$1, closeTo(-3.0, 0.001));

        // Standard Center 1:1 delegate
        var center = CoordinateSystemConverter.convertToInternal(
          CoordinateSystem.center,
          5.0,
          -3.0,
          pi,
          field,
        );
        expect(center.$1, closeTo(5.0, 0.001));
      },
    );
  });
}
