import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

class KeyModifier {
  static final KeyModifier control = KeyModifier._(
    () => HardwareKeyboard.instance.isControlPressed,
    'CTRL',
  );
  static final KeyModifier shift = KeyModifier._(
    () => HardwareKeyboard.instance.isShiftPressed,
    'SHIFT',
  );
  static final KeyModifier alt = KeyModifier._(
    () => HardwareKeyboard.instance.isAltPressed,
    'ALT',
  );

  const KeyModifier._(this.active, this.displayName);

  final bool Function() active;
  final String displayName;
}

class HotKey {
  final LogicalKeyboardKey logicalKey;
  final List<KeyModifier>? modifiers;
  final String description;
  final String category;
  final bool display;
  String identifier = const Uuid().v4();

  HotKey(
    this.logicalKey,
    this.description,
    this.category, {
    this.modifiers,
    String? identifier,

    //whether or not this keybind will be displayed on the keybinds page
    this.display = true,
  }) {
    if (identifier != null) {
      this.identifier = identifier;
    }
  }
}

typedef HotKeyCallback = void Function();

class HotKeyManager {
  HotKeyManager._();

  /// The shared instance of [HotKeyManager].
  static final HotKeyManager instance = HotKeyManager._();

  bool _initialized = false;
  final List<HotKey> _hotKeyList = [];
  final Map<String, HotKeyCallback> _callbackMap = {};

  void _init() {
    HardwareKeyboard.instance.addHandler(_handleRawKeyEvent);
    _initialized = true;
  }

  @visibleForTesting
  void tearDown() {
    _initialized = false;
    _hotKeyList.clear();
    _callbackMap.clear();
  }

  int _getNumberModifiersPressed() {
    int count = 0;

    if (HardwareKeyboard.instance.isControlPressed) {
      count++;
    }

    if (HardwareKeyboard.instance.isAltPressed) {
      count++;
    }

    if (HardwareKeyboard.instance.isShiftPressed) {
      count++;
    }

    if (HardwareKeyboard.instance.isMetaPressed) {
      count++;
    }

    return count;
  }

  bool _handleRawKeyEvent(KeyEvent value) {
    if (value is KeyUpEvent) {
      if (value is KeyRepeatEvent) return false;
      int modifierCount = _getNumberModifiersPressed();
      HotKey? hotKey = _hotKeyList.firstWhereOrNull((e) {
        if (value.logicalKey != e.logicalKey) {
          return false;
        }

        if (e.modifiers == null) {
          return true;
        }

        if (e.modifiers!.length != modifierCount) {
          return false;
        }

        for (KeyModifier modifier in e.modifiers!) {
          if (!modifier.active()) {
            return false;
          }
        }

        return true;
      });

      if (hotKey != null) {
        HotKeyCallback? callback = _callbackMap[hotKey.identifier];
        if (callback != null) {
          callback();
          return true;
        }
      } else {
        return false;
      }
    }
    return false;
  }

  List<HotKey> get registeredHotKeyList => _hotKeyList;

  void register(HotKey shortcut, {HotKeyCallback? callback}) {
    if (!_initialized) _init();

    if (callback != null) {
      _callbackMap.update(
        shortcut.identifier,
        (_) => callback,
        ifAbsent: () => callback,
      );
    }

    _hotKeyList.add(shortcut);
  }

  void unregister(HotKey hotKey) {
    if (!_initialized) _init();

    if (_callbackMap.containsKey(hotKey.identifier)) {
      _callbackMap.remove(hotKey.identifier);
    }

    _hotKeyList.removeWhere((e) => e.identifier == hotKey.identifier);
  }

  void unregisterAll() {
    if (!_initialized) _init();

    _callbackMap.clear();
    _hotKeyList.clear();
  }

  Future<void> resetKeysPressed() async {
    await HardwareKeyboard.instance.syncKeyboardState();
  }
}

class HotkeyCategories {
  static String layout = 'Layout';
  static String connection = 'Connection';
  static String tabs = 'Tab Control';
  static String misc = 'Miscellaneous';
}

final hotKeyManager = HotKeyManager.instance;
