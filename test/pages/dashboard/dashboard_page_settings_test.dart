import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/pages/dashboard/dashboard_page_settings.dart';
import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import '../../test_util.dart';
import '../../test_util.mocks.dart';

class SettingsDashboardViewModel = DashboardPageViewModel
    with DashboardPageSettings;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late SettingsDashboardViewModel dashboardModel;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PrefKeys.teamNumber: 353,
      PrefKeys.ipAddress: '10.3.53.2',
    });

    preferences = await SharedPreferences.getInstance();

    dashboardModel = SettingsDashboardViewModel(
      ntConnection: createMockOfflineNT4(),
      preferences: preferences,
      version: '0.0.0.0',
    );
  });

  group('[Team Number]:', () {
    test('Changing with null data does nothing', () async {
      await dashboardModel.changeTeamNumber(null);

      expect(preferences.getInt(PrefKeys.teamNumber), 353);
    });
    test('Changing with valid data', () async {
      await dashboardModel.changeTeamNumber('2053');

      expect(preferences.getInt(PrefKeys.teamNumber), 2053);
    });
    group('Changing with IP address mode:', () {
      test('Driver station', () async {
        await preferences.setInt(
          PrefKeys.ipAddressMode,
          IPAddressMode.driverStation.id,
        );
        await dashboardModel.changeTeamNumber('2053');
        // If driver station is disconnect, it does not change from the team number
        expect(preferences.getString(PrefKeys.ipAddress), '10.3.53.2');
      });
      test('Team number', () async {
        await preferences.setInt(
          PrefKeys.ipAddressMode,
          IPAddressMode.teamNumber.id,
        );
        await dashboardModel.changeTeamNumber('2053');
        expect(preferences.getString(PrefKeys.ipAddress), '10.20.53.2');
      });
    });
  });

  group('[IP Address Mode]:', () {
    group('Changing IP address mode to', () {
      setUp(() async {
        await preferences.setString(PrefKeys.ipAddress, '10.3.53.2');

        MockNTConnection mockConnection = createMockOfflineNT4();
        when(mockConnection.dsClient).thenReturn(MockDSInteropClient());

        dashboardModel = SettingsDashboardViewModel(
          ntConnection: mockConnection,
          preferences: preferences,
          version: '0.0.0.0',
        );
      });
      test('Driver Station', () async {
        await dashboardModel.changeIPAddressMode(IPAddressMode.driverStation);

        expect(preferences.getString(PrefKeys.ipAddress), '10.3.53.2');
      });
      test('SystemCore Wifi', () async {
        await dashboardModel.changeIPAddressMode(IPAddressMode.systemCoreAP);

        expect(preferences.getString(PrefKeys.ipAddress), '172.30.0.1');
      });
      test('SystemCore mDNS', () async {
        await dashboardModel.changeIPAddressMode(IPAddressMode.systemCoremDNS);

        expect(preferences.getString(PrefKeys.ipAddress), 'robot.local');
      });
    });
  });

  test('NT Target Server', () async {
    await preferences.setInt(
      PrefKeys.ntTargetServer,
      NTServerTarget.robotCode.index,
    );
    await dashboardModel.changeNTTargetServer(NTServerTarget.robotCode);

    expect(
      preferences.getInt(PrefKeys.ntTargetServer),
      NTServerTarget.robotCode.index,
    );

    await dashboardModel.changeNTTargetServer(NTServerTarget.systemCore);

    expect(
      preferences.getInt(PrefKeys.ntTargetServer),
      NTServerTarget.systemCore.index,
    );
  });

  test('Toggle Grid', () async {
    await dashboardModel.toggleGrid(true);
    expect(preferences.getBool(PrefKeys.showGrid), true);

    await dashboardModel.toggleGrid(false);
    expect(preferences.getBool(PrefKeys.showGrid), false);
  });

  group('[Grid Size]:', () {
    setUp(() async {
      await preferences.setInt(PrefKeys.gridSize, 64);
    });

    test('Changing with null data does nothing', () async {
      dashboardModel.changeGridSize(null);

      expect(preferences.getInt(PrefKeys.gridSize), 64);
    });

    testWidgets('Pressing okay updates preference', (widgetTester) async {
      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DashboardPage(model: dashboardModel)),
        ),
      );

      dashboardModel.changeGridSize('128');

      await widgetTester.pumpAndSettle();

      expect(find.text('Grid Resizing Warning'), findsOneWidget);

      final okayButton = find.widgetWithText(TextButton, 'Okay');

      expect(okayButton, findsOneWidget);
      await widgetTester.tap(okayButton);
      await widgetTester.pumpAndSettle();

      expect(preferences.getInt(PrefKeys.gridSize), 128);
    });

    testWidgets('Pressing cancel does nothing', (widgetTester) async {
      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DashboardPage(model: dashboardModel)),
        ),
      );

      dashboardModel.changeGridSize('128');

      await widgetTester.pumpAndSettle();

      expect(find.text('Grid Resizing Warning'), findsOneWidget);

      final cancelButton = find.widgetWithText(TextButton, 'Cancel');

      expect(cancelButton, findsOneWidget);
      await widgetTester.tap(cancelButton);
      await widgetTester.pumpAndSettle();

      expect(preferences.getInt(PrefKeys.gridSize), 64);
    });
  });

  group('[Corner Radius]:', () {
    setUp(() async {
      await preferences.setDouble(PrefKeys.cornerRadius, 25);
    });

    test('Changing with null data does nothing', () async {
      await dashboardModel.changeCornerRadius(null);
      expect(preferences.getDouble(PrefKeys.cornerRadius), 25);
    });

    test('Changing with valid data', () async {
      await dashboardModel.changeCornerRadius('10');
      expect(preferences.getDouble(PrefKeys.cornerRadius), 10);
    });
  });

  group('[Default Period]:', () {
    setUp(() async {
      await preferences.setDouble(PrefKeys.defaultPeriod, 0.1);
    });

    test('Changing with null data does nothing', () async {
      await dashboardModel.changeDefaultPeriod(null);
      expect(preferences.getDouble(PrefKeys.defaultPeriod), 0.1);
    });

    test('Changing with valid data', () async {
      await dashboardModel.changeDefaultPeriod('0.25');
      expect(preferences.getDouble(PrefKeys.defaultPeriod), 0.25);
    });
  });

  group('[Default Graph Period]:', () {
    setUp(() async {
      await preferences.setDouble(PrefKeys.defaultGraphPeriod, 0.1);
    });

    test('Changing with null data does nothing', () async {
      await dashboardModel.changeDefaultGraphPeriod(null);
      expect(preferences.getDouble(PrefKeys.defaultGraphPeriod), 0.1);
    });

    test('Changing with valid data', () async {
      await dashboardModel.changeDefaultGraphPeriod('0.25');
      expect(preferences.getDouble(PrefKeys.defaultGraphPeriod), 0.25);
    });
  });

  test('Remember window position', () async {
    await preferences.setBool(PrefKeys.rememberWindowPosition, false);

    await dashboardModel.changeRememberWindowPosition(true);
    expect(preferences.getBool(PrefKeys.rememberWindowPosition), true);

    await dashboardModel.changeRememberWindowPosition(false);
    expect(preferences.getBool(PrefKeys.rememberWindowPosition), false);
  });

  group('[Log Level]:', () {
    setUp(() async {
      await preferences.setString(PrefKeys.logLevel, Level.info.levelName);
    });

    test('Setting to null (automatic) removes key', () async {
      await dashboardModel.changeLogLevel(null);

      expect(preferences.containsKey(PrefKeys.logLevel), isFalse);
    });

    test('Setting to trace', () async {
      await dashboardModel.changeLogLevel(Level.trace);

      expect(preferences.getString(PrefKeys.logLevel), 'Trace');
      expect(Logger.level, Level.trace);
    });
  });

  group('[DPI Override]:', () {
    setUp(() async {
      await preferences.setDouble(PrefKeys.gridDpiOverride, 1);
    });

    test('Setting to null does nothing', () async {
      await dashboardModel.changeGridDPI(null);

      expect(preferences.containsKey(PrefKeys.gridDpiOverride), isTrue);
      expect(preferences.getDouble(PrefKeys.gridDpiOverride), 1);
    });

    test('Setting to empty removes key', () async {
      await dashboardModel.changeGridDPI('');

      expect(preferences.containsKey(PrefKeys.gridDpiOverride), isFalse);
    });

    test('Setting to negative value does nothing', () async {
      await dashboardModel.changeGridDPI('-1');

      expect(preferences.getDouble(PrefKeys.gridDpiOverride), 1);
    });

    test('Setting to positive value', () async {
      await dashboardModel.changeGridDPI('1.25');

      expect(preferences.getDouble(PrefKeys.gridDpiOverride), 1.25);
    });
  });
}
