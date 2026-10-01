import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:elastic_dashboard/services/hotkey_manager.dart';

class MockShortcutCallback extends Mock {
  void callback();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    hotKeyManager.tearDown();
    HardwareKeyboard.instance.clearState();
  });

  test('Shortcut no modifiers', () async {
    MockShortcutCallback mockCallback = MockShortcutCallback();

    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.keyA, 'Test Key', 'Test Category'),
      callback: mockCallback.callback,
    );

    await simulateKeyDownEvent(LogicalKeyboardKey.keyA);

    verifyNever(mockCallback.callback());

    await simulateKeyUpEvent(LogicalKeyboardKey.keyA);

    verify(mockCallback.callback()).called(1);

    await simulateKeyDownEvent(LogicalKeyboardKey.control);

    await simulateKeyDownEvent(LogicalKeyboardKey.keyA);
    await simulateKeyUpEvent(LogicalKeyboardKey.keyA);

    verify(mockCallback.callback()).called(1);
  });

  test('Shortcut with modifiers', () async {
    MockShortcutCallback mockCallback = MockShortcutCallback();

    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.keyA,
        'Test Key',
        'Test Category',
        modifiers: [KeyModifier.control, KeyModifier.shift, KeyModifier.alt],
      ),
      callback: mockCallback.callback,
    );

    await simulateKeyDownEvent(LogicalKeyboardKey.keyA);

    verifyNever(mockCallback.callback());

    await simulateKeyUpEvent(LogicalKeyboardKey.keyA);

    verifyNever(mockCallback.callback());

    await simulateKeyDownEvent(LogicalKeyboardKey.control);
    await simulateKeyDownEvent(LogicalKeyboardKey.shift);
    await simulateKeyDownEvent(LogicalKeyboardKey.alt);

    await simulateKeyDownEvent(LogicalKeyboardKey.keyA);
    await simulateKeyUpEvent(LogicalKeyboardKey.keyA);

    verify(mockCallback.callback()).called(1);
  });
}
