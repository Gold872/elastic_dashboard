import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:dot_cast/dot_cast.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/app_distributor.dart';
import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/services/settings.dart';

import 'package:path_provider/path_provider.dart'
    if (dart.library.js_interop) 'package:elastic_dashboard/util/stub/path_stub.dart';
import 'package:screen_retriever/screen_retriever.dart'
    if (dart.library.js_interop) 'package:elastic_dashboard/util/stub/screen_stub.dart';
import 'package:window_manager/window_manager.dart'
    if (dart.library.js_interop) 'package:elastic_dashboard/util/stub/window_stub.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    BrowserContextMenu.disableContextMenu();
  }

  final PackageInfo packageInfo = await PackageInfo.fromPlatform();

  await logger.initialize();

  logger.info('Starting application: Version ${packageInfo.version}');

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    logger.error('Flutter Error', details.exception, details.stack);
  };

  SharedPreferences preferences;
  if (!kIsWeb) {
    final String appFolderPath = (await getApplicationSupportDirectory()).path;
    // Prevents data loss if shared_preferences.json gets corrupted
    // More info and original implementation: https://github.com/flutter/flutter/issues/89211#issuecomment-915096452
    try {
      preferences = await SharedPreferences.getInstance();

      // Store a copy of user's preferences on the disk
      await _backupPreferences(appFolderPath);
    } catch (error) {
      logger.warning(
        'Failed to get shared preferences instance, attempting to retrieve from backup',
        error,
      );

      // Remove broken preferences files and restore previous settings
      await _restorePreferencesFromBackup(appFolderPath);
      preferences = await SharedPreferences.getInstance();
    }
  } else {
    preferences = await SharedPreferences.getInstance();
  }

  Level logLevel =
      Settings.logLevels.firstWhereOrNull(
        (level) => level.levelName == preferences.getString(PrefKeys.logLevel),
      ) ??
      Defaults.logLevel;
  Logger.level = logLevel;

  NTWidgetRegistry.ensureInitialized();

  String ipAddress =
      preferences.getString(PrefKeys.ipAddress) ?? Defaults.ipAddress;

  NTServerTarget serverMode =
      NTServerTarget.fromIndex(preferences.getInt(PrefKeys.ntTargetServer)) ??
      Defaults.targetServer;

  NTConnection ntConnection = NTConnection(ipAddress, serverMode);

  LicenseRegistry.addLicense(() async* {
    final robotoLicense = await rootBundle.loadString(
      'assets/third_party_licenses/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(['google_fonts'], robotoLicense);

    final advantageScopeLicense = await rootBundle.loadString(
      'assets/third_party_licenses/AdvantageScopeAssets.txt',
    );
    yield LicenseEntryWithLineBreaks([
      'advantagescope_assets',
    ], advantageScopeLicense);
  });

  await FieldImages.loadFields('assets/fields/');
  if (!kIsWeb) {
    Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
    Size screenSize = primaryDisplay.visibleSize ?? primaryDisplay.size;

    logger.debug('Display Information: - Screen Size: $screenSize');

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

    final Size minimumSize = Size(436.5 + platformWidthAdjust, 320.0);

    await windowManager.ensureInitialized();

    await windowManager.setMinimumSize(minimumSize);
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    if (preferences.getBool(PrefKeys.rememberWindowPosition) ?? false) {
      await _restoreWindowPosition(preferences, primaryDisplay, minimumSize);
    }

    await windowManager.show();
    await windowManager.focus();
  }

  runApp(
    Elastic(
      ntConnection: ntConnection,
      preferences: preferences,
      version: packageInfo.version,
    ),
  );
}

Future<void> _restoreWindowPosition(
  SharedPreferences preferences,
  Display primaryDisplay,
  Size minimumSize,
) async {
  String? positionString = preferences.getString(PrefKeys.windowPosition);

  if (positionString == null) {
    return;
  }

  List<Object?>? rawPosition = tryCast(jsonDecode(positionString));

  if (rawPosition == null || rawPosition.length < 4) {
    return;
  }

  List<double> position = rawPosition
      .whereType<num>()
      .map((n) => n.toDouble())
      .toList();

  if (position.length < 4) {
    return;
  }

  double x = position[0];
  double y = position[1];
  double width = position[2].clamp(
    minimumSize.width,
    primaryDisplay.size.width,
  );
  double height = position[3].clamp(
    minimumSize.height,
    primaryDisplay.size.height,
  );

  x = x.clamp(0.0, primaryDisplay.size.width);
  y = y.clamp(0.0, primaryDisplay.size.height);

  await windowManager.setBounds(Rect.fromLTWH(x, y, width, height));
}

/// Makes a backup copy of the current shared preferences file.
Future<void> _backupPreferences(String appFolderPath) async {
  try {
    final String original = '$appFolderPath\\shared_preferences.json';
    final String backup = '$appFolderPath\\shared_preferences_backup.json';

    if (await File(backup).exists()) await File(backup).delete(recursive: true);
    await File(original).copy(backup);

    logger.info('Backed up shared_preferences.json to $backup');
  } catch (_) {
    /* Do nothing */
  }
}

/// Removes current version of shared_preferences file and restores previous
/// user settings from a backup file (if it exists).
Future<void> _restorePreferencesFromBackup(String appFolderPath) async {
  try {
    final String original = '$appFolderPath\\shared_preferences.json';
    final String backup = '$appFolderPath\\shared_preferences_backup.json';

    await File(original).delete(recursive: true);

    if (await File(backup).exists()) {
      // Check if current backup copy is not broken by looking for letters and "
      // symbol in it to replace it as an original Settings file
      final String preferences = await File(backup).readAsString();
      if (preferences.contains('"') && preferences.contains(RegExp('[A-z]'))) {
        logger.info('Restoring shared_preferences from backup file at $backup');
        await File(backup).copy(original);
      }
    }
  } catch (_) {
    /* Do nothing */
  }
}

class Elastic extends StatefulWidget {
  final NTConnection ntConnection;
  final SharedPreferences preferences;
  final String version;

  const Elastic({
    super.key,
    required this.ntConnection,
    required this.preferences,
    required this.version,
  });

  @override
  State<Elastic> createState() => _ElasticState();
}

class _ElasticState extends State<Elastic> {
  late Color teamColor = Color(
    widget.preferences.getInt(PrefKeys.teamColor) ??
        Colors.blueAccent.toARGB32(),
  );
  late FlexSchemeVariant themeVariant =
      FlexSchemeVariant.values.firstWhereOrNull(
        (element) =>
            element.variantName ==
            widget.preferences.getString(PrefKeys.themeVariant),
      ) ??
      FlexSchemeVariant.material3Legacy;

  late final DashboardPageViewModel dashboardViewModel =
      DashboardPageViewModelImpl(
        ntConnection: widget.ntConnection,
        preferences: widget.preferences,
        version: widget.version,
        onColorChanged: (color) => setState(() {
          teamColor = color;
          widget.preferences.setInt(PrefKeys.teamColor, color.toARGB32());
        }),
        onThemeVariantChanged: (variant) async {
          themeVariant = variant;
          if (variant == Defaults.themeVariant) {
            await widget.preferences.setString(
              PrefKeys.themeVariant,
              Defaults.defaultVariantName,
            );
          } else {
            await widget.preferences.setString(
              PrefKeys.themeVariant,
              variant.variantName,
            );
          }
          setState(() {});
        },
      );

  FlexTones get themeTones => themeVariant.tones(Brightness.dark);

  @override
  Widget build(BuildContext context) {
    ThemeData theme = ThemeData(
      useMaterial3: true,
      colorScheme: SeedColorScheme.fromSeeds(
        primaryKey: teamColor,
        brightness: Brightness.dark,
        tones: themeTones.copyWith(
          // Use older (but incorrect) material 3 legacy tones from 2025 version
          surfaceTone: themeVariant == FlexSchemeVariant.material3Legacy
              ? 8
              : null,
          primaryMinChroma: themeVariant == FlexSchemeVariant.material3Legacy
              ? 0
              : null,
          // Have the dialog color match the card colors
          surfaceContainerHighTone:
              themeVariant == FlexSchemeVariant.material3Legacy
              ? 8
              : themeTones.surfaceTone,
        ),
      ),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: appTitle,
      theme: theme,
      home: DashboardPage(model: dashboardViewModel),
    );
  }
}
