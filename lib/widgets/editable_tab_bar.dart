import 'package:flutter/services.dart';

import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transitioned_indexed_stack/transitioned_indexed_stack.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/util/tab_data.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/gesture/context_menu_listener.dart';
import 'package:elastic_dashboard/widgets/pixel_ratio_override.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';

class EditableTabBar extends StatelessWidget {
  final SharedPreferences preferences;

  final List<TabData> tabData;

  final Function() onTabCreate;
  final Function(int index) onTabDestroy;
  final Function() onTabMoveLeft;
  final Function() onTabMoveRight;
  final Function(int index, TabData newData) onTabRename;
  final Function(int index) onTabChanged;
  final Function(int index) onTabDuplicate;

  final int currentIndex;

  final Widget? updateButton;

  final double? gridDpiOverride;

  const EditableTabBar({
    super.key,
    required this.preferences,
    required this.currentIndex,
    required this.tabData,
    required this.onTabCreate,
    required this.onTabDestroy,
    required this.onTabMoveLeft,
    required this.onTabMoveRight,
    required this.onTabRename,
    required this.onTabChanged,
    required this.onTabDuplicate,
    this.updateButton,
    this.gridDpiOverride,
  });

  void renameTab(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Tab'),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 200),
          child: DialogTextInput(
            onSubmit: (value) {
              tabData[index].name = value;
              onTabRename.call(index, tabData[index]);
            },
            initialText: tabData[index].name,
            label: 'Name',
            formatter: LengthLimitingTextInputFormatter(50),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void duplicateTab(BuildContext context, int index) {
    onTabDuplicate.call(index);
  }

  void createTab() {
    onTabCreate();
  }

  void closeTab(int index) {
    if (tabData.length == 1) {
      return;
    }

    onTabDestroy.call(index);
  }

  Widget _buildTab(
    int index,
    BuildContext context,
    ThemeData theme,
  ) => ContextMenuListener(
    onContextMenuGesture: (globalPosition, _) {
      if (preferences.getBool(PrefKeys.layoutLocked) ?? Defaults.layoutLocked) {
        return;
      }
      ContextMenu contextMenu = ContextMenu(
        position: globalPosition,
        borderRadius: BorderRadius.circular(5.0),
        padding: const EdgeInsets.all(4.0),
        entries: [
          MenuHeader(text: tabData[index].name, disableUppercase: true),
          const MenuDivider(),
          MenuItem(
            label: 'Rename',
            icon: Icons.drive_file_rename_outline_outlined,
            onSelected: () => renameTab(context, index),
          ),
          MenuItem(
            label: 'Duplicate',
            icon: Icons.control_point_duplicate_sharp,
            onSelected: () => duplicateTab(context, index),
          ),
          MenuItem(
            label: 'Close',
            icon: Icons.close,
            onSelected: () => closeTab(index),
          ),
        ],
      );

      showContextMenu(
        context,
        contextMenu: contextMenu,
        routeOptions: MenuRouteOptions(
          transitionDuration: const Duration(milliseconds: 100),
          reverseTransitionDuration: Duration.zero,
          maintainState: true,
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    },
    child: GestureDetector(
      onTap: () {
        onTabChanged.call(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutExpo,
        margin: const EdgeInsets.only(left: 5.0, right: 5.0, top: 5.0),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: (currentIndex == index)
              ? theme.colorScheme.onPrimaryContainer
              : Colors.transparent,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10.0),
            topRight: Radius.circular(10.0),
          ),
        ),
        child: Center(
          child: Row(
            children: [
              Text(
                tabData[index].name,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: (currentIndex == index)
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
              // Spacing for close button
              Visibility(
                visible:
                    !(preferences.getBool(PrefKeys.layoutLocked) ??
                        Defaults.layoutLocked),
                child: const SizedBox(width: 10),
              ),
              // Close button
              Visibility(
                visible:
                    !(preferences.getBool(PrefKeys.layoutLocked) ??
                        Defaults.layoutLocked),
                child: IconButton(
                  onPressed: () {
                    closeTab(index);
                  },
                  padding: const EdgeInsets.all(0.0),
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(
                    minWidth: 15.0,
                    minHeight: 15.0,
                  ),
                  iconSize: 14,
                  color: (currentIndex == index)
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.onPrimaryContainer,
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    ButtonStyle endButtonStyle = const ButtonStyle(
      shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
      maximumSize: WidgetStatePropertyAll(Size.square(34.0)),
      minimumSize: WidgetStatePropertyAll(Size.zero),
      padding: WidgetStatePropertyAll(EdgeInsets.all(4.0)),
      iconSize: WidgetStatePropertyAll(24.0),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // Tab bar
        ExcludeFocus(
          child: Container(
            width: double.infinity,
            height: 36,
            color: theme.colorScheme.primaryContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    itemCount: tabData.length,
                    itemBuilder: (context, index) =>
                        _buildTab(index, context, theme),
                  ),
                ),
                const SizedBox(width: 16),
                // Tab movement buttons (move left, close, move right)
                Row(
                  children: [
                    if (updateButton != null) updateButton!,
                    IconButton(
                      style: endButtonStyle,
                      onPressed:
                          !(preferences.getBool(PrefKeys.layoutLocked) ??
                              Defaults.layoutLocked)
                          ? () => onTabMoveLeft.call()
                          : null,
                      alignment: Alignment.center,
                      icon: const Icon(Icons.west),
                    ),
                    IconButton(
                      style: endButtonStyle,
                      onPressed:
                          !(preferences.getBool(PrefKeys.layoutLocked) ??
                              Defaults.layoutLocked)
                          ? () => createTab()
                          : null,
                      alignment: Alignment.center,
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      style: endButtonStyle,
                      onPressed:
                          !(preferences.getBool(PrefKeys.layoutLocked) ??
                              Defaults.layoutLocked)
                          ? () => onTabMoveRight.call()
                          : null,
                      alignment: Alignment.center,
                      icon: const Icon(Icons.east),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Tab grid area
        Flexible(
          child: PixelRatioOverride(
            dpiOverride: gridDpiOverride,
            child: Stack(
              children: [
                Visibility(
                  visible:
                      preferences.getBool(PrefKeys.showGrid) ??
                      Defaults.showGrid,
                  child: GridPaper(
                    color: const Color.fromARGB(50, 195, 232, 243),
                    interval:
                        (preferences.getInt(PrefKeys.gridSize) ??
                                Defaults.gridSize)
                            .toDouble(),
                    divisions: 1,
                    subdivisions: 1,
                    child: Container(),
                  ),
                ),
                FadeIndexedStack(
                  curve: Curves.decelerate,
                  index: currentIndex,
                  children: [
                    for (TabGridModel grid in tabData.map((e) => e.tabGrid))
                      ChangeNotifierProvider<TabGridModel>.value(
                        value: grid,
                        child: const TabGrid(),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
