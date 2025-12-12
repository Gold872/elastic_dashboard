import 'package:flutter/foundation.dart';

import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:logger/logger.dart';

import 'package:elastic_dashboard/services/ip_address_util.dart';

extension LogLevelUtil on Level {
  String get levelName => switch (this) {
    Level.all => 'All',
    Level.trace => 'Trace',
    Level.debug => 'Debug',
    Level.info => 'Info',
    Level.warning => 'Warning',
    Level.error => 'Error',
    Level.fatal => 'Fatal',
    Level.off => 'Off',
    _ => 'Unknown',
  };
}

class Settings {
  static const String repositoryLink =
      'https://github.com/Gold872/elastic_dashboard';
  static const String releasesLink = '$repositoryLink/releases/latest';

  // window_manager doesn't support drag disable/maximize
  // disable on some platforms, this is a dumb workaround for it
  static bool isWindowDraggable = true;
  static bool isWindowMaximizable = true;

  static final List<Level> logLevels = Level.values
      .where((level) => level.value % 1000 == 0)
      .toList();
}

class Defaults {
  static String defaultIPForPlatform() {
    if (kIsWeb) {
      return Uri.base.host;
    }
    return '127.0.0.1';
  }

  static IPAddressMode ipAddressMode = IPAddressMode.driverStation;

  static FlexSchemeVariant themeVariant = FlexSchemeVariant.material3Legacy;

  static const String defaultVariantName = 'Material-3 Legacy (Default)';
  static const String defaultLogLevelName = 'Automatic';
  static const Level logLevel = kDebugMode ? Level.debug : Level.info;
  static final String ipAddress = defaultIPForPlatform();

  static const int teamNumber = 9999;
  static const int gridSize = 128;

  static const bool layoutLocked = false;
  static const bool showGrid = true;
  static const bool autoResizeToDS = false;
  static const bool showOpenAssetsFolderWarning = true;

  static const double cornerRadius = 15.0;
  static const double defaultPeriod = 0.06;
  static const double defaultGraphPeriod = 0.033;
}

class PrefKeys {
  static String layout = 'layout';
  static String ipAddress = 'ip_address';
  static String ipAddressMode = 'ip_address_mode';
  static String teamNumber = 'team_number';
  static String teamColor = 'team_color';
  static String themeVariant = 'theme_variant';
  static String layoutLocked = 'layout_locked';
  static String gridSize = 'grid_size';
  static String cornerRadius = 'corner_radius';
  static String showGrid = 'show_grid';
  static String autoResizeToDS = 'auto_resize_to_driver_station';
  static String rememberWindowPosition = 'remember_window_position';
  static String defaultPeriod = 'default_period';
  static String defaultGraphPeriod = 'default_graph_period';
  static String logLevel = 'log_level';
  static String gridDpiOverride = 'grid_dpi_override';
  static String windowPosition = 'window_position';
  static String autoTextSubmitButton = 'auto_text_submit_button';
}
