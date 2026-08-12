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
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/yagsl_swerve_drive.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> yagslSwerveJson = {
    'topic': 'Test/YAGSL Swerve Drive',
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

  test('YAGSL swerve drive from json', () {
    NTWidgetModel yagslSwerveModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'YAGSL Swerve Drive',
      yagslSwerveJson,
    );

    expect(yagslSwerveModel.type, 'YAGSL Swerve Drive');
    expect(yagslSwerveModel.runtimeType, YAGSLSwerveDriveModel);

    if (yagslSwerveModel is! YAGSLSwerveDriveModel) {
      return;
    }

    expect(yagslSwerveModel.showRobotRotation, isTrue);
    expect(yagslSwerveModel.showDesiredStates, isTrue);
    expect(yagslSwerveModel.angleOffset, 90.0);
  });

  test('YAGSL swerve drive to json', () {
    YAGSLSwerveDriveModel yagslSwerveModel = YAGSLSwerveDriveModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/YAGSL Swerve Drive',
      period: 0.100,
      showRobotRotation: true,
      showDesiredStates: true,
      angleOffset: 90.0,
    );

    expect(yagslSwerveModel.toJson(), yagslSwerveJson);
  });

  testWidgets('YAGSL swerve drive widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel yagslSwerveModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'YAGSL Swerve Drive',
      yagslSwerveJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: yagslSwerveModel,
            child: const YAGSLSwerveDrive(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('YAGSL swerve drive edit properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    YAGSLSwerveDriveModel yagslSwerveModel = YAGSLSwerveDriveModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/YAGSL Swerve Drive',
      period: 0.100,
      showRobotRotation: true,
      showDesiredStates: true,
      angleOffset: 90.0,
    );

    NTWidgetContainerModel ntContainerModel = NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.zero,
      title: 'YAGSL Swerve Drive',
      childModel: yagslSwerveModel,
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
    expect(yagslSwerveModel.showRobotRotation, false);

    await widgetTester.tap(
      find.descendant(of: showDesiredStates, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();
    expect(yagslSwerveModel.showDesiredStates, false);

    await widgetTester.enterText(angleOffset, '45.0');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();
    expect(yagslSwerveModel.angleOffset, 45.0);
  });
}
