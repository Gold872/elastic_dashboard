import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titlebar_buttons/titlebar_buttons.dart';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/elastic_layout_downloader.dart';
import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/services/hotkey_manager.dart';
import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/services/update_checker.dart';
import 'package:elastic_dashboard/widgets/custom_appbar.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/layout_drag_tile.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_list_layout.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_dialog.dart';
import 'package:elastic_dashboard/widgets/editable_tab_bar.dart';
import 'package:elastic_dashboard/widgets/network_tree/networktables_tree.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/gyro.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/boolean_box.dart';
import 'package:elastic_dashboard/widgets/settings_dialog.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';
import '../services/elastic_layout_downloader_test.dart';
import '../test_util.dart';
import '../test_util.mocks.dart';

Future<void> pumpDashboardPage(
  WidgetTester widgetTester,
  SharedPreferences preferences, {
  NTConnection? ntConnection,
  ElasticLayoutDownloader? layoutDownloader,
  UpdateChecker? updateChecker,
  Size? size = const Size(1920, 1080),
}) async {
  FlutterError.onError = ignoreOverflowErrors;
  if (size != null) {
    widgetTester.view.physicalSize = size;
    widgetTester.view.devicePixelRatio = 1.0;
  }

  await widgetTester.pumpWidget(
    MaterialApp(
      home: DashboardPage(
        model: DashboardPageViewModelImpl(
          ntConnection: ntConnection ?? createMockOfflineNT4(),
          preferences: preferences,
          version: '0.0.0.0',
          updateChecker: updateChecker ?? createMockUpdateChecker(),
          layoutDownloader: layoutDownloader,
        ),
      ),
    ),
  );

  await widgetTester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String jsonFilePath =
      '${Directory.current.path}/test_resources/test-layout.json';

  late String jsonString;

  late SharedPreferences preferences;

  setUpAll(() async {
    await FieldImages.loadFields('assets/fields/');

    jsonString = jsonEncode(jsonDecode(File(jsonFilePath).readAsStringSync()));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PrefKeys.layout: jsonString,
      PrefKeys.teamNumber: 353,
      PrefKeys.ipAddress: '10.3.53.2',
    });

    preferences = await SharedPreferences.getInstance();
  });

  tearDown(() {
    hotKeyManager.tearDown();
  });

  group('[Responsive Layout]:', () {
    final fileButton = find.widgetWithText(SubmenuButton, 'File');
    final collapsedMenu = find.widgetWithIcon(SubmenuButton, Icons.menu);
    final title = find.text('Elastic');
    final teamNumber = find.text('Team 353');
    final latency = find.textContaining('Latency:');

    testWidgets('Shows everything on normal screen', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(fileButton, findsOneWidget);
      expect(collapsedMenu, findsNothing);
      expect(title, findsOneWidget);
      expect(teamNumber, findsOneWidget);
      expect(latency, findsOneWidget);
    });

    testWidgets('Hides title when width = 525', (widgetTester) async {
      await pumpDashboardPage(
        widgetTester,
        preferences,
        size: const Size(525, 525),
      );

      expect(title, findsNothing);
    });

    testWidgets('Hides team number when width = 500', (widgetTester) async {
      await pumpDashboardPage(
        widgetTester,
        preferences,
        size: const Size(500, 500),
      );

      expect(fileButton, findsOneWidget);
      expect(collapsedMenu, findsNothing);

      expect(teamNumber, findsNothing);
    });

    testWidgets('Collapses menu when width < 460', (widgetTester) async {
      await pumpDashboardPage(
        widgetTester,
        preferences,
        size: const Size(459.99, 459.99),
      );

      expect(fileButton, findsNothing);
      expect(collapsedMenu, findsOneWidget);
      expect(title, findsNothing);
    });

    testWidgets('Hides latency when width = 300', (widgetTester) async {
      await pumpDashboardPage(
        widgetTester,
        preferences,
        size: const Size(300, 300),
      );

      expect(fileButton, findsNothing);
      expect(collapsedMenu, findsOneWidget);
      expect(title, findsNothing);
      expect(teamNumber, findsNothing);
      expect(latency, findsNothing);
    });
  });

  group('[Loading and Saving]:', () {
    testWidgets('offline loading', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(
        find.textContaining('Network Tables: Disconnected'),
        findsOneWidget,
      );
      expect(find.textContaining('Network Tables: Connected'), findsNothing);
      expect(find.textContaining('(10.3.53.2)'), findsNothing);
      expect(find.text('Team 353'), findsOneWidget);

      expect(find.text('Teleoperated'), findsOneWidget);
      expect(find.text('Autonomous'), findsOneWidget);
    });

    testWidgets('online loading', (widgetTester) async {
      await pumpDashboardPage(
        widgetTester,
        preferences,
        ntConnection: createMockOnlineNT4(),
      );

      expect(find.textContaining('Network Tables: Disconnected'), findsNothing);
      expect(find.textContaining('Network Tables: Connected'), findsWidgets);
      expect(find.textContaining('(10.3.53.2)'), findsWidgets);
      expect(find.text('Team 353'), findsOneWidget);

      expect(find.text('Teleoperated'), findsOneWidget);
      expect(find.text('Autonomous'), findsOneWidget);
    });
  });

  group('[Adding Widgets]:', () {
    testWidgets('Add widget dialog search', (widgetTester) async {
      await pumpDashboardPage(
        widgetTester,
        preferences,
        ntConnection: createMockOnlineNT4(),
      );

      final addWidget = find.widgetWithText(MenuItemButton, 'Add Widget');

      expect(addWidget, findsOneWidget);
      expect(find.widgetWithText(DraggableDialog, 'Add Widget'), findsNothing);

      // widgetTester.tap() doesn't work :shrug:
      MenuItemButton addWidgetButton =
          addWidget.evaluate().first.widget as MenuItemButton;

      addWidgetButton.onPressed?.call();

      await widgetTester.pumpAndSettle();

      expect(
        find.widgetWithText(DraggableDialog, 'Add Widget'),
        findsOneWidget,
      );

      final smartDashboardTile = find.widgetWithText(
        TreeTile,
        'SmartDashboard',
      );

      expect(smartDashboardTile, findsOneWidget);

      await widgetTester.tap(smartDashboardTile);
      await widgetTester.pumpAndSettle();

      final searchQuery = find.widgetWithText(DialogTextInput, 'Search');
      expect(searchQuery, findsOneWidget);

      final testValueOne = find.widgetWithText(TreeTile, 'Test Value 1');
      final testValueTwo = find.widgetWithText(TreeTile, 'Test Value 2');

      expect(testValueOne, findsOneWidget);
      expect(testValueTwo, findsOneWidget);

      // Both match
      await widgetTester.enterText(searchQuery, 'Test Value');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);

      await widgetTester.pumpAndSettle();

      expect(testValueOne, findsOneWidget);
      expect(testValueTwo, findsOneWidget);

      // One match
      await widgetTester.enterText(searchQuery, 'Test Value 1');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);

      await widgetTester.pumpAndSettle();

      expect(testValueOne, findsOneWidget);
      expect(testValueTwo, findsNothing);
      expect(smartDashboardTile, findsOneWidget);

      // No matches
      await widgetTester.enterText(searchQuery, 'no match');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);

      await widgetTester.pumpAndSettle();

      expect(testValueOne, findsNothing);
      expect(testValueTwo, findsNothing);
      expect(smartDashboardTile, findsNothing);

      // Match only smart dashboard tile (all should show)
      await widgetTester.enterText(searchQuery, 'Smart');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);

      await widgetTester.pumpAndSettle();

      expect(testValueOne, findsOneWidget);
      expect(testValueTwo, findsOneWidget);
      expect(smartDashboardTile, findsOneWidget);

      // Empty text (both should be visible)
      await widgetTester.enterText(searchQuery, '');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);

      await widgetTester.pumpAndSettle();

      expect(testValueOne, findsOneWidget);
      expect(testValueTwo, findsOneWidget);
      expect(smartDashboardTile, findsOneWidget);
    });

    testWidgets('Add widget dialog (widgets)', (widgetTester) async {
      await pumpDashboardPage(
        widgetTester,
        preferences,
        ntConnection: createMockOnlineNT4(),
      );

      final addWidget = find.widgetWithText(MenuItemButton, 'Add Widget');

      expect(addWidget, findsOneWidget);
      expect(find.widgetWithText(DraggableDialog, 'Add Widget'), findsNothing);

      MenuItemButton addWidgetButton =
          addWidget.evaluate().first.widget as MenuItemButton;

      addWidgetButton.onPressed?.call();

      await widgetTester.pumpAndSettle();

      expect(
        find.widgetWithText(DraggableDialog, 'Add Widget'),
        findsOneWidget,
      );

      final smartDashboardTile = find.widgetWithText(
        TreeTile,
        'SmartDashboard',
      );

      expect(smartDashboardTile, findsOneWidget);

      await widgetTester.tap(smartDashboardTile);
      await widgetTester.pumpAndSettle();

      final testValueTile = find.widgetWithText(TreeTile, 'Test Value 1');
      final testValueContainer = find.widgetWithText(
        WidgetContainer,
        'Test Value 1',
      );

      expect(testValueTile, findsOneWidget);
      expect(testValueContainer, findsNothing);
      expect(find.widgetWithText(TreeTile, 'Test Value 2'), findsOneWidget);

      await widgetTester.drag(
        testValueTile,
        const Offset(100, 100),
        kind: PointerDeviceKind.mouse,
      );
      await widgetTester.pumpAndSettle();

      expect(testValueContainer, findsNothing);

      await widgetTester.drag(
        testValueTile,
        const Offset(300, -150),
        kind: PointerDeviceKind.mouse,
      );
      await widgetTester.pumpAndSettle();

      expect(testValueContainer, findsOneWidget);

      final dialogDragHandle = find.byIcon(Icons.drag_handle);

      expect(dialogDragHandle, findsOneWidget);

      await widgetTester.drag(dialogDragHandle, const Offset(100, 0));
      await widgetTester.pumpAndSettle();
    });

    testWidgets('Add widget dialog (layouts)', (widgetTester) async {
      await pumpDashboardPage(
        widgetTester,
        preferences,
        ntConnection: createMockOnlineNT4(),
      );

      final addWidget = find.widgetWithText(MenuItemButton, 'Add Widget');

      expect(addWidget, findsOneWidget);
      expect(find.widgetWithText(DraggableDialog, 'Add Widget'), findsNothing);

      MenuItemButton addWidgetButton =
          addWidget.evaluate().first.widget as MenuItemButton;

      addWidgetButton.onPressed?.call();

      await widgetTester.pumpAndSettle();

      expect(
        find.widgetWithText(DraggableDialog, 'Add Widget'),
        findsOneWidget,
      );

      final layoutsTab = find.text('Layouts');
      expect(layoutsTab, findsOneWidget);

      await widgetTester.tap(layoutsTab);
      await widgetTester.pumpAndSettle();

      final listLayoutContainer = find.widgetWithText(
        WidgetContainer,
        'List Layout',
      );
      expect(listLayoutContainer, findsNothing);

      final listLayoutTile = find.widgetWithText(LayoutDragTile, 'List Layout');
      expect(listLayoutTile, findsOneWidget);

      await widgetTester.drag(
        listLayoutTile,
        const Offset(100, 100),
        kind: PointerDeviceKind.mouse,
      );
      await widgetTester.pumpAndSettle();

      expect(listLayoutContainer, findsNothing);

      await widgetTester.drag(
        listLayoutTile,
        const Offset(300, -150),
        kind: PointerDeviceKind.mouse,
      );
      await widgetTester.pumpAndSettle();

      expect(listLayoutContainer, findsOneWidget);
    });

    testWidgets('Add widget dialog (list layout sub-table)', (
      widgetTester,
    ) async {
      await pumpDashboardPage(
        widgetTester,
        preferences,
        ntConnection: createMockOnlineNT4(
          virtualTopics: [
            NT4Topic(
              name: '/Non-Typed/Value 1',
              type: NT4Type.int(),
              properties: {},
            ),
            NT4Topic(
              name: '/Non-Typed/Value 2',
              type: NT4Type.int(),
              properties: {},
            ),
            NT4Topic(
              name: '/Non-Typed/Value 3',
              type: NT4Type.int(),
              properties: {},
            ),
          ],
        ),
      );

      final addWidget = find.widgetWithText(MenuItemButton, 'Add Widget');

      expect(addWidget, findsOneWidget);
      expect(find.widgetWithText(DraggableDialog, 'Add Widget'), findsNothing);

      MenuItemButton addWidgetButton =
          addWidget.evaluate().first.widget as MenuItemButton;

      addWidgetButton.onPressed?.call();

      await widgetTester.pumpAndSettle();

      expect(
        find.widgetWithText(DraggableDialog, 'Add Widget'),
        findsOneWidget,
      );

      final nonTypedTile = find.widgetWithText(TreeTile, 'Non-Typed');

      expect(nonTypedTile, findsOneWidget);

      final nonTypedContainer = find.widgetWithText(
        WidgetContainer,
        'Non-Typed',
      );
      expect(nonTypedContainer, findsNothing);

      await widgetTester.drag(
        nonTypedTile,
        const Offset(250, 0),
        kind: PointerDeviceKind.mouse,
      );
      await widgetTester.pumpAndSettle();

      expect(nonTypedContainer, findsOneWidget);
    });

    testWidgets('Add widget dialog (unregistered sendable)', (
      widgetTester,
    ) async {
      await pumpDashboardPage(
        widgetTester,
        preferences,
        ntConnection: createMockOnlineNT4(
          virtualTopics: [
            NT4Topic(
              name: '/Non-Registered/.type',
              type: NT4Type.string(),
              properties: {},
            ),
            NT4Topic(
              name: '/Non-Registered/Value 1',
              type: NT4Type.int(),
              properties: {},
            ),
            NT4Topic(
              name: '/Non-Registered/Value 2',
              type: NT4Type.int(),
              properties: {},
            ),
            NT4Topic(
              name: '/Non-Registered/Value 3',
              type: NT4Type.int(),
              properties: {},
            ),
          ],
          virtualValues: {'/Non-Registered/.type': 'Non Registered Type'},
        ),
      );

      final addWidget = find.widgetWithText(MenuItemButton, 'Add Widget');

      expect(addWidget, findsOneWidget);
      expect(find.widgetWithText(DraggableDialog, 'Add Widget'), findsNothing);

      MenuItemButton addWidgetButton =
          addWidget.evaluate().first.widget as MenuItemButton;

      addWidgetButton.onPressed?.call();

      await widgetTester.pumpAndSettle();

      expect(
        find.widgetWithText(DraggableDialog, 'Add Widget'),
        findsOneWidget,
      );

      final nonRegisteredTile = find.widgetWithText(TreeTile, 'Non-Registered');

      expect(nonRegisteredTile, findsOneWidget);

      final nonRegistered = find.widgetWithText(
        WidgetContainer,
        'Non-Registered',
      );
      expect(nonRegistered, findsNothing);

      await widgetTester.drag(
        nonRegisteredTile,
        const Offset(250, 0),
        kind: PointerDeviceKind.mouse,
      );
      await widgetTester.pumpAndSettle();

      expect(nonRegistered, findsOneWidget);
    });

    testWidgets('List Layouts', (widgetTester) async {
      await pumpDashboardPage(
        widgetTester,
        preferences,
        ntConnection: createMockOnlineNT4(),
        size: null,
      );

      final addWidget = find.widgetWithText(MenuItemButton, 'Add Widget');

      expect(addWidget, findsOneWidget);
      expect(find.widgetWithText(DraggableDialog, 'Add Widget'), findsNothing);

      MenuItemButton addWidgetButton =
          addWidget.evaluate().first.widget as MenuItemButton;

      addWidgetButton.onPressed?.call();

      await widgetTester.pumpAndSettle();

      expect(
        find.widgetWithText(DraggableDialog, 'Add Widget'),
        findsOneWidget,
      );

      final layoutsTab = find.text('Layouts');
      expect(layoutsTab, findsOneWidget);

      await widgetTester.tap(layoutsTab);
      await widgetTester.pumpAndSettle();

      final listLayoutContainer = find.widgetWithText(
        WidgetContainer,
        'List Layout',
      );
      expect(listLayoutContainer, findsNothing);

      final listLayoutTile = find.widgetWithText(LayoutDragTile, 'List Layout');
      expect(listLayoutTile, findsOneWidget);

      await widgetTester.drag(
        listLayoutTile,
        const Offset(100, 100),
        kind: PointerDeviceKind.mouse,
      );
      await widgetTester.pumpAndSettle();

      expect(listLayoutContainer, findsNothing);

      await widgetTester.drag(
        listLayoutTile,
        const Offset(300, -150),
        kind: PointerDeviceKind.mouse,
      );
      await widgetTester.pumpAndSettle();

      expect(listLayoutContainer, findsOneWidget);

      final closeButton = find.widgetWithText(TextButton, 'Close');
      expect(closeButton, findsOneWidget);

      await widgetTester.tap(closeButton);
      await widgetTester.pumpAndSettle();

      final listLayout = find.ancestor(
        of: find.widgetWithText(WidgetContainer, 'List Layout'),
        matching: find.byType(DraggableListLayout),
      );
      expect(listLayout, findsOneWidget);

      final testBooleanContainer = find.widgetWithText(
        WidgetContainer,
        'Test Boolean',
      );
      expect(testBooleanContainer, findsOneWidget);

      final testBooleanInLayout = find.descendant(
        of: find.widgetWithText(WidgetContainer, 'List Layout'),
        matching: find.byType(BooleanBox),
      );

      expect(testBooleanInLayout, findsNothing);

      // Drag into layout
      await widgetTester.timedDrag(
        testBooleanContainer,
        const Offset(250, 32),
        const Duration(milliseconds: 500),
      );
      await widgetTester.pumpAndSettle();

      expect(testBooleanInLayout, findsOneWidget);

      // Drag out of layout
      await widgetTester.timedDrag(
        testBooleanInLayout,
        const Offset(-200, -60),
        const Duration(milliseconds: 500),
      );
      await widgetTester.pumpAndSettle();

      expect(testBooleanInLayout, findsNothing);
    });
  });

  group('[ElasticLib]', () {
    group('[Remote Layouts]:', () {
      setUp(() async {
        SharedPreferences.setMockInitialValues({
          PrefKeys.ipAddress: '127.0.0.1',
          PrefKeys.layoutLocked: false,
        });

        preferences = await SharedPreferences.getInstance();
      });

      testWidgets('Shows list of layouts', (widgetTester) async {
        Client mockClient = createHttpClient(
          mockGetResponses: {
            'http://127.0.0.1:5800/?format=json': Response(
              jsonEncode(layoutFiles),
              200,
            ),
          },
        );

        ElasticLayoutDownloader layoutDownloader = ElasticLayoutDownloader(
          mockClient,
        );

        await pumpDashboardPage(
          widgetTester,
          preferences,
          ntConnection: createMockOnlineNT4(),
          layoutDownloader: layoutDownloader,
        );

        expect(find.text('File'), findsOneWidget);
        await widgetTester.tap(find.text('File'));
        await widgetTester.pumpAndSettle();

        expect(find.text('Download From Robot'), findsOneWidget);
        await widgetTester.tap(find.text('Download From Robot'));
        await widgetTester.pumpAndSettle();

        expect(find.text('Select Layout'), findsOneWidget);
        expect(find.byType(DialogDropdownChooser<String>), findsOneWidget);

        await widgetTester.tap(find.byType(DialogDropdownChooser<String>));
        await widgetTester.pumpAndSettle();

        expect(find.text('elastic-layout 1'), findsOneWidget);
        expect(find.text('elastic-layout 2'), findsOneWidget);
      });

      group('Download layout', () {
        testWidgets('shows help text', (widgetTester) async {
          Client mockClient = createHttpClient(
            mockGetResponses: {
              'http://127.0.0.1:5800/?format=json': Response(
                jsonEncode(layoutFiles),
                200,
              ),
            },
          );

          ElasticLayoutDownloader layoutDownloader = ElasticLayoutDownloader(
            mockClient,
          );

          await pumpDashboardPage(
            widgetTester,
            preferences,
            ntConnection: createMockOnlineNT4(),
            layoutDownloader: layoutDownloader,
          );

          expect(find.text('File'), findsOneWidget);
          await widgetTester.tap(find.text('File'));
          await widgetTester.pumpAndSettle();

          expect(find.text('Download From Robot'), findsOneWidget);
          await widgetTester.tap(find.text('Download From Robot'));
          await widgetTester.pumpAndSettle();

          expect(find.textContaining('Keeps existing tabs'), findsNothing);

          final helpButton = find.byIcon(Icons.help_outline);

          expect(helpButton, findsOneWidget);
          await widgetTester.ensureVisible(helpButton);
          await widgetTester.tap(helpButton);
          await widgetTester.pumpAndSettle();

          expect(find.textContaining('Keeps existing tabs'), findsOneWidget);
        });

        testWidgets('overwrite mode', (widgetTester) async {
          Client mockClient = createHttpClient(
            mockGetResponses: {
              'http://127.0.0.1:5800/?format=json': Response(
                jsonEncode(layoutFiles),
                200,
              ),
              'http://127.0.0.1:5800/${Uri.encodeComponent('elastic-layout 1.json')}':
                  Response(jsonEncode(layoutOne), 200),
            },
          );

          ElasticLayoutDownloader layoutDownloader = ElasticLayoutDownloader(
            mockClient,
          );

          SharedPreferences.setMockInitialValues({
            PrefKeys.layout: jsonEncode({
              'version': 1.0,
              'grid_size': 128.0,
              'tabs': [
                {
                  'name': 'Test Tab',
                  'grid_layout': {
                    'layouts': [],
                    'containers': [
                      {
                        'title': 'Blocking Widget',
                        'x': 384.0,
                        'y': 128.0,
                        'width': 256.0,
                        'height': 256.0,
                        'type': 'Text Display',
                        'properties': {
                          'topic': '/Test Tab/Blocking Widget',
                          'period': 0.06,
                        },
                      },
                    ],
                  },
                },
              ],
            }),
            PrefKeys.ipAddress: '127.0.0.1',
          });

          SharedPreferences preferences = await SharedPreferences.getInstance();

          await pumpDashboardPage(
            widgetTester,
            preferences,
            ntConnection: createMockOnlineNT4(),
            layoutDownloader: layoutDownloader,
          );

          expect(find.text('File'), findsOneWidget);
          await widgetTester.tap(find.text('File'));
          await widgetTester.pumpAndSettle();

          expect(find.text('Download From Robot'), findsOneWidget);
          await widgetTester.tap(find.text('Download From Robot'));
          await widgetTester.pumpAndSettle();

          expect(find.text('Select Layout'), findsOneWidget);
          expect(find.byType(DialogDropdownChooser<String>), findsOneWidget);

          await widgetTester.tap(find.byType(DialogDropdownChooser<String>));
          await widgetTester.pumpAndSettle();

          expect(find.text('elastic-layout 1'), findsOneWidget);

          await widgetTester.tap(find.text('elastic-layout 1'));
          await widgetTester.pumpAndSettle();

          expect(find.text('Download Mode'), findsOneWidget);
          expect(
            find.byType(DialogDropdownChooser<LayoutDownloadMode>),
            findsOneWidget,
          );
          await widgetTester.tap(
            find.byType(DialogDropdownChooser<LayoutDownloadMode>),
          );
          await widgetTester.pumpAndSettle();

          expect(find.text('Overwrite'), findsNWidgets(2));
          await widgetTester.tap(find.text('Overwrite').last);
          await widgetTester.pumpAndSettle();

          expect(find.text('Download'), findsOneWidget);
          await widgetTester.tap(find.text('Download'));
          await widgetTester.pump(Duration.zero);

          expect(
            find.widgetWithText(
              ElegantNotification,
              'Successfully Downloaded Layout',
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining('1 tabs were overwritten'),
            findsOneWidget,
          );

          await widgetTester.pumpAndSettle();

          expect(find.text('Test Tab'), findsOneWidget);
          await widgetTester.tap(find.text('Test Tab'));
          await widgetTester.pumpAndSettle();

          expect(find.text('Blocking Widget'), findsNothing);
          expect(find.byType(Gyro), findsNWidgets(2));
        });

        group('merge mode', () {
          testWidgets('without merges', (widgetTester) async {
            Client mockClient = createHttpClient(
              mockGetResponses: {
                'http://127.0.0.1:5800/?format=json': Response(
                  jsonEncode(layoutFiles),
                  200,
                ),
                'http://127.0.0.1:5800/${Uri.encodeComponent('elastic-layout 1.json')}':
                    Response(jsonEncode(layoutOne), 200),
              },
            );

            ElasticLayoutDownloader layoutDownloader = ElasticLayoutDownloader(
              mockClient,
            );

            await pumpDashboardPage(
              widgetTester,
              preferences,
              ntConnection: createMockOnlineNT4(),
              layoutDownloader: layoutDownloader,
            );

            expect(find.text('File'), findsOneWidget);
            await widgetTester.tap(find.text('File'));
            await widgetTester.pumpAndSettle();

            expect(find.text('Download From Robot'), findsOneWidget);
            await widgetTester.tap(find.text('Download From Robot'));
            await widgetTester.pumpAndSettle();

            expect(find.text('Select Layout'), findsOneWidget);
            expect(find.byType(DialogDropdownChooser<String>), findsOneWidget);

            await widgetTester.tap(find.byType(DialogDropdownChooser<String>));
            await widgetTester.pumpAndSettle();

            expect(find.text('elastic-layout 1'), findsOneWidget);

            await widgetTester.tap(find.text('elastic-layout 1'));
            await widgetTester.pumpAndSettle();

            expect(find.text('Download'), findsOneWidget);
            await widgetTester.tap(find.text('Download'));
            await widgetTester.pump(Duration.zero);

            expect(
              find.widgetWithText(
                ElegantNotification,
                'Successfully Downloaded Layout',
              ),
              findsOneWidget,
            );

            await widgetTester.pumpAndSettle();

            expect(find.text('Test Tab'), findsOneWidget);
            await widgetTester.tap(find.text('Test Tab'));
            await widgetTester.pumpAndSettle();

            expect(find.byType(Gyro), findsNWidgets(2));
          });
        });

        testWidgets('with merges', (widgetTester) async {
          Client mockClient = createHttpClient(
            mockGetResponses: {
              'http://127.0.0.1:5800/?format=json': Response(
                jsonEncode(layoutFiles),
                200,
              ),
              'http://127.0.0.1:5800/${Uri.encodeComponent('elastic-layout 1.json')}':
                  Response(jsonEncode(layoutOne), 200),
            },
          );

          ElasticLayoutDownloader layoutDownloader = ElasticLayoutDownloader(
            mockClient,
          );

          SharedPreferences.setMockInitialValues({
            PrefKeys.layout: jsonEncode({
              'version': 1.0,
              'grid_size': 128.0,
              'tabs': [
                {
                  'name': 'Test Tab',
                  'grid_layout': {
                    'layouts': [],
                    'containers': [
                      {
                        'title': 'Blocking Widget',
                        'x': 384.0,
                        'y': 128.0,
                        'width': 256.0,
                        'height': 256.0,
                        'type': 'Text Display',
                        'properties': {
                          'topic': '/Test Tab/Blocking Widget',
                          'period': 0.06,
                        },
                      },
                    ],
                  },
                },
              ],
            }),
            PrefKeys.ipAddress: '127.0.0.1',
          });

          SharedPreferences preferences = await SharedPreferences.getInstance();

          await pumpDashboardPage(
            widgetTester,
            preferences,
            ntConnection: createMockOnlineNT4(),
            layoutDownloader: layoutDownloader,
          );

          expect(find.text('File'), findsOneWidget);
          await widgetTester.tap(find.text('File'));
          await widgetTester.pumpAndSettle();

          expect(find.text('Download From Robot'), findsOneWidget);
          await widgetTester.tap(find.text('Download From Robot'));
          await widgetTester.pumpAndSettle();

          expect(find.text('Select Layout'), findsOneWidget);
          expect(find.byType(DialogDropdownChooser<String>), findsOneWidget);

          await widgetTester.tap(find.byType(DialogDropdownChooser<String>));
          await widgetTester.pumpAndSettle();

          expect(find.text('elastic-layout 1'), findsOneWidget);

          await widgetTester.tap(find.text('elastic-layout 1'));
          await widgetTester.pumpAndSettle();

          expect(find.text('Download Mode'), findsOneWidget);
          expect(
            find.byType(DialogDropdownChooser<LayoutDownloadMode>),
            findsOneWidget,
          );
          await widgetTester.tap(
            find.byType(DialogDropdownChooser<LayoutDownloadMode>),
          );
          await widgetTester.pumpAndSettle();

          expect(find.text('Merge'), findsOneWidget);
          await widgetTester.tap(find.text('Merge'));
          await widgetTester.pumpAndSettle();

          expect(find.text('Download'), findsOneWidget);
          await widgetTester.tap(find.text('Download'));
          await widgetTester.pump(Duration.zero);

          expect(
            find.widgetWithText(
              ElegantNotification,
              'Successfully Downloaded Layout',
            ),
            findsOneWidget,
          );

          await widgetTester.pumpAndSettle();

          expect(find.text('Test Tab'), findsOneWidget);
          await widgetTester.tap(find.text('Test Tab'));
          await widgetTester.pumpAndSettle();

          expect(find.text('Blocking Widget'), findsOneWidget);
          expect(find.byType(Gyro), findsOneWidget);
        });
      });
      testWidgets('reload mode', (widgetTester) async {
        Client mockClient = createHttpClient(
          mockGetResponses: {
            'http://127.0.0.1:5800/?format=json': Response(
              jsonEncode(layoutFiles),
              200,
            ),
            'http://127.0.0.1:5800/${Uri.encodeComponent('elastic-layout 1.json')}':
                Response(jsonEncode(layoutOne), 200),
          },
        );

        ElasticLayoutDownloader layoutDownloader = ElasticLayoutDownloader(
          mockClient,
        );

        await pumpDashboardPage(
          widgetTester,
          preferences,
          ntConnection: createMockOnlineNT4(),
          layoutDownloader: layoutDownloader,
        );

        expect(find.text('File'), findsOneWidget);
        await widgetTester.tap(find.text('File'));
        await widgetTester.pumpAndSettle();

        expect(find.text('Download From Robot'), findsOneWidget);
        await widgetTester.tap(find.text('Download From Robot'));
        await widgetTester.pumpAndSettle();

        expect(find.text('Select Layout'), findsOneWidget);
        expect(find.byType(DialogDropdownChooser<String>), findsOneWidget);

        await widgetTester.tap(find.byType(DialogDropdownChooser<String>));
        await widgetTester.pumpAndSettle();

        expect(find.text('elastic-layout 1'), findsOneWidget);

        await widgetTester.tap(find.text('elastic-layout 1'));
        await widgetTester.pumpAndSettle();

        expect(find.text('Download Mode'), findsOneWidget);
        expect(
          find.byType(DialogDropdownChooser<LayoutDownloadMode>),
          findsOneWidget,
        );
        await widgetTester.tap(
          find.byType(DialogDropdownChooser<LayoutDownloadMode>),
        );
        await widgetTester.pumpAndSettle();

        expect(find.text('Full Reload'), findsOneWidget);
        await widgetTester.tap(find.text('Full Reload'));
        await widgetTester.pumpAndSettle();

        expect(find.text('Download'), findsOneWidget);
        await widgetTester.tap(find.text('Download'));
        await widgetTester.pump(Duration.zero);

        expect(
          find.widgetWithText(
            ElegantNotification,
            'Successfully Downloaded Layout',
          ),
          findsOneWidget,
        );

        await widgetTester.pumpAndSettle();

        expect(find.text('Teleoperated'), findsNothing);
        expect(find.text('Autonomous'), findsNothing);
        expect(find.text('Test Tab'), findsOneWidget);
      });

      group('Shows error when', () {
        testWidgets('network tables is disconnected', (widgetTester) async {
          Client mockClient = createHttpClient();

          ElasticLayoutDownloader layoutDownloader = ElasticLayoutDownloader(
            mockClient,
          );

          await pumpDashboardPage(
            widgetTester,
            preferences,
            layoutDownloader: layoutDownloader,
          );

          expect(find.text('File'), findsOneWidget);
          await widgetTester.tap(find.text('File'));
          await widgetTester.pumpAndSettle();

          expect(find.text('Download From Robot'), findsOneWidget);
          await widgetTester.tap(find.text('Download From Robot'));
          await widgetTester.pump(Duration.zero);
          await widgetTester.pump(Duration.zero);

          expect(
            find.widgetWithText(
              ElegantNotification,
              'Cannot fetch remote layouts while disconnected from the robot',
            ),
            findsOneWidget,
          );
        });

        testWidgets('layout fetching is not a json', (widgetTester) async {
          Client mockClient = createHttpClient(
            mockGetResponses: {
              'http://127.0.0.1:5800/?format=json': Response('[1, 2, 3]', 200),
            },
          );

          ElasticLayoutDownloader layoutDownloader = ElasticLayoutDownloader(
            mockClient,
          );

          await pumpDashboardPage(
            widgetTester,
            preferences,
            ntConnection: createMockOnlineNT4(),
            layoutDownloader: layoutDownloader,
          );

          expect(find.text('File'), findsOneWidget);
          await widgetTester.tap(find.text('File'));
          await widgetTester.pumpAndSettle();

          expect(find.text('Download From Robot'), findsOneWidget);
          await widgetTester.tap(find.text('Download From Robot'));
          await widgetTester.pump(Duration.zero);
          await widgetTester.pump(Duration.zero);

          expect(
            find.widgetWithText(
              ElegantNotification,
              'Response was not a json object',
            ),
            findsOneWidget,
          );
        });

        testWidgets('layout json does not list files', (widgetTester) async {
          Client mockClient = createHttpClient(
            mockGetResponses: {
              'http://127.0.0.1:5800/?format=json': Response('{}', 200),
            },
          );

          ElasticLayoutDownloader layoutDownloader = ElasticLayoutDownloader(
            mockClient,
          );

          await pumpDashboardPage(
            widgetTester,
            preferences,
            ntConnection: createMockOnlineNT4(),
            layoutDownloader: layoutDownloader,
          );

          expect(find.text('File'), findsOneWidget);
          await widgetTester.tap(find.text('File'));
          await widgetTester.pumpAndSettle();

          expect(find.text('Download From Robot'), findsOneWidget);
          await widgetTester.tap(find.text('Download From Robot'));
          await widgetTester.pump(Duration.zero);
          await widgetTester.pump(Duration.zero);

          expect(
            find.widgetWithText(
              ElegantNotification,
              'Response json does not contain files list',
            ),
            findsOneWidget,
          );
        });

        testWidgets('layout json has empty files list', (widgetTester) async {
          Client mockClient = createHttpClient(
            mockGetResponses: {
              'http://127.0.0.1:5800/?format=json': Response(
                jsonEncode({'files': []}),
                200,
              ),
            },
          );

          ElasticLayoutDownloader layoutDownloader = ElasticLayoutDownloader(
            mockClient,
          );

          await pumpDashboardPage(
            widgetTester,
            preferences,
            ntConnection: createMockOnlineNT4(),
            layoutDownloader: layoutDownloader,
          );

          expect(find.text('File'), findsOneWidget);
          await widgetTester.tap(find.text('File'));
          await widgetTester.pumpAndSettle();

          expect(find.text('Download From Robot'), findsOneWidget);
          await widgetTester.tap(find.text('Download From Robot'));
          await widgetTester.pump(Duration.zero);
          await widgetTester.pump(Duration.zero);

          expect(
            find.widgetWithText(
              ElegantNotification,
              'No layouts were found, ensure a valid layout json file is placed in the root directory of your deploy directory.',
            ),
            findsOneWidget,
          );
        });

        testWidgets('selected file was not found', (widgetTester) async {
          Client mockClient = createHttpClient(
            mockGetResponses: {
              'http://127.0.0.1:5800/?format=json': Response(
                jsonEncode(layoutFiles),
                200,
              ),
              'http://127.0.0.1:5800/${Uri.encodeComponent('elastic-layout 1.json')}':
                  Response('', 404),
            },
          );

          ElasticLayoutDownloader layoutDownloader = ElasticLayoutDownloader(
            mockClient,
          );

          await pumpDashboardPage(
            widgetTester,
            preferences,
            ntConnection: createMockOnlineNT4(),
            layoutDownloader: layoutDownloader,
          );

          expect(find.text('File'), findsOneWidget);
          await widgetTester.tap(find.text('File'));
          await widgetTester.pumpAndSettle();

          expect(find.text('Download From Robot'), findsOneWidget);
          await widgetTester.tap(find.text('Download From Robot'));
          await widgetTester.pumpAndSettle();

          expect(find.text('Select Layout'), findsOneWidget);
          expect(find.byType(DialogDropdownChooser<String>), findsOneWidget);

          await widgetTester.tap(find.byType(DialogDropdownChooser<String>));
          await widgetTester.pumpAndSettle();

          expect(find.text('elastic-layout 1'), findsOneWidget);

          await widgetTester.tap(find.text('elastic-layout 1'));
          await widgetTester.pumpAndSettle();

          expect(find.text('Download'), findsOneWidget);
          await widgetTester.tap(find.text('Download'));
          await widgetTester.pump(Duration.zero);
          await widgetTester.pump(Duration.zero);

          expect(
            find.widgetWithText(
              ElegantNotification,
              'File "elastic-layout 1.json" was not found',
            ),
            findsOneWidget,
          );
        });
      });
    });
    group('[Tab Selection]:', () {
      testWidgets('Passing in tab indexes', (widgetTester) async {
        MockNTConnection ntConnection = createMockOnlineNT4(
          virtualTopics: [
            NT4Topic(
              name: '/Elastic/SelectedTab',
              type: NT4Type.string(),
              properties: {},
            ),
          ],
        );

        await pumpDashboardPage(
          widgetTester,
          preferences,
          ntConnection: ntConnection,
        );

        final editableTabBar = find.byType(EditableTabBar);

        expect(editableTabBar, findsOneWidget);

        editableTabBarWidget() =>
            (editableTabBar.evaluate().first.widget as EditableTabBar);

        ntConnection.updateDataFromTopicName('/Elastic/SelectedTab', '1');

        await widgetTester.pumpAndSettle();

        expect(editableTabBarWidget().currentIndex, 1);

        ntConnection.updateDataFromTopicName('/Elastic/SelectedTab', '10');

        await widgetTester.pumpAndSettle();

        expect(
          editableTabBarWidget().currentIndex,
          1,
          reason:
              'Selected tab should not change since tab index is out of range',
        );
      });

      testWidgets('Passing in tab names', (widgetTester) async {
        MockNTConnection ntConnection = createMockOnlineNT4(
          virtualTopics: [
            NT4Topic(
              name: '/Elastic/SelectedTab',
              type: NT4Type.string(),
              properties: {},
            ),
          ],
        );

        await pumpDashboardPage(
          widgetTester,
          preferences,
          ntConnection: ntConnection,
        );

        final editableTabBar = find.byType(EditableTabBar);

        expect(editableTabBar, findsOneWidget);

        editableTabBarWidget() =>
            (editableTabBar.evaluate().first.widget as EditableTabBar);

        ntConnection.updateDataFromTopicName(
          '/Elastic/SelectedTab',
          'Autonomous',
        );

        await widgetTester.pumpAndSettle();

        expect(editableTabBarWidget().currentIndex, 1);

        ntConnection.updateDataFromTopicName(
          '/Elastic/SelectedTab',
          'Random Tab',
        );

        await widgetTester.pumpAndSettle();

        expect(
          editableTabBarWidget().currentIndex,
          1,
          reason: 'Selected tab should not change since tab name doesnt exist',
        );
      });
    });
  });

  testWidgets('About dialog', (widgetTester) async {
    await pumpDashboardPage(widgetTester, preferences);

    final helpButton = find.widgetWithText(SubmenuButton, 'Help');

    expect(helpButton, findsOneWidget);

    await widgetTester.tap(helpButton);
    await widgetTester.pumpAndSettle();

    final showAboutDialogButton = find.widgetWithText(MenuItemButton, 'About');

    expect(showAboutDialogButton, findsOneWidget);

    await widgetTester.tap(showAboutDialogButton);
    await widgetTester.pumpAndSettle();

    expect(find.byType(AboutDialog), findsOneWidget);
  });

  group('[Tab Manipulation]:', () {
    testWidgets('Changing tabs', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.byType(ComboBoxChooser), findsNothing);

      expect(find.byType(EditableTabBar), findsOneWidget);

      final autonomousTab = find.widgetWithText(
        AnimatedContainer,
        'Autonomous',
      );

      expect(autonomousTab, findsOneWidget);

      await widgetTester.tap(autonomousTab);
      await widgetTester.pumpAndSettle();

      expect(find.byType(ComboBoxChooser), findsOneWidget);
    });

    testWidgets('Creating new tab', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

      expect(find.byType(EditableTabBar), findsOneWidget);

      final createNewTabButton = find.descendant(
        of: find.byType(EditableTabBar),
        matching: find.byIcon(Icons.add),
      );

      expect(createNewTabButton, findsOneWidget);

      await widgetTester.tap(createNewTabButton);
      await widgetTester.pumpAndSettle();

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(3));
    });

    testWidgets('Creating new tab (shortcut)', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.keyT);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.keyT);

      await widgetTester.pumpAndSettle();

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(3));
    });

    testWidgets('Closing tab', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

      expect(find.byType(EditableTabBar), findsOneWidget);

      final closeTabButton = find
          .descendant(
            of: find.byType(EditableTabBar),
            matching: find.byIcon(Icons.close),
          )
          .last;

      expect(closeTabButton, findsOneWidget);

      await widgetTester.tap(closeTabButton);
      await widgetTester.pumpAndSettle();

      expect(
        find.text('Confirm Tab Close', skipOffstage: false),
        findsOneWidget,
      );

      final confirmButton = find.widgetWithText(
        TextButton,
        'OK',
        skipOffstage: false,
      );

      expect(confirmButton, findsOneWidget);

      await widgetTester.tap(confirmButton);
      await widgetTester.pumpAndSettle();

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(1));
    });

    testWidgets('Closing tab (shortcut)', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.keyW);

      await widgetTester.pumpAndSettle();

      expect(
        find.text('Confirm Tab Close', skipOffstage: false),
        findsOneWidget,
      );

      final confirmButton = find.widgetWithText(
        TextButton,
        'OK',
        skipOffstage: false,
      );

      expect(confirmButton, findsOneWidget);

      await widgetTester.tap(confirmButton);
      await widgetTester.pumpAndSettle();

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(1));
    });

    testWidgets('Reordering tabs', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

      final editableTabBar = find.byType(EditableTabBar);

      expect(editableTabBar, findsOneWidget);

      final tabLeftButton = find.descendant(
        of: editableTabBar,
        matching: find.byIcon(Icons.west),
      );
      final tabRightButton = find.descendant(
        of: editableTabBar,
        matching: find.byIcon(Icons.east),
      );

      expect(tabLeftButton, findsOneWidget);
      expect(tabRightButton, findsOneWidget);

      editableTabBarWidget() =>
          (editableTabBar.evaluate().first.widget as EditableTabBar);

      expect(editableTabBarWidget().currentIndex, 0);

      await widgetTester.tap(tabLeftButton);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        0,
        reason: 'Tab index should not change since index is 0',
      );

      await widgetTester.tap(tabRightButton);
      await widgetTester.pumpAndSettle();

      expect(editableTabBarWidget().currentIndex, 1);

      await widgetTester.tap(tabRightButton);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        1,
        reason:
            'Tab index should not change since index is equal to number of tabs',
      );

      await widgetTester.tap(tabLeftButton);
      await widgetTester.pumpAndSettle();

      expect(editableTabBarWidget().currentIndex, 0);
    });

    testWidgets('Reordering tabs (shortcut)', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

      final editableTabBar = find.byType(EditableTabBar);

      expect(editableTabBar, findsOneWidget);

      editableTabBarWidget() =>
          (editableTabBar.evaluate().first.widget as EditableTabBar);

      expect(editableTabBarWidget().currentIndex, 0);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.control);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        0,
        reason: 'Tab index should not change since index is 0',
      );

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await widgetTester.pumpAndSettle();

      expect(editableTabBarWidget().currentIndex, 1);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        1,
        reason:
            'Tab index should not change since index is equal to number of tabs',
      );

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await widgetTester.pumpAndSettle();

      expect(editableTabBarWidget().currentIndex, 0);
    });

    testWidgets('Navigate tabs left right (shortcut)', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

      final editableTabBar = find.byType(EditableTabBar);

      expect(editableTabBar, findsOneWidget);

      editableTabBarWidget() =>
          (editableTabBar.evaluate().first.widget as EditableTabBar);

      expect(editableTabBarWidget().currentIndex, 0);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.shift);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        1,
        reason: 'Tab index should roll over',
      );

      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        0,
        reason: 'Tab index should roll back over to 0',
      );

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        1,
        reason: 'Tab index should increase to 1 (no rollover)',
      );

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await widgetTester.pumpAndSettle();

      expect(editableTabBarWidget().currentIndex, 0);
    });

    testWidgets('Navigate to specific tabs', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      expect(find.byType(TabGrid, skipOffstage: false), findsNWidgets(2));

      final editableTabBar = find.byType(EditableTabBar);

      expect(editableTabBar, findsOneWidget);

      editableTabBarWidget() =>
          (editableTabBar.evaluate().first.widget as EditableTabBar);

      expect(editableTabBarWidget().currentIndex, 0);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.control);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.digit1);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.digit1);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        0,
        reason: 'Tab index should remain at 0',
      );

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.digit2);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.digit2);
      await widgetTester.pumpAndSettle();

      expect(editableTabBarWidget().currentIndex, 1);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.digit5);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.digit5);
      await widgetTester.pumpAndSettle();

      expect(
        editableTabBarWidget().currentIndex,
        1,
        reason: 'Tab index should remain at 1 since there is no tab at index 4',
      );
    });

    testWidgets('Renaming tab', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      final teleopTab = find.widgetWithText(AnimatedContainer, 'Teleoperated');

      expect(teleopTab, findsOneWidget);

      await widgetTester.tap(teleopTab, buttons: kSecondaryButton);
      await widgetTester.pumpAndSettle();

      final renameButton = find.text('Rename');

      expect(renameButton, findsOneWidget);

      await widgetTester.tap(renameButton);
      await widgetTester.pumpAndSettle();

      expect(find.text('Rename Tab'), findsOneWidget);

      final nameTextField = find.widgetWithText(DialogTextInput, 'Name');

      expect(nameTextField, findsOneWidget);

      await widgetTester.enterText(nameTextField, 'New Tab Name!');
      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pump();

      final saveButton = find.widgetWithText(TextButton, 'Save');

      expect(saveButton, findsOneWidget);

      await widgetTester.tap(saveButton);
      await widgetTester.pumpAndSettle();

      expect(
        find.widgetWithText(AnimatedContainer, 'Teleoperated'),
        findsNothing,
      );
      expect(
        find.widgetWithText(AnimatedContainer, 'New Tab Name!'),
        findsOneWidget,
      );
    });

    testWidgets('Duplicating tab', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      final teleopTab = find.widgetWithText(AnimatedContainer, 'Teleoperated');

      expect(teleopTab, findsOneWidget);

      await widgetTester.tap(teleopTab, buttons: kSecondaryButton);
      await widgetTester.pumpAndSettle();

      final duplicateButton = find.text('Duplicate');

      expect(duplicateButton, findsOneWidget);

      await widgetTester.tap(duplicateButton);
      await widgetTester.pumpAndSettle();

      expect(find.text('Teleoperated (Copy)'), findsOneWidget);
    });
  });

  group('[Window Manipulation]:', () {
    testWidgets('Minimizing window', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      final minimizeButton = find.ancestor(
        of: find.byType(DecoratedMinimizeButton),
        matching: find.byType(InkWell),
      );

      expect(minimizeButton, findsOneWidget);

      await widgetTester.tap(minimizeButton);
    });

    testWidgets('Maximizing/unmaximizing window', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      final appBar = find.byType(CustomAppBar);

      expect(appBar, findsOneWidget);

      await widgetTester.tapAt(const Offset(250, 0));
      await widgetTester.pump(kDoubleTapMinTime);
      await widgetTester.tapAt(const Offset(250, 0));

      await widgetTester.pumpAndSettle();

      final maximizeButton = find.ancestor(
        of: find.byType(DecoratedMaximizeButton),
        matching: find.byType(InkWell),
      );

      await widgetTester.tap(maximizeButton);
    });

    testWidgets('Closing window (All changes saved)', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      final gyroWidget = find.widgetWithText(WidgetContainer, 'Test Gyro');

      expect(gyroWidget, findsOneWidget);

      // Drag to a location
      await widgetTester.drag(gyroWidget, const Offset(256, -128));
      await widgetTester.pumpAndSettle();

      // Drag back to its original location
      await widgetTester.drag(gyroWidget, const Offset(-256, 128));
      await widgetTester.pumpAndSettle();

      final closeButton = find.ancestor(
        of: find.byType(DecoratedCloseButton),
        matching: find.byType(InkWell),
      );

      await widgetTester.tap(closeButton);
      await widgetTester.pumpAndSettle();

      expect(find.widgetWithText(AlertDialog, 'Unsaved Changes'), findsNothing);
    });

    testWidgets('Closing window (Unsaved changes)', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      final gyroWidget = find.widgetWithText(WidgetContainer, 'Test Gyro');

      expect(gyroWidget, findsOneWidget);

      // Drag to a location
      await widgetTester.drag(gyroWidget, const Offset(256, -128));

      await widgetTester.pumpAndSettle();

      final closeButton = find.ancestor(
        of: find.byType(DecoratedCloseButton),
        matching: find.byType(InkWell),
      );

      expect(closeButton, findsOneWidget);

      await widgetTester.tap(closeButton);
      await widgetTester.pumpAndSettle();

      expect(
        find.widgetWithText(AlertDialog, 'Unsaved Changes'),
        findsOneWidget,
      );

      final discardButton = find.widgetWithText(TextButton, 'Discard');

      expect(discardButton, findsOneWidget);

      await widgetTester.tap(discardButton);
      await widgetTester.pumpAndSettle();
    });
  });

  group('[Misc Shortcuts]:', () {
    testWidgets('Opening settings', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      final settingsButton = find.widgetWithIcon(
        MenuItemButton,
        Icons.settings,
      );

      expect(settingsButton, findsOneWidget);

      final settingsButtonWidget =
          settingsButton.evaluate().first.widget as MenuItemButton;

      settingsButtonWidget.onPressed?.call();

      await widgetTester.pumpAndSettle();

      expect(find.byType(SettingsDialog), findsOneWidget);
    });

    testWidgets('Opening settings (shortcut)', (widgetTester) async {
      await pumpDashboardPage(widgetTester, preferences);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.control);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.comma);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.comma);

      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.control);

      await widgetTester.pumpAndSettle();

      expect(find.byType(SettingsDialog), findsOneWidget);
    });

    testWidgets('IP Address shortcuts', (widgetTester) async {
      SharedPreferences.setMockInitialValues({
        PrefKeys.ipAddressMode: IPAddressMode.custom.index,
        PrefKeys.ipAddress: '127.0.0.1',
        PrefKeys.teamNumber: 353,
      });

      MockNTConnection ntConnection = createMockOfflineNT4();
      MockDSInteropClient dsClient = MockDSInteropClient();
      when(dsClient.lastAnnouncedIP).thenReturn(null);
      when(ntConnection.dsClient).thenReturn(dsClient);

      await pumpDashboardPage(
        widgetTester,
        preferences,
        ntConnection: ntConnection,
      );

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.control);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.keyK);

      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.control);

      await widgetTester.pumpAndSettle();

      expect(
        preferences.getInt(PrefKeys.ipAddressMode),
        IPAddressMode.driverStation.index,
      );
      expect(preferences.getString(PrefKeys.ipAddress), '10.3.53.2');

      await preferences.setString(PrefKeys.ipAddress, '0.0.0.0');

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.control);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.keyK);

      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.control);

      await widgetTester.pumpAndSettle();

      // IP Address shouldn't change since it's already driver station
      expect(
        preferences.getInt(PrefKeys.ipAddressMode),
        IPAddressMode.driverStation.index,
      );
      expect(preferences.getString(PrefKeys.ipAddress), '0.0.0.0');

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.shift);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.keyK);

      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      await widgetTester.pumpAndSettle();

      expect(
        preferences.getInt(PrefKeys.ipAddressMode),
        IPAddressMode.localhost.index,
      );
      expect(preferences.getString(PrefKeys.ipAddress), 'localhost');

      await preferences.setString(PrefKeys.ipAddress, '0.0.0.0');

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.shift);

      await widgetTester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.keyK);

      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await widgetTester.sendKeyUpEvent(LogicalKeyboardKey.shift);

      await widgetTester.pumpAndSettle();

      // IP address shouldn't change since mode is set to localhost
      expect(
        preferences.getInt(PrefKeys.ipAddressMode),
        IPAddressMode.localhost.index,
      );
      expect(preferences.getString(PrefKeys.ipAddress), '0.0.0.0');
    });
  });

  group('[Notifications]:', () {
    testWidgets('Robot Notifications', (widgetTester) async {
      final Map<String, dynamic> data = {
        'title': 'Robot Notification Title',
        'description': 'Robot Notification Description',
        'level': 'INFO',
        'displayTime': 350,
        'width': 300.0,
        'height': 300.0,
      };

      MockNTConnection connection = createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
            name: '/Elastic/RobotNotifications',
            type: NT4Type.string(),
            properties: {},
          ),
        ],
        virtualValues: {'/Elastic/RobotNotifications': jsonEncode(data)},
        serverTime: 5000000,
      );
      MockNT4Subscription mockSub = MockNT4Subscription();

      List<Function(Object?, int)> listeners = [];
      when(mockSub.listen(any)).thenAnswer((realInvocation) {
        listeners.add(realInvocation.positionalArguments[0]);
        mockSub.updateValue(jsonEncode(data), 0);
      });

      when(mockSub.updateValue(any, any)).thenAnswer((invoc) {
        for (var value in listeners) {
          value.call(
            invoc.positionalArguments[0],
            invoc.positionalArguments[1],
          );
        }
      });

      when(
        connection.subscribeAll(any, any),
      ).thenAnswer((realInvocation) => mockSub);

      final notificationWidget = find.widgetWithText(
        ElegantNotification,
        data['title'],
      );

      await pumpDashboardPage(
        widgetTester,
        preferences,
        ntConnection: connection,
      );

      expect(notificationWidget, findsNothing);

      connection
          .subscribeAll('/Elastic/RobotNotifications', 0.2)
          .updateValue(jsonEncode(data), 1);

      await widgetTester.pump();

      expect(notificationWidget, findsOneWidget);

      await widgetTester.pumpAndSettle();

      expect(notificationWidget, findsNothing);

      connection
          .subscribeAll('/Elastic/RobotNotifications', 0.2)
          .updateValue(jsonEncode(data), 1);
    });

    testWidgets('Update Notification', (widgetTester) async {
      await pumpDashboardPage(
        widgetTester,
        preferences,
        updateChecker: createMockUpdateChecker(
          updateAvailable: true,
          latestVersion: '2025.0.1',
        ),
      );

      final notificationWidget = find.widgetWithText(
        ElegantNotification,
        'Version 2025.0.1 Available',
      );
      final notificationIcon = find.byIcon(Icons.update);

      expect(notificationWidget, findsOneWidget);
      expect(notificationIcon, findsOneWidget);
    });
  });
}
