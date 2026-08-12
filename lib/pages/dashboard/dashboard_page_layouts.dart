import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import 'package:collection/collection.dart';
import 'package:dot_cast/dot_cast.dart';
import 'package:file_selector/file_selector.dart';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/elastic_layout_downloader.dart';
import 'package:elastic_dashboard/services/hotkey_manager.dart';
import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/util/tab_data.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';

mixin DashboardPageLayouts on DashboardPageViewModel {
  @override
  Future<void> saveLayout() async {
    Map<String, dynamic> jsonData = toJson();

    bool successful = await preferences.setString(
      PrefKeys.layout,
      jsonEncode(jsonData),
    );
    await saveWindowPosition();

    if (successful) {
      logger.info('Layout saved successfully');
      showInfoNotification(
        title: 'Saved',
        message: 'Layout saved successfully',
        width: 300,
      );
    } else {
      logger.error('Could not save layout');
      showInfoNotification(
        title: 'Error While Saving Layout',
        message: 'Failed to save layout, please try again',
        width: 300,
      );
    }
  }

  @override
  Future<void> exportLayout() async {
    const XTypeGroup jsonTypeGroup = XTypeGroup(
      label: 'JSON (JavaScript Object Notation)',
      extensions: ['.json'],
      mimeTypes: ['application/json'],
      uniformTypeIdentifiers: ['public.json'],
    );

    const XTypeGroup anyTypeGroup = XTypeGroup(label: 'All Files');

    logger.info('Exporting layout');
    final FileSaveLocation? saveLocation = await getSaveLocation(
      suggestedName: 'elastic-layout.json',
      acceptedTypeGroups: [jsonTypeGroup, anyTypeGroup],
    );

    hotKeyManager.resetKeysPressed();

    if (saveLocation == null) {
      logger.info('Ignoring layout export, no location was selected');
      return;
    }

    Map<String, dynamic> jsonData = toJson();
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    String jsonString = encoder.convert(jsonData);

    final Uint8List fileData = utf8.encode(jsonString);

    final XFile jsonFile = XFile.fromData(
      fileData,
      mimeType: 'application/json',
      name: 'elastic-layout.json',
    );

    logger.info('Saving layout data to ${saveLocation.path}');
    await jsonFile.saveTo(saveLocation.path);
    showInfoNotification(
      title: 'Exported Layout',
      message: 'Successfully exported layout to\n${saveLocation.path}',
      width: 500,
    );
  }

  @override
  Future<void> importLayout() async {
    if (preferences.getBool(PrefKeys.layoutLocked) ?? Defaults.layoutLocked) {
      return;
    }
    const XTypeGroup jsonTypeGroup = XTypeGroup(
      label: 'JSON (JavaScript Object Notation)',
      extensions: ['.json'],
      mimeTypes: ['application/json'],
      uniformTypeIdentifiers: ['public.json'],
    );

    const XTypeGroup anyTypeGroup = XTypeGroup(label: 'All Files');

    logger.info('Importing layout');
    final XFile? file = await openFile(
      acceptedTypeGroups: [jsonTypeGroup, anyTypeGroup],
    );

    hotKeyManager.resetKeysPressed();

    if (file == null) {
      logger.info('Canceling layout import, no file was selected');
      return;
    }

    String jsonString;

    try {
      jsonString = await file.readAsString();
    } on FileSystemException catch (e) {
      showJsonLoadingError(e.message);
      return;
    }

    Map<String, dynamic> jsonData;
    try {
      jsonData = jsonDecode(jsonString);
    } catch (e) {
      showJsonLoadingError(e.toString());
      return;
    }

    await preferences.setString(PrefKeys.layout, jsonEncode(jsonData));

    loadLayoutFromJsonData(jsonString);
    notifyListeners();
  }

  @override
  void loadLayout() {
    String? jsonString = preferences.getString(PrefKeys.layout);

    if (jsonString == null) {
      createDefaultTabs();
      return;
    }

    loadLayoutFromJsonData(jsonString);
    notifyListeners();
  }

  @override
  bool validateJsonData(Map<String, dynamic>? jsonData) {
    if (jsonData == null) {
      showJsonLoadingError('Invalid JSON format, aborting.');
      return false;
    }

    if (!jsonData.containsKey('tabs')) {
      showJsonLoadingError('JSON does not contain necessary data, aborting.');
      return false;
    }

    for (Map<String, dynamic> data in jsonData['tabs']) {
      if (tryCast(data['name']) == null) {
        showJsonLoadingError('Tab name not specified');
        return false;
      }

      if (tryCast<Map>(data['grid_layout']) == null) {
        showJsonLoadingError(
          'Grid layout not specified for tab \'${data['name']}\'',
        );
        return false;
      }
    }

    return true;
  }

  @override
  void clearLayout() {
    for (TabData tab in tabData) {
      tab.tabGrid.onDestroy();
    }
    tabData.clear();
  }

  @override
  bool loadLayoutFromJsonData(String jsonString) {
    logger.info('Loading layout from json');
    Map<String, dynamic>? jsonData = tryCast(jsonDecode(jsonString));

    if (!validateJsonData(jsonData)) {
      createDefaultTabs();
      return false;
    }

    if (jsonData!.containsKey('grid_size')) {
      gridSize = tryCast(jsonData['grid_size']) ?? gridSize;
      preferences.setInt(PrefKeys.gridSize, gridSize);
    }

    clearLayout();

    for (Map<String, dynamic> data in jsonData['tabs']) {
      tabData.add(
        TabData(
          name: data['name'],
          tabGrid: TabGridModel.fromJson(
            ntConnection: ntConnection,
            preferences: preferences,
            jsonData: data['grid_layout'],
            onAddWidgetPressed: displayAddWidgetDialog,
            onJsonLoadingWarning: showJsonLoadingWarning,
          ),
        ),
      );
    }

    createDefaultTabs();

    if (currentTabIndex >= tabData.length) {
      switchToTab(tabData.length - 1);
    }

    return true;
  }

  @override
  bool mergeLayoutFromJsonData(String jsonString) {
    logger.info('Merging layout from json');

    Map<String, dynamic>? jsonData = tryCast(jsonDecode(jsonString));

    if (!validateJsonData(jsonData)) {
      return false;
    }

    for (Map<String, dynamic> tabJson in jsonData!['tabs']) {
      String tabName = tabJson['name'];
      if (!tabData.any((tab) => tab.name == tabName)) {
        tabData.add(
          TabData(
            name: tabName,
            tabGrid: TabGridModel.fromJson(
              ntConnection: ntConnection,
              preferences: preferences,
              jsonData: tabJson['grid_layout'],
              onAddWidgetPressed: displayAddWidgetDialog,
              onJsonLoadingWarning: showJsonLoadingWarning,
            ),
          ),
        );
      } else {
        TabGridModel existingTab = tabData
            .firstWhere((tab) => tab.name == tabName)
            .tabGrid;
        existingTab.mergeFromJson(
          jsonData: tabJson['grid_layout'],
          onJsonLoadingWarning: showJsonLoadingWarning,
        );
      }
    }

    showInfoNotification(
      title: 'Successfully Downloaded Layout',
      message: 'Remote layout has been successfully downloaded and merged!',
      width: 350,
    );

    return true;
  }

  @override
  void overwriteLayoutFromJsonData(String jsonString) {
    logger.info('Overwriting layout from json');

    Map<String, dynamic>? jsonData = tryCast(jsonDecode(jsonString));

    if (!validateJsonData(jsonData)) {
      return;
    }

    int overwritten = 0;
    for (Map<String, dynamic> tabJson in jsonData!['tabs']) {
      String tabName = tabJson['name'];
      if (!tabData.any((tab) => tab.name == tabName)) {
        tabData.add(
          TabData(
            name: tabName,
            tabGrid: TabGridModel.fromJson(
              ntConnection: ntConnection,
              preferences: preferences,
              jsonData: tabJson['grid_layout'],
              onAddWidgetPressed: displayAddWidgetDialog,
              onJsonLoadingWarning: showJsonLoadingWarning,
            ),
          ),
        );
      } else {
        overwritten++;
        TabGridModel existingTab = tabData
            .firstWhere((tab) => tab.name == tabName)
            .tabGrid;
        existingTab.onDestroy();
        existingTab.loadFromJson(
          jsonData: tabJson['grid_layout'],
          onJsonLoadingWarning: showJsonLoadingWarning,
        );
      }
    }

    showInfoNotification(
      title: 'Successfully Downloaded Layout',
      message:
          'Remote layout has been successfully downloaded, $overwritten tabs were overwritten.',
      width: 350,
    );
  }

  @override
  Future<({String layout, LayoutDownloadMode mode})?> showRemoteLayoutSelection(
    List<String> fileNames,
  ) async {
    if (state == null) {
      logger.warning(
        'Attempting to show Remote Layout Selection while state is null.',
      );
      return null;
    }
    ValueNotifier<String?> layoutSelection = ValueNotifier(null);
    ValueNotifier<LayoutDownloadMode> modeSelection = ValueNotifier(
      LayoutDownloadMode.overwrite,
    );

    bool showModes = false;
    return await showDialog(
      context: state!.context,
      builder: (context) => AlertDialog(
        title: const Text('Select Layout'),
        content: SizedBox(
          width: 350,
          child: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Layout File'),
                ValueListenableBuilder(
                  valueListenable: layoutSelection,
                  builder: (_, value, child) => DialogDropdownChooser<String>(
                    choices: fileNames,
                    initialValue: value,
                    onSelectionChanged: (selection) =>
                        layoutSelection.value = selection,
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Download Mode'),
                Row(
                  children: [
                    Flexible(
                      child: ValueListenableBuilder(
                        valueListenable: modeSelection,
                        builder: (_, value, child) =>
                            DialogDropdownChooser<LayoutDownloadMode>(
                              choices: LayoutDownloadMode.values,
                              initialValue: value,
                              nameMap: (value) => value.name,
                              onSelectionChanged: (selection) {
                                if (selection != null) {
                                  modeSelection.value = selection;
                                }
                              },
                            ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    TextButton.icon(
                      label: const Text('Help'),
                      icon: const Icon(Icons.help_outline),
                      onPressed: () {
                        setState(() => showModes = !showModes);
                      },
                    ),
                  ],
                ),
                if (showModes) ...[
                  const SizedBox(height: 5),
                  Text(LayoutDownloadMode.descriptions),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder(
            valueListenable: layoutSelection,
            builder: (_, value, child) => TextButton(
              onPressed: (value != null)
                  ? () => Navigator.of(
                      context,
                    ).pop((layout: value, mode: modeSelection.value))
                  : null,
              child: const Text('Download'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> loadLayoutFromRobot() async {
    if (preferences.getBool(PrefKeys.layoutLocked) ?? Defaults.layoutLocked) {
      return;
    }

    LayoutDownloadResponse<List<String>> layoutsResponse =
        await layoutDownloader!.getAvailableLayouts(
          ntConnection: ntConnection,
          preferences: preferences,
        );

    if (!layoutsResponse.successful) {
      showErrorNotification(
        title: 'Failed to Retrieve Layout List',
        message:
            layoutsResponse.data.firstOrNull ??
            'Unable to retrieve list of available layouts',
        width: 400,
      );
      return;
    }

    if (layoutsResponse.data.isEmpty) {
      showErrorNotification(
        title: 'Failed to Retrieve Layout List',
        message:
            'No layouts were found, ensure a valid layout json file is placed in the root directory of your deploy directory.',
        width: 400,
      );
      return;
    }

    final selectedLayout = await showRemoteLayoutSelection(
      layoutsResponse.data.sorted((a, b) => a.compareTo(b)),
    );

    if (selectedLayout == null) {
      return;
    }

    LayoutDownloadResponse response = await layoutDownloader!.downloadLayout(
      ntConnection: ntConnection,
      preferences: preferences,
      layoutName: selectedLayout.layout,
    );

    if (!response.successful) {
      showErrorNotification(
        title: 'Failed to Download Layout',
        message: response.data,
        width: 400,
      );
      return;
    }

    switch (selectedLayout.mode) {
      case LayoutDownloadMode.merge:
        mergeLayoutFromJsonData(response.data);
        notifyListeners();
        break;
      case LayoutDownloadMode.overwrite:
        overwriteLayoutFromJsonData(response.data);
        notifyListeners();
        break;
      case LayoutDownloadMode.reload:
        bool success = loadLayoutFromJsonData(response.data);
        if (success) {
          showInfoNotification(
            title: 'Successfully Downloaded Layout',
            message: 'Remote layout has been successfully downloaded!',
            width: 350,
          );
        }
        notifyListeners();
    }
  }

  @override
  void lockLayout() async {
    for (TabGridModel grid in tabData.map((e) => e.tabGrid)) {
      grid.lockLayout();
    }
    await preferences.setBool(PrefKeys.layoutLocked, true);
  }

  @override
  void unlockLayout() async {
    for (TabGridModel grid in tabData.map((e) => e.tabGrid)) {
      grid.unlockLayout();
    }
    await preferences.setBool(PrefKeys.layoutLocked, false);
  }
}
