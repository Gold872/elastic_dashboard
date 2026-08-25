import 'package:flutter/gestures.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/util/tab_data.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/editable_tab_bar.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';

import '../test_util.dart';
import '../test_util.mocks.dart';

class FakeTabBarFunctions extends Mock {
  void onTabCreate();

  void onTabDestroy();

  void onTabMoveLeft();

  void onTabMoveRight();

  void onTabRename();

  void onTabChanged();

  void onTabDuplicate();
}

void main() {
  late FakeTabBarFunctions tabBarFunctions;
  late MockNTConnection mockNTConnection;
  late SharedPreferences preferences;

  setUp(() async {
    tabBarFunctions = FakeTabBarFunctions();
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    mockNTConnection = createMockOfflineNT4();
  });

  testWidgets('Editable tab bar', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditableTabBar(
            preferences: preferences,
            currentIndex: 0,
            tabData: [
              TabData(
                name: 'Teleoperated',
                tabGrid: TabGridModel(
                  ntConnection: mockNTConnection,
                  preferences: preferences,
                  onAddWidgetPressed: () {},
                ),
              ),
              TabData(
                name: 'Autonomous',
                tabGrid: TabGridModel(
                  ntConnection: mockNTConnection,
                  preferences: preferences,
                  onAddWidgetPressed: () {},
                ),
              ),
            ],
            onTabCreate: () {},
            onTabDestroy: (index) {},
            onTabMoveLeft: () {},
            onTabMoveRight: () {},
            onTabRename: (tab, grid) {},
            onTabChanged: (index) {},
            onTabDuplicate: (index) {},
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(
      find.widgetWithText(AnimatedContainer, 'Teleoperated'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(AnimatedContainer, 'Autonomous'),
      findsOneWidget,
    );

    expect(find.byIcon(Icons.close), findsNWidgets(2));
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.west), findsOneWidget);
    expect(find.byIcon(Icons.east), findsOneWidget);
  });

  testWidgets('Open new tab', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditableTabBar(
            preferences: preferences,
            currentIndex: 0,
            tabData: [
              TabData(
                name: 'Teleoperated',
                tabGrid: TabGridModel(
                  ntConnection: mockNTConnection,
                  preferences: preferences,
                  onAddWidgetPressed: () {},
                ),
              ),
              TabData(
                name: 'Autonomous',
                tabGrid: TabGridModel(
                  ntConnection: mockNTConnection,
                  preferences: preferences,
                  onAddWidgetPressed: () {},
                ),
              ),
            ],
            onTabCreate: () {
              tabBarFunctions.onTabCreate();
            },
            onTabDestroy: (index) {
              tabBarFunctions.onTabDestroy();
            },
            onTabMoveLeft: () {
              tabBarFunctions.onTabMoveLeft();
            },
            onTabMoveRight: () {
              tabBarFunctions.onTabMoveRight();
            },
            onTabRename: (tab, grid) {
              tabBarFunctions.onTabRename();
            },
            onTabChanged: (index) {
              tabBarFunctions.onTabChanged();
            },
            onTabDuplicate: (index) {
              tabBarFunctions.onTabDuplicate();
            },
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    final newTabButton = find.byIcon(Icons.add);

    expect(newTabButton, findsOneWidget);

    await widgetTester.tap(newTabButton);
    await widgetTester.pumpAndSettle();

    verify(tabBarFunctions.onTabCreate()).called(1);
  });

  testWidgets('Close tab', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditableTabBar(
            preferences: preferences,
            currentIndex: 0,
            tabData: [
              TabData(
                name: 'Teleoperated',
                tabGrid: TabGridModel(
                  ntConnection: mockNTConnection,
                  preferences: preferences,
                  onAddWidgetPressed: () {},
                ),
              ),
              TabData(
                name: 'Autonomous',
                tabGrid: TabGridModel(
                  ntConnection: mockNTConnection,
                  preferences: preferences,
                  onAddWidgetPressed: () {},
                ),
              ),
            ],
            onTabCreate: () {
              tabBarFunctions.onTabCreate();
            },
            onTabDestroy: (index) {
              tabBarFunctions.onTabDestroy();
            },
            onTabMoveLeft: () {
              tabBarFunctions.onTabMoveLeft();
            },
            onTabMoveRight: () {
              tabBarFunctions.onTabMoveRight();
            },
            onTabRename: (tab, grid) {
              tabBarFunctions.onTabRename();
            },
            onTabChanged: (index) {
              tabBarFunctions.onTabChanged();
            },
            onTabDuplicate: (index) {
              tabBarFunctions.onTabDuplicate();
            },
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    final closeTabButton = find.byIcon(Icons.close).first;

    expect(closeTabButton, findsOneWidget);

    await widgetTester.tap(closeTabButton);
    await widgetTester.pumpAndSettle();

    verify(tabBarFunctions.onTabDestroy()).called(1);
  });

  testWidgets('Reordering tabs', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditableTabBar(
            preferences: preferences,
            currentIndex: 0,
            tabData: [
              TabData(
                name: 'Teleoperated',
                tabGrid: TabGridModel(
                  ntConnection: mockNTConnection,
                  preferences: preferences,
                  onAddWidgetPressed: () {},
                ),
              ),
              TabData(
                name: 'Autonomous',
                tabGrid: TabGridModel(
                  ntConnection: mockNTConnection,
                  preferences: preferences,
                  onAddWidgetPressed: () {},
                ),
              ),
            ],
            onTabCreate: () {
              tabBarFunctions.onTabCreate();
            },
            onTabDestroy: (index) {
              tabBarFunctions.onTabDestroy();
            },
            onTabMoveLeft: () {
              tabBarFunctions.onTabMoveLeft();
            },
            onTabMoveRight: () {
              tabBarFunctions.onTabMoveRight();
            },
            onTabRename: (tab, grid) {
              tabBarFunctions.onTabRename();
            },
            onTabChanged: (index) {
              tabBarFunctions.onTabChanged();
            },
            onTabDuplicate: (index) {
              tabBarFunctions.onTabDuplicate();
            },
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    final tabLeftButton = find.byIcon(Icons.west);
    final tabRightButton = find.byIcon(Icons.east);

    expect(tabLeftButton, findsOneWidget);
    expect(tabRightButton, findsOneWidget);

    // Should not change indexes
    await widgetTester.tap(tabLeftButton);
    await widgetTester.pumpAndSettle();
    // Should change indexes
    await widgetTester.tap(tabRightButton);
    await widgetTester.pumpAndSettle();
    // Should not change indexes
    await widgetTester.tap(tabRightButton);
    await widgetTester.pumpAndSettle();
    // Should change indexes
    await widgetTester.tap(tabLeftButton);
    await widgetTester.pumpAndSettle();

    verify(tabBarFunctions.onTabMoveLeft()).called(2);
    verify(tabBarFunctions.onTabMoveRight()).called(2);
  });

  testWidgets('Rename tab', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditableTabBar(
            preferences: preferences,
            currentIndex: 0,
            tabData: [
              TabData(
                name: 'Teleoperated',
                tabGrid: TabGridModel(
                  ntConnection: mockNTConnection,
                  preferences: preferences,
                  onAddWidgetPressed: () {},
                ),
              ),
              TabData(
                name: 'Autonomous',
                tabGrid: TabGridModel(
                  ntConnection: mockNTConnection,
                  preferences: preferences,
                  onAddWidgetPressed: () {},
                ),
              ),
            ],
            onTabCreate: () {
              tabBarFunctions.onTabCreate();
            },
            onTabDestroy: (index) {
              tabBarFunctions.onTabDestroy();
            },
            onTabMoveLeft: () {
              tabBarFunctions.onTabMoveLeft();
            },
            onTabMoveRight: () {
              tabBarFunctions.onTabMoveRight();
            },
            onTabRename: (tab, grid) {
              tabBarFunctions.onTabRename();
            },
            onTabChanged: (index) {
              tabBarFunctions.onTabChanged();
            },
            onTabDuplicate: (index) {
              tabBarFunctions.onTabDuplicate();
            },
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

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

    verify(tabBarFunctions.onTabRename()).called(greaterThanOrEqualTo(1));
  });

  testWidgets('Change tab', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditableTabBar(
            preferences: preferences,
            currentIndex: 0,
            tabData: [
              TabData(
                name: 'Teleoperated',
                tabGrid: TabGridModel(
                  ntConnection: mockNTConnection,
                  preferences: preferences,
                  onAddWidgetPressed: () {},
                ),
              ),
              TabData(
                name: 'Autonomous',
                tabGrid: TabGridModel(
                  ntConnection: mockNTConnection,
                  preferences: preferences,
                  onAddWidgetPressed: () {},
                ),
              ),
            ],
            onTabCreate: () {
              tabBarFunctions.onTabCreate();
            },
            onTabDestroy: (index) {
              tabBarFunctions.onTabDestroy();
            },
            onTabMoveLeft: () {
              tabBarFunctions.onTabMoveLeft();
            },
            onTabMoveRight: () {
              tabBarFunctions.onTabMoveRight();
            },
            onTabRename: (tab, grid) {
              tabBarFunctions.onTabRename();
            },
            onTabChanged: (index) {
              tabBarFunctions.onTabChanged();
            },
            onTabDuplicate: (index) {
              tabBarFunctions.onTabDuplicate();
            },
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    final autonomousTab = find.widgetWithText(AnimatedContainer, 'Autonomous');

    expect(autonomousTab, findsOneWidget);

    await widgetTester.tap(autonomousTab);
    await widgetTester.pumpAndSettle();

    verify(tabBarFunctions.onTabChanged()).called(1);
  });
}
