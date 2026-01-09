import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/field_images.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_list_layout.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/basic_swerve_drive.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/camera_stream.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/command_scheduler.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/command_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/field_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/fms_info.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/gyro.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/pid_controller.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/power_distribution.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/robot_preferences.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/split_button_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/subsystem_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/boolean_box.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/graph.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/match_time.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/multi_color_view.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/number_bar.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/number_slider.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/single_color_view.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/text_display.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/toggle_button.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/voltage_view.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';
import '../test_util.dart';
import '../test_util.mocks.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String jsonString;
  late Map<String, dynamic> jsonData;
  late SharedPreferences preferences;

  setUpAll(() async {
    await FieldImages.loadFields('assets/fields/');

    String filePath =
        '${Directory.current.path}/test_resources/test-layout.json';

    jsonString = File(filePath).readAsStringSync();
    jsonData = jsonDecode(jsonString);

    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  testWidgets('Tab grid loading (Tab 1)', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    widgetTester.view.physicalSize = const Size(1920, 1080);
    widgetTester.view.devicePixelRatio = 1.0;

    expect(jsonData.containsKey('tabs'), true);

    expect(jsonData['tabs'][0].containsValue('Teleoperated'), true);
    expect(jsonData['tabs'][0].containsKey('grid_layout'), true);

    expect(jsonData['tabs'][1].containsValue('Autonomous'), true);
    expect(jsonData['tabs'][1].containsKey('grid_layout'), true);

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<TabGridModel>.value(
            value: TabGridModel.fromJson(
              ntConnection: createMockOfflineNT4(),
              preferences: preferences,
              jsonData: jsonData['tabs'][0]['grid_layout'],
              onAddWidgetPressed: () {},
            ),
            child: const TabGrid(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.bySubtype<DraggableNTWidgetContainer>(), findsNWidgets(10));
    expect(find.bySubtype<DraggableWidgetContainer>(), findsNWidgets(11));
    expect(find.bySubtype<NTWidget>(), findsNWidgets(12));

    expect(find.bySubtype<TextDisplay>(), findsOneWidget);
    expect(find.bySubtype<BooleanBox>(), findsNWidgets(2));
    expect(find.bySubtype<FieldWidget>(), findsOneWidget);
    expect(find.bySubtype<PowerDistribution>(), findsOneWidget);
    expect(find.bySubtype<FMSInfo>(), findsOneWidget);
    expect(find.bySubtype<Gyro>(), findsOneWidget);
    expect(find.bySubtype<CameraStreamWidget>(), findsOneWidget);
    expect(find.bySubtype<MatchTimeWidget>(), findsOneWidget);
    expect(find.bySubtype<PIDControllerWidget>(), findsOneWidget);
    expect(find.bySubtype<SwerveDriveWidget>(), findsOneWidget);

    expect(find.bySubtype<DraggableListLayout>(), findsOneWidget);
  });

  testWidgets('Tab grid loading (2nd Tab)', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    widgetTester.view.physicalSize = const Size(1920, 1080);
    widgetTester.view.devicePixelRatio = 1.0;

    expect(jsonData.containsKey('tabs'), true);

    expect(jsonData['tabs'][0].containsValue('Teleoperated'), true);
    expect(jsonData['tabs'][0].containsKey('grid_layout'), true);

    expect(jsonData['tabs'][1].containsValue('Autonomous'), true);
    expect(jsonData['tabs'][1].containsKey('grid_layout'), true);

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<TabGridModel>.value(
            value: TabGridModel.fromJson(
              ntConnection: createMockOfflineNT4(),
              preferences: preferences,
              jsonData: jsonData['tabs'][1]['grid_layout'],
              onAddWidgetPressed: () {},
            ),
            child: const TabGrid(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.bySubtype<DraggableNTWidgetContainer>(), findsNWidgets(14));
    expect(find.bySubtype<NTWidget>(), findsNWidgets(14));

    expect(find.bySubtype<ToggleButton>(), findsOneWidget);
    expect(find.bySubtype<ToggleSwitch>(), findsOneWidget);
    expect(find.bySubtype<ComboBoxChooser>(), findsOneWidget);
    expect(find.bySubtype<SplitButtonChooser>(), findsOneWidget);
    expect(find.bySubtype<SingleColorView>(), findsOneWidget);
    expect(find.bySubtype<MultiColorView>(), findsOneWidget);
    expect(find.bySubtype<VoltageView>(), findsOneWidget);
    expect(find.bySubtype<NumberBar>(), findsOneWidget);
    expect(find.bySubtype<NumberSlider>(), findsOneWidget);
    expect(find.bySubtype<GraphWidget>(), findsOneWidget);
    expect(find.bySubtype<CommandSchedulerWidget>(), findsOneWidget);
    expect(find.bySubtype<CommandWidget>(), findsOneWidget);
    expect(find.bySubtype<SubsystemWidget>(), findsOneWidget);
    expect(find.bySubtype<RobotPreferences>(), findsOneWidget);
  });

  testWidgets('Editing properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    widgetTester.view.physicalSize = const Size(1920, 1080);
    widgetTester.view.devicePixelRatio = 1.0;

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<TabGridModel>.value(
            value: TabGridModel.fromJson(
              ntConnection: createMockOfflineNT4(),
              preferences: preferences,
              jsonData: jsonData['tabs'][0]['grid_layout'],
              onAddWidgetPressed: () {},
            ),
            child: const TabGrid(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    await widgetTester.ensureVisible(find.text('Test Number'));

    await widgetTester.pumpAndSettle();

    await widgetTester.tap(
      find.text('Test Number'),
      buttons: kSecondaryMouseButton,
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Test Number'), findsAtLeastNWidgets(2));
    expect(find.byType(TextDisplay), findsOneWidget);
    expect(find.text('Edit Properties'), findsOneWidget);

    await widgetTester.tap(find.text('Edit Properties'));
    await widgetTester.pumpAndSettle();

    expect(find.text('Container Settings'), findsOneWidget);
    expect(find.text('Network Tables Settings (Advanced)'), findsOneWidget);

    final titleText = find.widgetWithText(DialogTextInput, 'Title');

    expect(titleText, findsOneWidget);

    await widgetTester.enterText(titleText, 'Editing Title Test');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pump(Duration.zero);

    expect(find.text('Editing Title Test'), findsAtLeastNWidgets(2));

    final widgetTypeSelection = find.text('Text Display');

    expect(widgetTypeSelection, findsOneWidget);

    await widgetTester.tap(widgetTypeSelection);
    await widgetTester.pumpAndSettle();

    expect(find.text('Text Display'), findsNWidgets(2));
    expect(find.text('Graph'), findsNothing);

    await widgetTester.tap(find.text('Text Display').last);
    await widgetTester.pumpAndSettle();

    expect(find.byType(TextDisplay), findsOneWidget);

    final closeButton = find.widgetWithText(TextButton, 'Close');

    expect(closeButton, findsOneWidget);

    await widgetTester.tap(closeButton);
    await widgetTester.pumpAndSettle();
  });

  testWidgets('Editing properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    widgetTester.view.physicalSize = const Size(1920, 1080);
    widgetTester.view.devicePixelRatio = 1.0;

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<TabGridModel>.value(
            value: TabGridModel.fromJson(
              ntConnection: createMockOfflineNT4(),
              preferences: preferences,
              jsonData: jsonData['tabs'][0]['grid_layout'],
              onAddWidgetPressed: () {},
            ),
            child: const TabGrid(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    await widgetTester.ensureVisible(find.text('Test Number'));

    await widgetTester.pumpAndSettle();

    await widgetTester.tapAt(
      const Offset(320.0, 64.0),
      buttons: kSecondaryButton,
    );
    await widgetTester.pumpAndSettle();

    expect(find.text('Paste'), findsNothing);

    // Dismiss context menu
    await widgetTester.tapAt(const Offset(320.0, 64.0));
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(
      find.text('Test Number'),
      buttons: kSecondaryMouseButton,
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Test Number'), findsAtLeastNWidgets(2));
    expect(find.text('Copy'), findsOneWidget);

    await widgetTester.tap(find.text('Copy'));

    await widgetTester.pumpAndSettle();

    await widgetTester.tapAt(
      const Offset(320.0, 64.0),
      buttons: kSecondaryButton,
    );
    await widgetTester.pumpAndSettle();

    expect(find.text('Paste'), findsOneWidget);
    await widgetTester.tap(find.text('Paste'));
    await widgetTester.pumpAndSettle();

    expect(find.text('Test Number'), findsNWidgets(2));
  });

  testWidgets('Dragging widgets', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    widgetTester.view.physicalSize = const Size(1920, 1080);
    widgetTester.view.devicePixelRatio = 1.0;

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<TabGridModel>.value(
            value: TabGridModel.fromJson(
              ntConnection: createMockOfflineNT4(),
              preferences: preferences,
              jsonData: jsonData['tabs'][0]['grid_layout'],
              onAddWidgetPressed: () {},
            ),
            child: const TabGrid(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    final gyroWidget = find.widgetWithText(WidgetContainer, 'Test Gyro');

    expect(gyroWidget, findsOneWidget);

    // Drag to a valid location
    await widgetTester.drag(gyroWidget, const Offset(256, -128));

    await widgetTester.pumpAndSettle();

    expect(gyroWidget, findsOneWidget);

    // Drag back to its original location
    await widgetTester.drag(gyroWidget, const Offset(-256, 128));

    await widgetTester.pumpAndSettle();

    expect(gyroWidget, findsOneWidget);

    // Drag to an invalid location
    await widgetTester.drag(gyroWidget, const Offset(0, -128));

    await widgetTester.pumpAndSettle();

    expect(gyroWidget, findsOneWidget);
  });

  testWidgets('Disposing properly unsubscribes', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;
    widgetTester.view.physicalSize = const Size(1920, 1080);
    widgetTester.view.devicePixelRatio = 1.0;

    expect(jsonData.containsKey('tabs'), true);

    expect(jsonData['tabs'][0].containsValue('Teleoperated'), true);
    expect(jsonData['tabs'][0].containsKey('grid_layout'), true);

    expect(jsonData['tabs'][1].containsValue('Autonomous'), true);
    expect(jsonData['tabs'][1].containsKey('grid_layout'), true);

    MockNTConnection ntConnection = createMockOnlineNT4();

    TabGridModel tabGridModel = TabGridModel.fromJson(
      ntConnection: ntConnection,
      preferences: preferences,
      jsonData: jsonData['tabs'][0]['grid_layout'],
      onAddWidgetPressed: () {},
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<TabGridModel>.value(
            value: tabGridModel,
            child: const TabGrid(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    int subscribeCallCount =
        verify(ntConnection.subscribe(any, any)).callCount +
        verify(ntConnection.subscribeWithOptions(any, any)).callCount;

    expect(subscribeCallCount, greaterThan(10));

    tabGridModel.clearWidgets();

    await widgetTester.pumpAndSettle();

    verify(ntConnection.unSubscribe(any)).called(subscribeCallCount);
  });
}
