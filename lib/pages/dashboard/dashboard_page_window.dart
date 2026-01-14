import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:screen_retriever/screen_retriever.dart';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/settings.dart';

import 'package:window_manager/window_manager.dart'
    if (dart.library.js_interop) 'package:elastic_dashboard/util/stub/window_stub.dart';

mixin DashboardPageWindow on DashboardPageViewModel {
  @override
  Future<void> saveWindowPosition() async {
    Rect bounds = await windowManager.getBounds();

    List<double> positionArray = [
      bounds.left,
      bounds.top,
      bounds.width,
      bounds.height,
    ];

    String positionString = jsonEncode(positionArray);

    await preferences.setString(PrefKeys.windowPosition, positionString);
  }

  @override
  Future<void> onDriverStationDocked() async {
    Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
    Size screenSize = primaryDisplay.visibleSize ?? primaryDisplay.size;

    await windowManager.unmaximize();

    Size newScreenSize = Size(screenSize.width, screenSize.height - 200);

    await windowManager.setSize(newScreenSize);

    await windowManager.setAlignment(Alignment.topCenter);

    Settings.isWindowMaximizable = false;
    Settings.isWindowDraggable = false;
    await windowManager.setResizable(false);

    await windowManager.setAsFrameless();
  }

  @override
  Future<void> onDriverStationUndocked() async {
    Settings.isWindowMaximizable = true;
    Settings.isWindowDraggable = true;
    await windowManager.setResizable(true);

    // Re-adds the window frame, window manager's API for this is weird
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
  }

  @override
  void showWindowCloseConfirmation(BuildContext context) {
    if (state == null) {
      logger.warning(
        'Attempting to show window closing confirmation while state is null',
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes, are you sure you want to continue? All unsaved changes will be lost!',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await saveLayout();

              Future.delayed(
                const Duration(milliseconds: 250),
                () async => await state!.closeWindow(),
              );
            },
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () async {
              await state!.closeWindow();
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
