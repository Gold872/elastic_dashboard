import 'dart:io';

import 'package:flutter/material.dart';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/settings_dialog.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';

mixin DashboardPageSettings on DashboardPageViewModel {
  @override
  void displaySettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        ntConnection: ntConnection,
        preferences: preferences,
        onTeamNumberChanged: changeTeamNumber,
        onIPAddressModeChanged: (mode) async {
          if (mode.index == preferences.getInt(PrefKeys.ipAddressMode)) {
            return;
          }

          changeIPAddressMode(mode);
        },
        onIPAddressChanged: (String? data) async {
          if (data == null ||
              data == preferences.getString(PrefKeys.ipAddress)) {
            return;
          }

          updateIPAddress(data);
        },
        onLayoutPortChanged: onLayoutPortChanged,
        onGridToggle: toggleGrid,
        onGridSizeChanged: changeGridSize,
        onCornerRadiusChanged: changeCornerRadius,
        onResizeToDSChanged: changeResizeToDS,
        onRememberWindowPositionChanged: changeRememberWindowPosition,
        onLayoutLock: changeLayoutLock,
        onDefaultPeriodChanged: changeDefaultPeriod,
        onDefaultGraphPeriodChanged: changeDefaultGraphPeriod,
        onColorChanged: onColorChanged,
        onThemeVariantChanged: onThemeVariantChanged,
        onLogLevelChanged: changeLogLevel,
        onGridDPIChanged: changeGridDPI,
        onAutoSubmitButtonChanged: changeAutoSubmitButton,
        onOpenAssetsFolderPressed: () async {
          Uri uri = Uri.file(
            '${path.dirname(Platform.resolvedExecutable)}/data/flutter_assets/assets/',
          );
          if (await canLaunchUrl(uri)) {
            logger.info('Opening URL (assets folder): ${uri.toString()}');
            launchUrl(uri);
          }
        },
      ),
    );
  }

  Future<void> changeTeamNumber(String? data) async {
    if (data == null) {
      return;
    }

    int? newTeamNumber = int.tryParse(data);

    if (newTeamNumber == null ||
        (newTeamNumber == preferences.getInt(PrefKeys.teamNumber))) {
      return;
    }

    await preferences.setInt(PrefKeys.teamNumber, newTeamNumber);

    switch (IPAddressMode.fromIndex(
      preferences.getInt(PrefKeys.ipAddressMode),
    )) {
      case IPAddressMode.roboRIOmDNS:
        updateIPAddress(IPAddressUtil.teamNumberToRIOmDNS(newTeamNumber));
        break;
      case IPAddressMode.teamNumber:
        updateIPAddress(IPAddressUtil.teamNumberToIP(newTeamNumber));
        break;
      default:
        notifyListeners();
        break;
    }
  }

  Future<void> onLayoutPortChanged(String? data) async {
    if (data == null) {
      return;
    }

    int? newPort = int.tryParse(data);

    if (newPort == null ||
        (newPort.toString() == preferences.getString(PrefKeys.layoutPort))) {
      return;
    }
    if (newPort < 1 || newPort > 65535) {
      logger.warning('User entered an invalid port: $newPort');
      await showDialog(
        context: state!.context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Port'),
          content: const Text('Please enter a valid port number (1-65535).'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Okay'),
            ),
          ],
        ),
      );
      return;
    }
    bool allowedPort =
        newPort == 80 ||
        (newPort >= 1180 && newPort <= 1190) ||
        (newPort >= 5800 && newPort <= 5810);

    if (!allowedPort) {
      logger.warning('User entered a potentially unsafe port: $newPort');
      bool? proceed = await showDialog<bool>(
        context: state!.context,
        builder: (context) => AlertDialog(
          title: const Text('Warning'),
          content: const Text(
            'The port you entered is blocked by the FMS firewall (see rule R704). \nOnly continue if you know what you\'re doing.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abort'),
            ),
          ],
        ),
      );

      if (proceed != true) {
        return;
      }
    }

    await preferences.setString(PrefKeys.layoutPort, newPort.toString());
    notifyListeners();
  }

  Future<void> toggleGrid(bool value) async {
    await preferences.setBool(PrefKeys.showGrid, value);

    notifyListeners();
  }

  Future<void> changeGridSize(String? gridSize) async {
    if (state == null) {
      logger.warning('Attempting to change grid size while state is null');
      return;
    }
    if (gridSize == null) {
      return;
    }

    int? newGridSize = int.tryParse(gridSize);

    if (newGridSize == null ||
        newGridSize == 0 ||
        newGridSize == this.gridSize) {
      return;
    }

    bool? cancel =
        await showDialog<bool>(
          context: state!.context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.yellow),
                SizedBox(width: 5),
                Text('Grid Resizing Warning'),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resizing the grid may cause widgets to become misaligned due to sizing constraints. Manual work may be required after resizing.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Okay'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ) ??
        true;

    if (cancel) {
      return;
    }

    int oldGridSize = this.gridSize;
    this.gridSize = newGridSize;

    await preferences.setInt(PrefKeys.gridSize, newGridSize);

    for (TabGridModel grid in tabData.map((e) => e.tabGrid)) {
      grid.resizeGrid(oldGridSize, newGridSize);
    }

    notifyListeners();
  }

  Future<void> changeCornerRadius(String? radius) async {
    if (radius == null) {
      return;
    }

    double? newRadius = double.tryParse(radius);

    if (newRadius == null ||
        newRadius == preferences.getDouble(PrefKeys.cornerRadius)) {
      return;
    }

    await preferences.setDouble(PrefKeys.cornerRadius, newRadius);

    for (TabGridModel grid in tabData.map((e) => e.tabGrid)) {
      grid.refreshAllContainers();
    }
    notifyListeners();
  }

  Future<void> changeResizeToDS(bool value) async {
    if (value && ntConnection.dsClient.driverStationDocked) {
      onDriverStationDocked();
    } else {
      onDriverStationUndocked();
    }

    await preferences.setBool(PrefKeys.autoResizeToDS, value);
    notifyListeners();
  }

  Future<void> changeRememberWindowPosition(bool value) async {
    await preferences.setBool(PrefKeys.rememberWindowPosition, value);
  }

  Future<void> changeLayoutLock(bool value) async {
    if (value) {
      lockLayout();
    } else {
      unlockLayout();
    }
    notifyListeners();
  }

  Future<void> changeDefaultPeriod(String? value) async {
    if (value == null) {
      return;
    }
    double? newPeriod = double.tryParse(value);

    if (newPeriod == null ||
        newPeriod == preferences.getDouble(PrefKeys.defaultPeriod)) {
      return;
    }

    await preferences.setDouble(PrefKeys.defaultPeriod, newPeriod);

    notifyListeners();
  }

  Future<void> changeDefaultGraphPeriod(String? value) async {
    if (value == null) {
      return;
    }
    double? newPeriod = double.tryParse(value);

    if (newPeriod == null ||
        newPeriod == preferences.getDouble(PrefKeys.defaultGraphPeriod)) {
      return;
    }

    await preferences.setDouble(PrefKeys.defaultGraphPeriod, newPeriod);

    notifyListeners();
  }

  Future<void> changeLogLevel(Level? level) async {
    if (level == null) {
      logger.info('Removing log level preference');
      await preferences.remove(PrefKeys.logLevel);
      Logger.level = Defaults.logLevel;
      return;
    }
    logger.info('Changing log level to ${level.levelName}');
    Logger.level = level;
    await preferences.setString(PrefKeys.logLevel, level.levelName);
  }

  Future<void> changeGridDPI(String? value) async {
    if (value == null) {
      return;
    }
    num? dpiOverride = double.tryParse(value) ?? int.tryParse(value);
    if (dpiOverride != null && dpiOverride <= 0) {
      return;
    }
    if (dpiOverride != null) {
      logger.info('Setting DPI override to ${dpiOverride.toDouble()}');
      await preferences.setDouble(
        PrefKeys.gridDpiOverride,
        dpiOverride.toDouble(),
      );
    } else {
      logger.info('Removing DPI override preference');
      await preferences.remove(PrefKeys.gridDpiOverride);
    }
    notifyListeners();
  }

  Future<void> changeAutoSubmitButton(bool value) async {
    await preferences.setBool(PrefKeys.autoTextSubmitButton, value);
    notifyListeners();
  }

  @override
  Future<void> changeIPAddressMode(IPAddressMode mode) async {
    await preferences.setInt(PrefKeys.ipAddressMode, mode.index);
    switch (mode) {
      case IPAddressMode.driverStation:
        String? lastAnnouncedIP = ntConnection.dsClient.lastAnnouncedIP;

        if (lastAnnouncedIP == null) {
          break;
        }

        updateIPAddress(lastAnnouncedIP);
        break;
      case IPAddressMode.roboRIOmDNS:
        updateIPAddress(
          IPAddressUtil.teamNumberToRIOmDNS(
            preferences.getInt(PrefKeys.teamNumber) ?? Defaults.teamNumber,
          ),
        );
        break;
      case IPAddressMode.teamNumber:
        updateIPAddress(
          IPAddressUtil.teamNumberToIP(
            preferences.getInt(PrefKeys.teamNumber) ?? Defaults.teamNumber,
          ),
        );
        break;
      case IPAddressMode.localhost:
        updateIPAddress('localhost');
        break;
      default:
        notifyListeners();
        break;
    }
  }

  @override
  Future<void> updateIPAddress(String newIPAddress) async {
    if (newIPAddress == preferences.getString(PrefKeys.ipAddress)) {
      return;
    }
    await preferences.setString(PrefKeys.ipAddress, newIPAddress);

    ntConnection.changeIPAddress(newIPAddress);
    notifyListeners();
  }
}
