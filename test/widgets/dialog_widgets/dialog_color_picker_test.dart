import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';

class MockColorCallback extends Mock {
  void onColorChanged(Color? color);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Color picker select', (widgetTester) async {
    MockColorCallback mockCallback = MockColorCallback();

    Color? calledBackColor;

    when(mockCallback.onColorChanged(any)).thenAnswer((realInvocation) {
      calledBackColor = realInvocation.positionalArguments[0];
    });

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DialogColorPicker(
            onColorPicked: mockCallback.onColorChanged,
            label: 'Color Picker',
            initialColor: Colors.green,
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Color Picker'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);

    await widgetTester.tap(find.byType(ElevatedButton));
    await widgetTester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Restore Default'), findsNothing);
    expect(find.text('Save'), findsOneWidget);

    final hexInput = find.widgetWithText(TextField, 'Hex Code');

    expect(hexInput, findsOneWidget);

    await widgetTester.enterText(hexInput, '0000FF');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(calledBackColor, isNull);

    await widgetTester.tap(find.text('Save'));
    await widgetTester.pumpAndSettle();

    expect(calledBackColor, isNotNull);
    expect(calledBackColor!.toARGB32(), 0xFF0000FF);
  });

  testWidgets('Color picker cancel', (widgetTester) async {
    MockColorCallback mockCallback = MockColorCallback();

    Color? calledBackColor;

    when(mockCallback.onColorChanged(any)).thenAnswer((realInvocation) {
      calledBackColor = realInvocation.positionalArguments[0];
    });

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DialogColorPicker(
            onColorPicked: mockCallback.onColorChanged,
            label: 'Color Picker',
            initialColor: Colors.green,
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Color Picker'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);

    await widgetTester.tap(find.byType(ElevatedButton));
    await widgetTester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Restore Default'), findsNothing);
    expect(find.text('Save'), findsOneWidget);

    final hexInput = find.widgetWithText(TextField, 'Hex Code');

    expect(hexInput, findsOneWidget);

    await widgetTester.enterText(hexInput, '0000FF');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(calledBackColor, isNull);

    await widgetTester.tap(find.text('Cancel'));
    await widgetTester.pumpAndSettle();

    expect(calledBackColor, isNotNull);
    expect(calledBackColor!.toARGB32(), Colors.green.toARGB32());
  });

  testWidgets('Color picker restore default', (widgetTester) async {
    MockColorCallback mockCallback = MockColorCallback();

    Color? calledBackColor;

    when(mockCallback.onColorChanged(any)).thenAnswer((realInvocation) {
      calledBackColor = realInvocation.positionalArguments[0];
    });

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DialogColorPicker(
            onColorPicked: mockCallback.onColorChanged,
            label: 'Color Picker',
            initialColor: Colors.green,
            defaultColor: Colors.red,
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Color Picker'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);

    await widgetTester.tap(find.byType(ElevatedButton));
    await widgetTester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Restore Default'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    await widgetTester.tap(find.text('Restore Default'));
    await widgetTester.pumpAndSettle();

    expect(calledBackColor, isNotNull);
    expect(calledBackColor!.toARGB32(), Colors.red.toARGB32());
  });
}
