import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/swerve_drive_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> swerveJson = {
    'topic': 'Test/Swerve Drive',
    'period': 0.100,
    'show_robot_rotation': true,
    'show_desired_states': true,
    'angle_offset': 90.0,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4();
  });

  test('Swerve drive from json', () {
    NTWidgetModel swerveModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'SwerveDrive',
      swerveJson,
    );

    expect(swerveModel.type, 'SwerveDrive');
    expect(swerveModel.runtimeType, SwerveDriveWidgetModel);

    if (swerveModel is! SwerveDriveWidgetModel) {
      return;
    }

    expect(swerveModel.showRobotRotation, isTrue);
    expect(swerveModel.showDesiredStates, isTrue);
    expect(swerveModel.angleOffset, 90.0);
  });

  test('Swerve drive to json', () {
    SwerveDriveWidgetModel swerveModel = SwerveDriveWidgetModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Swerve Drive',
      period: 0.100,
      showRobotRotation: true,
      showDesiredStates: true,
      angleOffset: 90.0,
    );

    expect(swerveModel.toJson(), swerveJson);
  });

  testWidgets('Swerve drive widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel swerveModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'SwerveDrive',
      swerveJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: swerveModel,
            child: const SwerveDriveWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('Swerve drive edit properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    SwerveDriveWidgetModel swerveModel = SwerveDriveWidgetModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Swerve Drive',
      period: 0.100,
      showRobotRotation: true,
      showDesiredStates: true,
      angleOffset: 90.0,
    );

    NTWidgetContainerModel ntContainerModel = NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.zero,
      title: 'Swerve Drive',
      childModel: swerveModel,
    );

    final key = GlobalKey();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetContainerModel>.value(
            key: key,
            value: ntContainerModel,
            child: const DraggableNTWidgetContainer(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    ntContainerModel.showEditProperties(key.currentContext!);

    await widgetTester.pumpAndSettle();

    final showRobotRotation = find.widgetWithText(
      DialogToggleSwitch,
      'Show Robot Rotation',
    );
    final showDesiredStates = find.widgetWithText(
      DialogToggleSwitch,
      'Show Desired States',
    );
    final angleOffset = find.widgetWithText(
      DialogTextInput,
      'Angle Offset (Degrees)',
    );

    expect(showRobotRotation, findsOneWidget);
    expect(showDesiredStates, findsOneWidget);
    expect(angleOffset, findsOneWidget);

    await widgetTester.tap(
      find.descendant(of: showRobotRotation, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();
    expect(swerveModel.showRobotRotation, false);

    await widgetTester.tap(
      find.descendant(of: showDesiredStates, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();
    expect(swerveModel.showDesiredStates, false);

    await widgetTester.enterText(angleOffset, '45.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(swerveModel.angleOffset, 45.0);
  });
}
