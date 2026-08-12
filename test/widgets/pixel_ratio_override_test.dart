import 'package:material_ui/material_ui.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:elastic_dashboard/widgets/pixel_ratio_override.dart';
import '../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Does not scale if override is null', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    final key = GlobalKey();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: PixelRatioOverride(dpiOverride: null, child: Container(key: key)),
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(
      key.currentContext!.findAncestorWidgetOfExactType<FractionallySizedBox>(),
      isNull,
    );
  });

  testWidgets('Does not scale if override is equal to dpi', (
    widgetTester,
  ) async {
    FlutterError.onError = ignoreOverflowErrors;

    final key = GlobalKey();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 1),
          child: PixelRatioOverride(dpiOverride: 1, child: Container(key: key)),
        ),
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(
      key.currentContext!.findAncestorWidgetOfExactType<FractionallySizedBox>(),
      isNull,
    );
  });

  testWidgets('Aligns top left if dpi override is smaller', (
    widgetTester,
  ) async {
    FlutterError.onError = ignoreOverflowErrors;

    final key = GlobalKey();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 1.25),
          child: PixelRatioOverride(dpiOverride: 1, child: Container(key: key)),
        ),
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(
      key.currentContext!.findAncestorWidgetOfExactType<FractionallySizedBox>(),
      isNotNull,
    );

    expect(
      key.currentContext!
          .findAncestorWidgetOfExactType<FractionallySizedBox>()!
          .alignment,
      Alignment.topLeft,
    );
  });

  testWidgets('Aligns top center if dpi override is larger', (
    widgetTester,
  ) async {
    FlutterError.onError = ignoreOverflowErrors;

    final key = GlobalKey();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 1),
          child: PixelRatioOverride(
            dpiOverride: 1.25,
            child: Container(key: key),
          ),
        ),
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(
      key.currentContext!.findAncestorWidgetOfExactType<FractionallySizedBox>(),
      isNotNull,
    );

    expect(
      key.currentContext!
          .findAncestorWidgetOfExactType<FractionallySizedBox>()!
          .alignment,
      Alignment.topCenter,
    );
  });
}
