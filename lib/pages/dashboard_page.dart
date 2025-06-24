import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:elegant_notification/resources/stacked_options.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:elastic_dashboard/pages/dashboard/add_widget_dialog.dart';
import 'package:elastic_dashboard/pages/dashboard/dashboard_page_footer.dart';
import 'package:elastic_dashboard/pages/dashboard/dashboard_page_layouts.dart';
import 'package:elastic_dashboard/pages/dashboard/dashboard_page_notifications.dart';
import 'package:elastic_dashboard/pages/dashboard/dashboard_page_settings.dart';
import 'package:elastic_dashboard/pages/dashboard/dashboard_page_tabs.dart';
import 'package:elastic_dashboard/pages/dashboard/dashboard_page_window.dart';
import 'package:elastic_dashboard/services/app_distributor.dart';
import 'package:elastic_dashboard/services/elastic_layout_downloader.dart';
import 'package:elastic_dashboard/services/elasticlib_listener.dart';
import 'package:elastic_dashboard/services/hotkey_manager.dart';
import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/services/update_checker.dart';
import 'package:elastic_dashboard/util/tab_data.dart';
import 'package:elastic_dashboard/util/test_utils.dart';
import 'package:elastic_dashboard/widgets/custom_appbar.dart';
import 'package:elastic_dashboard/widgets/editable_tab_bar.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';

import 'package:elastic_dashboard/util/stub/unload_handler_stub.dart'
    if (dart.library.js_interop) 'package:elastic_dashboard/util/unload_handler.dart';
import 'package:window_manager/window_manager.dart'
    if (dart.library.js_interop) 'package:elastic_dashboard/util/stub/window_stub.dart';

enum LayoutDownloadMode {
  overwrite(
    name: 'Overwrite',
    description:
        'Keeps existing tabs that are not defined in the remote layout. Any tabs that are defined in the remote layout will be overwritten locally.',
  ),
  merge(
    name: 'Merge',
    description:
        'Merge the downloaded layout with the existing one. If a new widget cannot be properly placed, it will not be added.',
  ),
  reload(
    name: 'Full Reload',
    description: 'Deletes the existing layout and loads the new one.',
  );

  final String name;
  final String description;

  const LayoutDownloadMode({required this.name, required this.description});

  static String get descriptions {
    String result = '';
    for (final value in values) {
      result += '${value.name}: ';
      result += value.description;

      if (value != values.last) {
        result += '\n\n';
      }
    }
    return result;
  }
}

mixin DashboardPageStateMixin on State<DashboardPage> {
  void showNotification(ElegantNotification notification) {
    if (mounted) notification.show(context);
  }

  Future<void> closeWindow();

  ThemeData get theme => Theme.of(context);

  ButtonThemeData get buttonTheme => ButtonTheme.of(context);
}

abstract class DashboardPageViewModel extends ChangeNotifier {
  final String version;
  final NTConnection ntConnection;
  final SharedPreferences preferences;
  late final UpdateChecker? updateChecker;
  late final ElasticLayoutDownloader? layoutDownloader;
  final Function(Color color)? onColorChanged;
  final Function(FlexSchemeVariant variant)? onThemeVariantChanged;

  late final ElasticLibListener robotNotificationListener;

  final List<TabData> tabData = [];

  final Function mapEquals = const DeepCollectionEquality().equals;

  late int gridSize =
      preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize;

  UpdateCheckerResponse lastUpdateResponse = UpdateCheckerResponse(
    updateAvailable: false,
    error: false,
  );

  int currentTabIndex = 0;

  bool addWidgetDialogVisible = false;

  DashboardPageStateMixin? _state;
  DashboardPageStateMixin? get state => _state;

  DashboardPageViewModel({
    required this.ntConnection,
    required this.preferences,
    required this.version,
    UpdateChecker? updateChecker,
    ElasticLayoutDownloader? layoutDownloader,
    this.onColorChanged,
    this.onThemeVariantChanged,
  }) {
    this.layoutDownloader =
        layoutDownloader ?? ElasticLayoutDownloader(Client());

    this.updateChecker =
        updateChecker ?? UpdateChecker(currentVersion: version);
  }

  Map<String, dynamic> toJson() {
    List<Map<String, dynamic>> gridData = [];

    for (int i = 0; i < tabData.length; i++) {
      TabData data = tabData[i];

      gridData.add({'name': data.name, 'grid_layout': data.tabGrid.toJson()});
    }

    return {'version': 1.0, 'grid_size': gridSize, 'tabs': gridData};
  }

  void init() {
    robotNotificationListener = ElasticLibListener(
      ntConnection: ntConnection,
      onTabSelected: (tabIdentifier) {
        if (tabIdentifier is int) {
          if (tabIdentifier >= tabData.length) {
            return;
          }
          switchToTab(tabIdentifier);
        } else if (tabIdentifier is String) {
          int tabIndex = tabData.indexWhere((tab) => tab.name == tabIdentifier);
          if (tabIndex == -1) {
            return;
          }
          switchToTab(tabIndex);
        }
      },
      onNotification: (title, description, icon, time, width, height) {
        ColorScheme colorScheme = state!.theme.colorScheme;
        TextTheme textTheme = state!.theme.textTheme;
        var widget = ElegantNotification(
          autoDismiss: time.inMilliseconds > 0,
          showProgressIndicator: time.inMilliseconds > 0,
          background: colorScheme.surface,
          width: width,
          height: height,
          position: Alignment.bottomRight,
          title: Text(
            title,
            style: textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
          ),
          toastDuration: time,
          icon: icon,
          description: Text(description),
          stackedOptions: StackedOptions(
            key: 'robot_notification',
            type: StackedType.above,
          ),
        );
        state!.showNotification(widget);
      },
    );
    robotNotificationListener.listen();

    ntConnection.dsClientConnect(
      onIPAnnounced: (ip) async {
        if (preferences.getInt(PrefKeys.ipAddressMode) !=
            IPAddressMode.driverStation.id) {
          return;
        }

        if (preferences.getString(PrefKeys.ipAddress) != ip) {
          await preferences.setString(PrefKeys.ipAddress, ip);
        } else {
          return;
        }

        ntConnection.changeIPAddress(ip);
      },
      onDriverStationDockChanged: (docked) {
        if ((preferences.getBool(PrefKeys.autoResizeToDS) ??
                Defaults.autoResizeToDS) &&
            docked) {
          onDriverStationDocked();
        } else {
          onDriverStationUndocked();
        }
      },
    );

    ntConnection.addConnectedListener(() {
      for (TabGridModel grid in tabData.map((e) => e.tabGrid)) {
        grid.onNTConnect();
      }
      notifyListeners();
    });

    ntConnection.addDisconnectedListener(() {
      for (TabGridModel grid in tabData.map((e) => e.tabGrid)) {
        grid.onNTDisconnect();
      }
      notifyListeners();
    });

    loadLayout();

    if (!isWPILib) {
      Future(
        () => checkForUpdates(notifyIfLatest: false, notifyIfError: false),
      );
    }
  }

  bool hasUnsavedChanges() {
    Map<String, dynamic> savedJson = jsonDecode(
      preferences.getString(PrefKeys.layout) ?? '{}',
    );
    Map<String, dynamic> currentJson = toJson();

    return !mapEquals(savedJson, currentJson);
  }

  Future<void> saveLayout() async {}

  Future<void> saveWindowPosition() async {}

  Future<void> checkForUpdates({
    bool notifyIfLatest = true,
    bool notifyIfError = true,
  }) async {
    ColorScheme colorScheme = state!.theme.colorScheme;
    TextTheme textTheme = state!.theme.textTheme;
    ButtonThemeData buttonTheme = state!.buttonTheme;

    UpdateCheckerResponse updateResponse = await updateChecker!
        .isUpdateAvailable();

    lastUpdateResponse = updateResponse;
    notifyListeners();

    if (updateResponse.error && notifyIfError) {
      ElegantNotification notification = ElegantNotification(
        background: colorScheme.surface,
        progressIndicatorBackground: colorScheme.surface,
        progressIndicatorColor: const Color(0xffFE355C),
        width: 350,
        height: 100,
        position: Alignment.bottomRight,
        toastDuration: const Duration(seconds: 3, milliseconds: 500),
        icon: const Icon(Icons.error, color: Color(0xffFE355C)),
        title: Text(
          'Failed to check for updates',
          style: textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
        ),
        description: Text(
          updateResponse.errorMessage!,
          overflow: TextOverflow.ellipsis,
          maxLines: 3,
        ),
      );

      state!.showNotification(notification);
      return;
    }

    if (updateResponse.updateAvailable) {
      ElegantNotification notification = ElegantNotification(
        autoDismiss: false,
        showProgressIndicator: false,
        background: colorScheme.surface,
        width: 350,
        height: 100,
        position: Alignment.bottomRight,
        title: Text(
          'Version ${updateResponse.latestVersion!} Available',
          style: textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.info, color: Color(0xff0066FF)),
        description: const Text('A new update is available!'),
        action: TextButton(
          onPressed: () async {
            Uri url = Uri.parse(
              '${Settings.repositoryLink}/releases/tag/v${updateResponse.latestVersion!}',
            );

            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
          child: Text(
            'Update',
            style: textTheme.bodyMedium!.copyWith(
              color: buttonTheme.colorScheme?.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );

      state!.showNotification(notification);
    } else if (updateResponse.onLatestVersion && notifyIfLatest) {
      showInfoNotification(
        title: 'No Updates Available',
        message: 'You are running on the latest version of Elastic',
        width: 350,
        height: 75,
      );
    }
  }

  Future<void> exportLayout() async {}

  Future<void> importLayout() async {}

  void loadLayout() {}

  bool validateJsonData(Map<String, dynamic>? jsonData) => false;

  void clearLayout() {}

  bool loadLayoutFromJsonData(String jsonString) => false;

  bool mergeLayoutFromJsonData(String jsonString) => false;

  void overwriteLayoutFromJsonData(String jsonString) {}

  Future<({String layout, LayoutDownloadMode mode})?> showRemoteLayoutSelection(
    List<String> fileNames,
  ) => Future.value(null);

  Future<void> loadLayoutFromRobot() async {}

  void createDefaultTabs() {}

  void lockLayout() {}

  void unlockLayout() {}

  void displayAddWidgetDialog() {
    logger.info('Displaying add widget dialog');
    addWidgetDialogVisible = true;
    notifyListeners();
  }

  void displayAboutDialog(BuildContext context) {
    logger.info('Displaying about dialog');
    IconThemeData iconTheme = IconTheme.of(context);

    showAboutDialog(
      context: context,
      applicationName: appTitle,
      applicationVersion: version,
      applicationIcon: Image.asset(
        logoPath,
        width: iconTheme.size,
        height: iconTheme.size,
      ),
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 353),
          child: const Text(
            'Elastic was created by Nadav from FRC Team 353, the POBots, in the Summer of 2023.\n',
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 353),
          child: const Text(
            'The goal of Elastic is to have the essential features needed for a driver dashboard, but with an elegant and modern display and a focus on customizability and performance.\n',
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 353),
          child: const Text(
            'Elastic is an ongoing project; if you have any ideas, feedback, or bug reports, feel free to share them on the Github page!\n',
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 353),
          child: const Text(
            'Elastic was built with inspiration from Shuffleboard and AdvantageScope, along with significant help from FRC and WPILib developers.\n',
          ),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () async {
                Uri url = Uri.parse(Settings.repositoryLink);

                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: const Text('View Repository'),
            ),
            const Spacer(),
          ],
        ),
      ],
    );
  }

  void displaySettingsDialog(BuildContext context) {}

  Future<void> changeIPAddressMode(IPAddressMode mode) async {}

  Future<void> changeNTTargetServer(NTServerTarget mode) async {}

  Future<void> updateIPAddress(String newIPAddress) async {}

  Future<void> onDriverStationDocked() async {}

  Future<void> onDriverStationUndocked() async {}

  void showWindowCloseConfirmation(BuildContext context) {}

  void showTabCloseConfirmation(
    BuildContext context,
    String tabName,
    Function() onClose,
  ) {}

  void switchToTab(int tabIndex) {}

  void moveTabLeft() {}

  void moveTabRight() {}

  void moveToNextTab() {}

  void moveToPreviousTab() {}

  void showJsonLoadingError(String errorMessage) {}

  void showJsonLoadingWarning(String warningMessage) {}

  void showInfoNotification({
    required String title,
    required String message,
    Duration toastDuration = const Duration(seconds: 3, milliseconds: 500),
    double? width,
    double? height,
  }) {}

  void showWarningNotification({
    required String title,
    required String message,
    Duration toastDuration = const Duration(seconds: 3, milliseconds: 500),
    double? width,
    double? height,
  }) {}

  void showErrorNotification({
    required String title,
    required String message,
    Duration toastDuration = const Duration(seconds: 3, milliseconds: 500),
    double? width,
    double? height,
  }) {}

  void showNotification({
    required String title,
    required String message,
    required Color color,
    required Widget icon,
    Duration toastDuration = const Duration(seconds: 3, milliseconds: 500),
    double? width,
    double? height,
  }) {}
}

class DashboardPageViewModelImpl = DashboardPageViewModel
    with
        DashboardPageNotifications,
        DashboardPageLayouts,
        DashboardPageSettings,
        DashboardPageTabs,
        DashboardPageWindow;

class DashboardPage extends StatefulWidget {
  final DashboardPageViewModel model;

  const DashboardPage({super.key, required this.model});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WindowListener, DashboardPageStateMixin {
  SharedPreferences get preferences => widget.model.preferences;
  DashboardPageViewModel get model => widget.model;

  @override
  void initState() {
    super.initState();

    model._state = this;
    model.init();

    model.addListener(onModelUpdate);

    windowManager.addListener(this);
    setupUnloadHandler(() => model.hasUnsavedChanges());
    if (!isUnitTest) {
      Future(() async => await windowManager.setPreventClose(true));
    }

    _setupShortcuts();
  }

  void onModelUpdate() => setState(() {});

  @override
  void onWindowClose() async {
    bool showConfirmation = model.hasUnsavedChanges();

    if (showConfirmation) {
      widget.model.showWindowCloseConfirmation(context);
      await windowManager.focus();
    } else {
      await closeWindow();
    }
  }

  @override
  Future<void> closeWindow() async {
    await model.saveWindowPosition();
    await windowManager.destroy();
    exit(0);
  }

  @override
  void didUpdateWidget(DashboardPage oldWidget) {
    if (widget.model != oldWidget.model) {
      oldWidget.model.removeListener(onModelUpdate);
      oldWidget.model._state = null;

      widget.model.addListener(onModelUpdate);
      widget.model._state = this;
      widget.model.init();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    removeUnloadHandler();
    windowManager.removeListener(this);
    model._state = null;
    model.removeListener(onModelUpdate);
    super.dispose();
  }

  void _setupShortcuts() {
    logger.info('Setting up shortcuts');
    // Import Layout (Ctrl + O)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.keyO, modifiers: [KeyModifier.control]),
      callback: model.importLayout,
    );
    // Save (Ctrl + S)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.keyS, modifiers: [KeyModifier.control]),
      callback: model.saveLayout,
    );
    // Export (Ctrl + Shift + S)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.keyS,
        modifiers: [KeyModifier.control, KeyModifier.shift],
      ),
      callback: model.exportLayout,
    );
    // Download from robot (Ctrl + D)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.keyD, modifiers: [KeyModifier.control]),
      callback: () {
        if (preferences.getBool(PrefKeys.layoutLocked) ??
            Defaults.layoutLocked) {
          return;
        }

        model.loadLayoutFromRobot();
      },
    );
    // Switch to Tab (Ctrl + Tab #)
    for (int i = 1; i <= 9; i++) {
      hotKeyManager.register(
        HotKey(LogicalKeyboardKey(48 + i), modifiers: [KeyModifier.control]),
        callback: () {
          if (model.currentTabIndex == i - 1) {
            logger.debug(
              'Ignoring switch to tab ${i - 1}, current tab is already ${model.currentTabIndex}',
            );
            return;
          }
          if (i - 1 < model.tabData.length) {
            logger.info(
              'Switching tab to index ${i - 1} via keyboard shortcut',
            );
            model.switchToTab(i - 1);
          }
        },
      );
    }
    // Move to next tab (Ctrl + Tab)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.tab, modifiers: [KeyModifier.control]),
      callback: () {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          model.moveToNextTab();
        }
      },
    );
    // Move to prevoius tab (Ctrl + Shift + Tab)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.tab,
        modifiers: [KeyModifier.control, KeyModifier.shift],
      ),
      callback: () {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          model.moveToPreviousTab();
        }
      },
    );
    // Move Tab Left (Ctrl + <-)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.arrowLeft, modifiers: [KeyModifier.control]),
      callback: () {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          model.moveTabLeft();
        }
      },
    );
    // Move Tab Right (Ctrl + ->)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.arrowRight, modifiers: [KeyModifier.control]),
      callback: () {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          model.moveTabRight();
        }
      },
    );
    // New Tab (Ctrl + T)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.keyT, modifiers: [KeyModifier.control]),
      callback: () {
        if (preferences.getBool(PrefKeys.layoutLocked) ??
            Defaults.layoutLocked) {
          return;
        }
        String newTabName = 'Tab ${model.tabData.length + 1}';
        int newTabIndex = model.tabData.length;

        model.tabData.add(
          TabData(
            name: newTabName,
            tabGrid: TabGridModel(
              ntConnection: model.ntConnection,
              preferences: model.preferences,
              onAddWidgetPressed: model.displayAddWidgetDialog,
            ),
          ),
        );

        model.switchToTab(newTabIndex);
      },
    );
    // Close Tab (Ctrl + W)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.keyW, modifiers: [KeyModifier.control]),
      callback: () {
        if (preferences.getBool(PrefKeys.layoutLocked) ??
            Defaults.layoutLocked) {
          return;
        }
        if (model.tabData.length <= 1) {
          return;
        }

        TabData currentTab = model.tabData[model.currentTabIndex];

        model.showTabCloseConfirmation(context, currentTab.name, () {
          int oldTabIndex = model.currentTabIndex;

          if (model.currentTabIndex == model.tabData.length - 1) {
            model.currentTabIndex--;
          }

          model.tabData[oldTabIndex].tabGrid.onDestroy();

          setState(() {
            model.tabData[oldTabIndex].tabGrid.dispose();
            model.tabData.removeAt(oldTabIndex);
          });
        });
      },
    );
    // Open settings dialog (Ctrl + ,)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.comma, modifiers: [KeyModifier.control]),
      callback: () {
        if ((ModalRoute.of(context)?.isCurrent ?? false) && mounted) {
          model.displaySettingsDialog(context);
        }
      },
    );
    // Connect to robot (Ctrl + K)
    hotKeyManager.register(
      HotKey(LogicalKeyboardKey.keyK, modifiers: [KeyModifier.control]),
      callback: () {
        if (preferences.getInt(PrefKeys.ipAddressMode) ==
            IPAddressMode.driverStation.id) {
          return;
        }
        model.updateIPAddress(
          IPAddressUtil.teamNumberToIP(
            preferences.getInt(PrefKeys.teamNumber) ?? Defaults.teamNumber,
          ),
        );
        model.changeIPAddressMode(IPAddressMode.driverStation);
      },
    );
    // Connect to sim (Ctrl + Shift + K)
    hotKeyManager.register(
      HotKey(
        LogicalKeyboardKey.keyK,
        modifiers: [KeyModifier.control, KeyModifier.shift],
      ),
      callback: () {
        if (preferences.getInt(PrefKeys.ipAddressMode) ==
            IPAddressMode.localhost.id) {
          return;
        }
        widget.model.changeIPAddressMode(IPAddressMode.localhost);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double windowWidth = MediaQuery.of(context).size.width;

    TextStyle? menuTextStyle = Theme.of(context).textTheme.bodySmall;
    TextStyle? footerStyle = Theme.of(context).textTheme.bodyMedium;
    ButtonStyle menuButtonStyle = ButtonStyle(
      alignment: Alignment.center,
      textStyle: WidgetStatePropertyAll(menuTextStyle),
      backgroundColor: const WidgetStatePropertyAll(
        Color.fromARGB(255, 25, 25, 25),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      iconSize: const WidgetStatePropertyAll(20.0),
    );

    final bool layoutLocked =
        preferences.getBool(PrefKeys.layoutLocked) ?? Defaults.layoutLocked;

    late final double platformWidthAdjust;
    if (!kIsWeb) {
      if (Platform.isMacOS) {
        platformWidthAdjust = 30;
      } else if (Platform.isLinux) {
        platformWidthAdjust = 10;
      } else {
        platformWidthAdjust = 0;
      }
    } else {
      platformWidthAdjust = 0;
    }

    final double minWindowWidth =
        platformWidthAdjust + (layoutLocked ? 500 : 460);
    final bool consolidateMenu = windowWidth < minWindowWidth;

    List<Widget> menuChildren = [
      // File
      SubmenuButton(
        style: menuButtonStyle,
        menuChildren: [
          // Open Layout
          MenuItemButton(
            style: menuButtonStyle,
            onPressed: !layoutLocked ? model.importLayout : null,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyO,
              control: true,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_open_outlined),
                SizedBox(width: 8),
                Text('Open Layout'),
              ],
            ),
          ),
          // Save
          MenuItemButton(
            style: menuButtonStyle,
            onPressed: model.saveLayout,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyS,
              control: true,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.save_outlined),
                SizedBox(width: 8),
                Text('Save'),
              ],
            ),
          ),
          // Export layout
          MenuItemButton(
            style: menuButtonStyle,
            onPressed: model.exportLayout,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyS,
              shift: true,
              control: true,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.save_as_outlined),
                SizedBox(width: 8),
                Text('Save As'),
              ],
            ),
          ),
          // Download layout
          MenuItemButton(
            style: menuButtonStyle,
            onPressed: !layoutLocked ? model.loadLayoutFromRobot : null,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyD,
              control: true,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download),
                SizedBox(width: 8),
                Text('Download From Robot'),
              ],
            ),
          ),
        ],
        child: const Text('File'),
      ),
      // Edit
      SubmenuButton(
        style: menuButtonStyle,
        menuChildren: [
          // Clear layout
          MenuItemButton(
            style: menuButtonStyle,
            onPressed: !layoutLocked
                ? () {
                    setState(() {
                      model.tabData[model.currentTabIndex].tabGrid
                          .confirmClearWidgets(context);
                    });
                  }
                : null,
            leadingIcon: const Icon(Icons.clear),
            child: const Text('Clear Layout'),
          ),
          // Lock/Unlock Layout
          MenuItemButton(
            style: menuButtonStyle,
            onPressed: () {
              if (layoutLocked) {
                model.unlockLayout();
              } else {
                model.lockLayout();
              }

              setState(() {});
            },
            leadingIcon: layoutLocked
                ? const Icon(Icons.lock_open)
                : const Icon(Icons.lock_outline),
            child: Text('${layoutLocked ? 'Unlock' : 'Lock'} Layout'),
          ),
        ],
        child: const Text('Edit'),
      ),
      // Help
      SubmenuButton(
        style: menuButtonStyle,
        menuChildren: [
          // About
          MenuItemButton(
            style: menuButtonStyle,
            onPressed: () {
              model.displayAboutDialog(context);
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 8),
                Text('About'),
              ],
            ),
          ),
          // Check for Updates (not for WPILib distribution)
          if (!isWPILib)
            MenuItemButton(
              style: menuButtonStyle,
              onPressed: () => model.checkForUpdates(),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.update_outlined),
                  SizedBox(width: 8),
                  Text('Check for Updates'),
                ],
              ),
            ),
        ],
        child: const Text('Help'),
      ),
    ];

    MenuBar menuBar = MenuBar(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          Color.fromARGB(255, 25, 25, 25),
        ),
        elevation: WidgetStatePropertyAll(0),
      ),
      children: [
        Center(child: Image.asset(logoPath, width: 24, height: 24)),
        const SizedBox(width: 5),
        if (!consolidateMenu)
          ...menuChildren
        else
          SubmenuButton(
            style: menuButtonStyle.copyWith(
              iconSize: const WidgetStatePropertyAll(24),
            ),
            menuChildren: menuChildren,
            child: const Icon(Icons.menu),
          ),
        const VerticalDivider(width: 4),
        // Settings
        MenuItemButton(
          style: menuButtonStyle,
          leadingIcon: const Icon(Icons.settings),
          onPressed: () {
            model.displaySettingsDialog(context);
          },
          child: const Text('Settings'),
        ),
        const VerticalDivider(width: 4),
        // Add Widget
        MenuItemButton(
          style: menuButtonStyle,
          leadingIcon: const Icon(Icons.add),
          onPressed: !layoutLocked
              ? () => model.displayAddWidgetDialog()
              : null,
          child: const Text('Add Widget'),
        ),
        if (layoutLocked) ...[
          const VerticalDivider(width: 4),
          // Unlock Layout
          Tooltip(
            message: 'Unlock Layout',
            child: MenuItemButton(
              style: menuButtonStyle.copyWith(
                minimumSize: const WidgetStatePropertyAll(
                  Size(36.0, double.infinity),
                ),
                maximumSize: const WidgetStatePropertyAll(
                  Size(36.0, double.infinity),
                ),
              ),
              onPressed: () {
                model.unlockLayout();
                setState(() {});
              },
              child: const Icon(Icons.lock_outline),
            ),
          ),
        ],
      ],
    );

    Widget? updateButton;
    if (model.lastUpdateResponse.updateAvailable) {
      updateButton = IconButton(
        style: const ButtonStyle(
          shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
          maximumSize: WidgetStatePropertyAll(Size.square(34.0)),
          minimumSize: WidgetStatePropertyAll(Size.zero),
          padding: WidgetStatePropertyAll(EdgeInsets.all(4.0)),
          iconSize: WidgetStatePropertyAll(24.0),
        ),
        tooltip: 'Download version ${model.lastUpdateResponse.latestVersion}',
        onPressed: () async {
          Uri url = Uri.parse(Settings.releasesLink);

          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          }
        },
        icon: const Icon(Icons.update, color: Colors.orange),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        titleText: appTitle,
        onWindowClose: onWindowClose,
        leading: menuBar,
      ),
      body: Focus(
        autofocus: true,
        canRequestFocus: true,
        descendantsAreTraversable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Main dashboard page
            Expanded(
              child: Stack(
                children: [
                  EditableTabBar(
                    preferences: preferences,
                    gridDpiOverride: preferences.getDouble(
                      PrefKeys.gridDpiOverride,
                    ),
                    updateButton: updateButton,
                    currentIndex: model.currentTabIndex,
                    onTabMoveLeft: model.moveTabLeft,
                    onTabMoveRight: model.moveTabRight,
                    onTabRename: (index, newData) =>
                        setState(() => model.tabData[index] = newData),
                    onTabCreate: () {
                      String tabName = 'Tab ${model.tabData.length + 1}';
                      setState(() {
                        model.tabData.add(
                          TabData(
                            name: tabName,
                            tabGrid: TabGridModel(
                              ntConnection: model.ntConnection,
                              preferences: model.preferences,
                              onAddWidgetPressed: model.displayAddWidgetDialog,
                            ),
                          ),
                        );
                      });
                    },
                    onTabDestroy: (index) {
                      if (model.tabData.length <= 1) {
                        return;
                      }

                      TabData tabToRemove = model.tabData[index];

                      model.showTabCloseConfirmation(
                        context,
                        tabToRemove.name,
                        () {
                          int indexToSwitch = model.currentTabIndex;

                          if (indexToSwitch == model.tabData.length - 1) {
                            indexToSwitch--;
                          }

                          tabToRemove.tabGrid.onDestroy();
                          tabToRemove.tabGrid.dispose();

                          setState(() => model.tabData.remove(tabToRemove));
                          model.switchToTab(indexToSwitch);
                        },
                      );
                    },
                    onTabChanged: model.switchToTab,
                    onTabDuplicate: (index) {
                      setState(() {
                        Map<String, dynamic> tabJson = model
                            .tabData[index]
                            .tabGrid
                            .toJson();
                        TabGridModel newGrid = TabGridModel.fromJson(
                          ntConnection: model.ntConnection,
                          preferences: preferences,
                          jsonData: tabJson,
                          onAddWidgetPressed: model.displayAddWidgetDialog,
                          onJsonLoadingWarning: model.showJsonLoadingWarning,
                        );
                        model.tabData.insert(
                          index + 1,
                          TabData(
                            name: '${model.tabData[index].name} (Copy)',
                            tabGrid: newGrid,
                          ),
                        );
                      });
                    },
                    tabData: model.tabData,
                  ),
                  if (model.addWidgetDialogVisible)
                    AddWidgetDialog(
                      ntConnection: model.ntConnection,
                      preferences: model.preferences,
                      grid: model.tabData[model.currentTabIndex].tabGrid,
                      gridIndex: model.currentTabIndex,
                      onNTDragUpdate: (globalPosition, widget) {
                        model.tabData[model.currentTabIndex].tabGrid
                            .addDragInWidget(widget, globalPosition);
                      },
                      onNTDragEnd: (widget) {
                        model.tabData[model.currentTabIndex].tabGrid
                            .placeDragInWidget(widget);
                      },
                      onLayoutDragUpdate: (globalPosition, widget) {
                        model.tabData[model.currentTabIndex].tabGrid
                            .addDragInWidget(widget, globalPosition);
                      },
                      onLayoutDragEnd: (widget) {
                        model.tabData[model.currentTabIndex].tabGrid
                            .placeDragInWidget(widget);
                      },
                      onClose: () =>
                          setState(() => model.addWidgetDialogVisible = false),
                    ),
                ],
              ),
            ),
            // Bottom bar
            DashboardPageFooter(
              model: model,
              preferences: preferences,
              footerStyle: footerStyle,
              windowWidth: windowWidth,
            ),
          ],
        ),
      ),
    );
  }
}
