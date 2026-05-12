import 'dart:collection';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';

import 'package:elastic_dashboard/services/hotkey_manager.dart';

class KeybindsDialog extends StatelessWidget {
  final List<HotKey> hotkeys;

  const KeybindsDialog({super.key, required this.hotkeys});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Column(
      children: [Text('Keyboard Shortcuts'), Divider()],
    ),
    content: SizedBox(
      width: 350,
      child: Wrap(
        direction: Axis.horizontal,
        children: _buildFullKeyBindList(
          KeybindsUtils.convertHotkeysToDisplayKeybinds(hotkeys),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  );

  List<Widget> _buildFullKeyBindList(
    List<DisplayableKeybindCategory> keybinds,
  ) {
    /// Builds the entire page for the keybinds based on all the provided caterogies which contains keybinds
    List<Widget> keybindWidgets = [];
    for (DisplayableKeybindCategory keybindCategory in keybinds) {
      keybindWidgets.add(
        KeybindCategoryWidget(
          name: keybindCategory.name,
          keybinds: keybindCategory.keybinds,
        ),
      );
    }
    return [
      ...keybindWidgets,
    ];
  }
}

class KeybindCategoryWidget extends StatelessWidget {
  final String name;
  final List<DisplayableHotkey> keybinds;

  const KeybindCategoryWidget({
    super.key,
    required this.name,
    required this.keybinds,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> keybindWidgets = [];
    for (int i = 0; i < keybinds.length; i++) {
      keybindWidgets.add(
        KeybindWidget(
          keys: keybinds[i].keys,
          description: keybinds[i].description,
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
      child: Wrap(
        direction: Axis.vertical,
        spacing: 4,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleMedium),
          ...keybindWidgets,
        ],
      ),
    );
  }
}

class KeybindWidget extends StatelessWidget {
  final List<String> keys;
  final String description;

  const KeybindWidget({
    super.key,
    required this.keys,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    /// Builds a single keybind entry, showing the keys and the description
    List<Widget> keybindChips = [];
    for (int i = 0; i < keys.length; i++) {
      keybindChips.add(_buildSingleChip(context, keys[i]));
      if (i < keys.length - 1) {
        //the "+" between keys
        keybindChips.add(
          Row(
            children: [
              const SizedBox(width: 5),
              Text('+'),
              const SizedBox(width: 5),
            ],
          ),
        );
      }
    }
    //description of the key on the right side
    keybindChips.add(
      Row(
        children: [
          const SizedBox(width: 5),
          Text('-'),
          const SizedBox(width: 5),
          Text(
            description,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
    return Row(mainAxisSize: MainAxisSize.min, children: keybindChips);
  }

  Widget _buildSingleChip(BuildContext context, String text) => Chip(
    label: Text(text),
    padding: EdgeInsets.all(2),
    labelStyle: Theme.of(context).textTheme.bodySmall,
    // backgroundColor: Theme.of(context).cardColor,
  );
}

class DisplayableKeybindCategory {
  final String name;
  final List<DisplayableHotkey> keybinds;

  DisplayableKeybindCategory(this.name, this.keybinds);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DisplayableKeybindCategory &&
        name == other.name &&
        const ListEquality<DisplayableHotkey>().equals(
          keybinds,
          other.keybinds,
        );
  }

  @override
  int get hashCode => Object.hash(
    name,
    const ListEquality<DisplayableHotkey>().hash(keybinds),
  );
}

class DisplayableHotkey {
  final List<String> keys;
  final String description;

  DisplayableHotkey(this.keys, this.description);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DisplayableHotkey &&
        description == other.description &&
        const ListEquality<String>().equals(keys, other.keys);
  }

  @override
  int get hashCode => Object.hash(
    description,
    const ListEquality<String>().hash(keys),
  );
}

class KeybindsUtils {
  static List<DisplayableKeybindCategory> convertHotkeysToDisplayKeybinds(
    List<HotKey> hotkeys,
  ) {
    List<DisplayableKeybindCategory> convertedKeybinds = [];
    HashMap<String, List<DisplayableHotkey>> keybindMap = HashMap();

    for (var key in hotkeys) {
      if (!key.display) continue;
      DisplayableHotkey displayableHotkey = _fromHotkey(key);
      if (!keybindMap.containsKey(key.category)) {
        keybindMap[key.category] = [displayableHotkey];
      } else {
        keybindMap[key.category]!.add(displayableHotkey);
      }
    }
    for (final entry in keybindMap.entries) {
      final key = entry.key;
      final value = entry.value;
      convertedKeybinds.add(DisplayableKeybindCategory(key, value));
    }
    return convertedKeybinds;
  }

  static DisplayableHotkey _fromHotkey(HotKey key) {
    List<String> keys = [];
    if (key.modifiers != null) {
      for (KeyModifier modifier in key.modifiers!) {
        keys.add(modifier.displayName);
      }
    }
    keys.add(key.logicalKey.keyLabel);
    return DisplayableHotkey(keys, key.description);
  }
}
