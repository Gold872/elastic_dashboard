import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:elastic_dashboard/services/hotkey_manager.dart';
import 'package:elastic_dashboard/widgets/keybinds_dialog.dart';
import '../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<HotKey> hotkeys = [
    HotKey(
      LogicalKeyboardKey.keyA,
      'Select All',
      'Test Category 1',
      modifiers: [KeyModifier.control],
    ),
    HotKey(
      LogicalKeyboardKey.delete,
      'Delete Everything',
      'Test Category 1',
      modifiers: [KeyModifier.control],
    ),
    HotKey(
      LogicalKeyboardKey.delete,
      'Escape the Field',
      'Test Category 1',
      modifiers: [KeyModifier.control, KeyModifier.alt],
    ),
    HotKey(
      LogicalKeyboardKey.keyH,
      'Open Help',
      'Test Category 2',
      modifiers: [KeyModifier.control],
    ),
    HotKey(
      LogicalKeyboardKey.keyS,
      'Save Layout',
      'Test Category 2',
      modifiers: [KeyModifier.control],
    ),
    HotKey(
      LogicalKeyboardKey.keyM,
      'Print Out',
      'Test Category 2',
      modifiers: [KeyModifier.control, KeyModifier.shift],
    ),
    HotKey(
      LogicalKeyboardKey.keyM,
      'You Cant See Me!',
      'Test Category 2',
      modifiers: [KeyModifier.control, KeyModifier.shift],
      display: false,
    ),
  ];

  final List<DisplayableKeybindCategory> displayKeybinds = [
    DisplayableKeybindCategory('Test Category 1', [
      DisplayableHotkey(['CTRL', 'A'], 'Select All'),
      DisplayableHotkey(['CTRL', 'Delete'], 'Delete Everything'),
      DisplayableHotkey(['CTRL', 'ALT', 'Delete'], 'Escape the Field'),
    ]),
    DisplayableKeybindCategory('Test Category 2', [
      DisplayableHotkey(['CTRL', 'H'], 'Open Help'),
      DisplayableHotkey(['CTRL', 'S'], 'Save Layout'),
      DisplayableHotkey(['CTRL', 'SHIFT', 'M'], 'Print Out'),
    ]),
  ];

  int totalDisplayKeybinds = 0;
  for (var cat in displayKeybinds) {
    totalDisplayKeybinds += cat.keybinds.length;
  }

  testWidgets('Keybinds Dialog Basic Layout', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeybindsDialog(
            hotkeys: hotkeys,
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Keyboard Shortcuts'), findsOneWidget);

    final closeButton = find.widgetWithText(TextButton, 'Close');

    expect(closeButton, findsOneWidget);

    await widgetTester.tap(closeButton);
    await widgetTester.pumpAndSettle();
  });

  test('Verify Utils Conversion Function', () {
    var result = KeybindsUtils.convertHotkeysToDisplayKeybinds(hotkeys);
    expect(result, equals(displayKeybinds));
  });

  testWidgets('Keybinds Dialog Correct Categories', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeybindsDialog(
            hotkeys: hotkeys,
          ),
        ),
      ),
    );
    await widgetTester.pumpAndSettle();
    // verify amount
    expect(
      find.byType(KeybindCategoryWidget),
      findsNWidgets(displayKeybinds.length),
      reason:
          'There are not exactly ${displayKeybinds.length} categories on the keybinds dialog.',
    );
    for (var category in displayKeybinds) {
      expect(find.text(category.name), findsOneWidget);
    }
  });

  testWidgets('Keybinds Dialog Correct Keybinds', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeybindsDialog(
            hotkeys: hotkeys,
          ),
        ),
      ),
    );
    await widgetTester.pumpAndSettle();
    expect(
      find.byType(KeybindWidget),
      findsNWidgets(totalDisplayKeybinds),
      reason:
          'There are not exactly $totalDisplayKeybinds keybinds on the keybinds dialog.',
    );

    var categories = find.byType(KeybindCategoryWidget);
    //iterate through each category
    for (int i = 0; i < displayKeybinds.length; i++) {
      final category = categories.at(i);
      var keybindsAmount = (widgetTester.widget<KeybindCategoryWidget>(
        category,
      )).keybinds.length;

      //child keybinds of a category
      var keybinds = find.descendant(
        of: category,
        matching: find.byType(KeybindWidget),
      );
      expect(keybinds, findsNWidgets(keybindsAmount));

      //check that each keybind is correct
      for (int j = 0; j < keybindsAmount; j++) {
        final keybindFinder = keybinds.at(j); //KeybindWidget
        var keyDesc = (widgetTester.widget<KeybindWidget>(
          keybindFinder,
        )).description;
        var keys = (widgetTester.widget<KeybindWidget>(keybindFinder)).keys;
        for (var key in keys) {
          expect(
            find.descendant(
              of: keybindFinder,
              matching: find.widgetWithText(Chip, key),
            ),
            findsOneWidget,
          );
        }
        expect(
          find.descendant(of: keybindFinder, matching: find.text('+')),
          findsNWidgets((keys.length - 1).toInt()),
          reason: 'You have too many \'+\'s in the keybind widget',
        );
        expect(
          find.descendant(of: keybindFinder, matching: find.text('-')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: keybindFinder, matching: find.text(keyDesc)),
          findsOneWidget,
        );
      }
    }
  });
}
