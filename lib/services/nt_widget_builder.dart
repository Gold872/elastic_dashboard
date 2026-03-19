import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/limelight.dart';
import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/accelerometer.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/basic_swerve_drive.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/camera_stream.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/command_scheduler.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/command_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/differential_drive.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/encoder_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/field_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/fms_info.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/gyro.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/motion_magic_config.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/motor_controller.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/network_alerts.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/pid_controller.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/pid_ff_config.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/power_distribution.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/profiled_pid_controller.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/recording.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/reef.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/relay_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/robot_preferences.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/split_button_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/subsystem_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/talon_motor.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/three_axis_accelerometer.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/ultrasonic.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi-topic/yagsl_swerve_drive.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/boolean_box.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/graph.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/large_text_display.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/match_time.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/multi_color_view.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/number_bar.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/number_slider.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/radial_gauge.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/single_color_view.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/text_display.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/toggle_button.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/voltage_view.dart';

typedef NTModelJsonProvider = NTWidgetModel Function({
  required Map<String, dynamic> jsonData,
  required NTConnection ntConnection,
  required SharedPreferences preferences,
});

typedef NTModelProvider = NTWidgetModel Function({
  String dataType,
  required NTConnection ntConnection,
  double period,
  required SharedPreferences preferences,
  required String topic,
});

typedef NTWidgetProvider = NTWidget Function({Key? key});

class NTWidgetBuilder {
  static final Map<String, NTWidgetProvider> _widgetNameBuildMap = {};

  static final Map<String, NTModelProvider> _modelNameBuildMap = {};

  static final Map<String, NTModelJsonProvider> _modelJsonBuildMap = {};

  static final Map<String, double> _minimumWidthMap = {};
  static final Map<String, double> _minimumHeightMap = {};

  static final Map<String, double> _defaultWidthMap = {};
  static final Map<String, double> _defaultHeightMap = {};

  static const double _normalSize = 128.0;

  NTWidgetBuilder._();

  static bool _initialized = false;
  static void ensureInitialized() {
    if (_initialized) {
      return;
    }

    logger.info('Configuring NT Widget Builder');

    register(
        name: BooleanBox.widgetType,
        model: BooleanBoxModel.new,
        widget: BooleanBox.new,
        fromJson: BooleanBoxModel.fromJson);

    register(
        name: GraphWidget.widgetType,
        model: GraphModel.new,
        widget: GraphWidget.new,
        fromJson: GraphModel.fromJson,
        minWidth: _normalSize * 2,
        minHeight: _normalSize * 2);

    register(name: LimelightWiget.widgetType, model: LimelightModel.new, widget: LimelightWiget.new, fromJson: LimelightModel.fromJson);


    register(
        name: MatchTimeWidget.widgetType,
        model: MatchTimeModel.new,
        widget: MatchTimeWidget.new,
        fromJson: MatchTimeModel.fromJson);

    register(
        name: NumberBar.widgetType,
        model: NumberBarModel.new,
        widget: NumberBar.new,
        fromJson: NumberBarModel.fromJson,
        minHeight: _normalSize);

    register(
        name: NumberSlider.widgetType,
        model: NumberSliderModel.new,
        widget: NumberSlider.new,
        fromJson: NumberSliderModel.fromJson,
        minHeight: _normalSize);

    registerWithAlias(
        names: {RadialGaugeWidget.widgetType, 'Simple Dial'},
        model: RadialGaugeModel.new,
        widget: RadialGaugeWidget.new,
        fromJson: RadialGaugeModel.fromJson,
        minWidth: _normalSize * 1.6,
        minHeight: _normalSize * 1.6);

    registerWithAlias(
        names: {TextDisplay.widgetType, 'Text View'},
        model: TextDisplayModel.new,
        widget: TextDisplay.new,
        fromJson: TextDisplayModel.fromJson);

    register(
        name: VoltageView.widgetType,
        model: VoltageViewModel.new,
        widget: VoltageView.new,
        fromJson: VoltageViewModel.fromJson,
        minHeight: _normalSize);

    register(
        name: AccelerometerWidget.widgetType,
        model: AccelerometerModel.new,
        widget: AccelerometerWidget.new,
        fromJson: AccelerometerModel.fromJson);

    register(
      name: TalonMotorWidget.widgetType,
      model: TalonMotorModel.new,
      widget: TalonMotorWidget.new,
      fromJson: TalonMotorModel.fromJson,
      minHeight: _normalSize * 2,
      minWidth: _normalSize * 2,
      defaultHeight: 2,
      defaultWidth: 2,
    );

    register(
        name: PidFfConfigWidget.widgetType,
        model: PidFfConfigModel.new,
        widget: PidFfConfigWidget.new,
        fromJson: PidFfConfigModel.fromJson,
        minWidth: _normalSize * 3,
        minHeight: _normalSize * 3,
        defaultWidth: 3,
        defaultHeight: 3);

    register(
        name: MotionMagicConfigWidget.widgetType,
        model: MotionMagicConfigModel.new,
        widget: MotionMagicConfigWidget.new,
        fromJson: MotionMagicConfigModel.fromJson,
        minWidth: _normalSize * 2,
        minHeight: _normalSize * 3,
        defaultWidth: 2,
        defaultHeight: 3);

    register(
      name: RecordingWidget.widgetType,
      model: RecordingModel.new,
      widget: RecordingWidget.new,
      fromJson: RecordingModel.fromJson,
    );

    register(
      name: ReefWidget.widgetType,
      model: ReefModel.new,
      widget: ReefWidget.new,
      fromJson: ReefModel.fromJson,
      minWidth: _normalSize * 4,
      minHeight: _normalSize * 3,
      defaultWidth: 4,
      defaultHeight: 3,
    );

    register(
        name: SwerveDriveWidget.widgetType,
        model: BasicSwerveModel.new,
        widget: SwerveDriveWidget.new,
        fromJson: BasicSwerveModel.fromJson,
        minWidth: _normalSize * 2,
        minHeight: _normalSize * 2,
        defaultWidth: 2,
        defaultHeight: 2);

    register(
        name: CameraStreamWidget.widgetType,
        model: CameraStreamModel.new,
        widget: CameraStreamWidget.new,
        fromJson: CameraStreamModel.fromJson,
        minWidth: _normalSize * 2,
        minHeight: _normalSize * 2,
        defaultWidth: 2,
        defaultHeight: 2);

    registerWithAlias(
        names: {ComboBoxChooser.widgetType, 'String Chooser'},
        model: ComboBoxChooserModel.new,
        widget: ComboBoxChooser.new,
        fromJson: ComboBoxChooserModel.fromJson,
        minHeight: _normalSize * 0.85);

    register(
        name: CommandSchedulerWidget.widgetType,
        model: CommandSchedulerModel.new,
        widget: CommandSchedulerWidget.new,
        fromJson: CommandSchedulerModel.fromJson,
        minWidth: _normalSize * 2,
        minHeight: _normalSize * 2,
        defaultWidth: 2,
        defaultHeight: 3);

    register(
        name: CommandWidget.widgetType,
        model: CommandModel.new,
        widget: CommandWidget.new,
        fromJson: CommandModel.fromJson,
        minWidth: _normalSize * 2,
        minHeight: _normalSize * 0.90,
        defaultWidth: 2);

    registerWithAlias(
        names: {DifferentialDrive.widgetType, 'Differential Drivebase'},
        model: DifferentialDriveModel.new,
        widget: DifferentialDrive.new,
        fromJson: DifferentialDriveModel.fromJson,
        minWidth: _normalSize * 2,
        minHeight: _normalSize * 2,
        defaultWidth: 3,
        defaultHeight: 2);

    registerWithAlias(
        names: {EncoderWidget.widgetType, 'Quadrature Encoder'},
        model: EncoderModel.new,
        widget: EncoderWidget.new,
        fromJson: EncoderModel.fromJson,
        minWidth: _normalSize * 2,
        minHeight: _normalSize * 0.86,
        defaultWidth: 2);

    registerWithAlias(
        names: {FieldWidget.widgetType, 'Field2d'},
        model: FieldWidgetModel.new,
        widget: FieldWidget.new,
        fromJson: FieldWidgetModel.fromJson,
        minWidth: _normalSize * 2,
        minHeight: _normalSize * 2,
        defaultWidth: 2,
        defaultHeight: 2);

    register(
        name: FMSInfo.widgetType,
        model: FMSInfoModel.new,
        widget: FMSInfo.new,
        fromJson: FMSInfoModel.fromJson,
        minWidth: _normalSize * 3,
        minHeight: _normalSize,
        defaultWidth: 3);

    register(
        name: Gyro.widgetType,
        model: GyroModel.new,
        widget: Gyro.new,
        fromJson: GyroModel.fromJson,
        minWidth: _normalSize * 2,
        minHeight: _normalSize * 2,
        defaultWidth: 2,
        defaultHeight: 2);

    registerWithAlias(
        names: {MotorController.widgetType, 'Nidec Brushless'},
        model: MotorControllerModel.new,
        widget: MotorController.new,
        fromJson: MotorControllerModel.fromJson,
        minHeight: _normalSize * 0.92);

    register(
        name: NetworkAlerts.widgetType,
        model: NetworkAlertsModel.new,
        widget: NetworkAlerts.new,
        fromJson: NetworkAlertsModel.fromJson,
        minWidth: _normalSize * 2,
        minHeight: _normalSize * 2,
        defaultWidth: 2,
        defaultHeight: 3);

    registerWithAlias(
        names: {PIDControllerWidget.widgetType, 'PID Controller'},
        model: PIDControllerModel.new,
        widget: PIDControllerWidget.new,
        fromJson: PIDControllerModel.fromJson,
        minWidth: _normalSize * 2,
        minHeight: _normalSize * 3,
        defaultWidth: 2,
        defaultHeight: 3);

    registerWithAlias(
        names: {PowerDistribution.widgetType, 'PDP'},
        model: PowerDistributionModel.new,
        widget: PowerDistribution.new,
        fromJson: PowerDistributionModel.fromJson,
        minWidth: _normalSize * 3,
        minHeight: _normalSize * 3,
        defaultWidth: 3,
        defaultHeight: 4);

    register(
        name: ProfiledPIDControllerWidget.widgetType,
        model: ProfiledPIDControllerModel.new,
        widget: ProfiledPIDControllerWidget.new,
        fromJson: ProfiledPIDControllerModel.fromJson,
        minWidth: _normalSize * 2,
        minHeight: _normalSize * 3,
        defaultWidth: 2,
        defaultHeight: 3);

    register(
        name: RelayWidget.widgetType,
        model: RelayModel.new,
        widget: RelayWidget.new,
        fromJson: RelayModel.fromJson,
        minHeight: _normalSize * 2,
        defaultHeight: 2);

    register(
        name: RobotPreferences.widgetType,
        model: RobotPreferencesModel.new,
        widget: RobotPreferences.new,
        fromJson: RobotPreferencesModel.fromJson,
        minWidth: _normalSize * 2,
        minHeight: _normalSize * 2,
        defaultWidth: 2,
        defaultHeight: 3);

    register(
        name: SplitButtonChooser.widgetType,
        model: SplitButtonChooserModel.new,
        widget: SplitButtonChooser.new,
        fromJson: SplitButtonChooserModel.fromJson);

    register(
        name: SubsystemWidget.widgetType,
        model: SubsystemModel.new,
        widget: SubsystemWidget.new,
        fromJson: SubsystemModel.fromJson,
        minWidth: _normalSize * 2,
        defaultWidth: 2);

    registerWithAlias(
        names: {ThreeAxisAccelerometer.widgetType, '3AxisAccelerometer'},
        model: ThreeAxisAccelerometerModel.new,
        widget: ThreeAxisAccelerometer.new,
        fromJson: ThreeAxisAccelerometerModel.fromJson);

    register(
        name: Ultrasonic.widgetType,
        model: UltrasonicModel.new,
        widget: Ultrasonic.new,
        fromJson: UltrasonicModel.fromJson,
        minWidth: _normalSize * 2,
        defaultWidth: 2);

    register(
        name: YAGSLSwerveDrive.widgetType,
        model: YAGSLSwerveDriveModel.new,
        widget: YAGSLSwerveDrive.new,
        fromJson: YAGSLSwerveDriveModel.fromJson,
        minWidth: _normalSize * 2,
        minHeight: _normalSize * 2,
        defaultWidth: 2,
        defaultHeight: 2);

    _widgetNameBuildMap.addAll({
      LargeTextDisplay.widgetType: LargeTextDisplay.new,
      ToggleButton.widgetType: ToggleButton.new,
      ToggleSwitch.widgetType: ToggleSwitch.new,
      SingleColorView.widgetType: SingleColorView.new,
      MultiColorView.widgetType: MultiColorView.new,
    });

    _initialized = true;
  }

  static NTWidget? buildNTWidgetFromModel(NTWidgetModel model, {Key? key}) {
    ensureInitialized();

    if (_widgetNameBuildMap.containsKey(model.type)) {
      return _widgetNameBuildMap[model.type]!(key: key);
    }
    return null;
  }

  static NTWidgetModel buildNTModelFromType(
    NTConnection ntConnection,
    SharedPreferences preferences,
    String type,
    String topic, {
    String dataType = 'Unknown',
    double? period,
  }) {
    period ??=
        preferences.getDouble(PrefKeys.defaultPeriod) ?? Defaults.defaultPeriod;

    ensureInitialized();

    if (_modelNameBuildMap.containsKey(type)) {
      return _modelNameBuildMap[type]!(
        ntConnection: ntConnection,
        preferences: preferences,
        topic: topic,
        dataType: dataType,
        period: period,
      );
    }

    return SingleTopicNTWidgetModel.createDefault(
      ntConnection: ntConnection,
      preferences: preferences,
      type: type,
      topic: topic,
      dataType: dataType,
      period: period,
    );
  }

  static NTWidgetModel buildNTModelFromJson(
    NTConnection ntConnection,
    SharedPreferences preferences,
    String type,
    Map<String, dynamic> jsonData, {
    Function(String message)? onWidgetTypeNotFound,
  }) {
    ensureInitialized();

    if (_modelJsonBuildMap.containsKey(type)) {
      return _modelJsonBuildMap[type]!(
        ntConnection: ntConnection,
        preferences: preferences,
        jsonData: jsonData,
      );
    }

    onWidgetTypeNotFound
        ?.call('Unknown widget type: \'$type\', defaulting to Empty Model.');
    return SingleTopicNTWidgetModel.createDefault(
      ntConnection: ntConnection,
      preferences: preferences,
      type: type,
      topic: tryCast(jsonData['topic']) ?? '',
      dataType: tryCast(jsonData['data_type']) ?? 'Unknown',
      period: tryCast(jsonData['period']),
    );
  }

  static double getMinimumWidth(NTWidgetModel widget) {
    ensureInitialized();

    if (_minimumWidthMap.containsKey(widget.type)) {
      return _minimumWidthMap[widget.type]!;
    } else {
      return (widget.preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize)
          .toDouble();
    }
  }

  static double getMinimumHeight(NTWidgetModel widget) {
    ensureInitialized();

    if (_minimumHeightMap.containsKey(widget.type)) {
      return _minimumHeightMap[widget.type]!;
    } else {
      return (widget.preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize)
          .toDouble();
    }
  }

  static double getDefaultWidth(NTWidgetModel widget) {
    ensureInitialized();

    double snappedNormal = DraggableWidgetContainer.snapToGrid(
        _normalSize, widget.preferences.getInt(PrefKeys.gridSize));

    if (snappedNormal < _normalSize) {
      snappedNormal +=
          widget.preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize;
    }

    if (_defaultWidthMap.containsKey(widget.type)) {
      return snappedNormal * _defaultWidthMap[widget.type]!;
    }
    return snappedNormal;
  }

  static double getDefaultHeight(NTWidgetModel widget) {
    ensureInitialized();

    double snappedNormal = DraggableWidgetContainer.snapToGrid(
        _normalSize, widget.preferences.getInt(PrefKeys.gridSize));

    if (snappedNormal < _normalSize) {
      snappedNormal +=
          widget.preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize;
    }

    if (_defaultHeightMap.containsKey(widget.type)) {
      return snappedNormal * _defaultHeightMap[widget.type]!;
    }
    return snappedNormal;
  }

  static double getNormalSize([int? gridSize]) {
    return DraggableWidgetContainer.snapToGrid(_normalSize, gridSize);
  }

  static bool isRegistered(String name) {
    ensureInitialized();

    return (_modelNameBuildMap.containsKey(name) &&
            _modelJsonBuildMap.containsKey(name)) ||
        _widgetNameBuildMap.containsKey(name);
  }

  static void
      register<ModelType extends NTWidgetModel, WidgetType extends NTWidget>({
    required String name,
    required NTModelProvider model,
    required NTWidgetProvider widget,
    required NTModelJsonProvider fromJson,
    double? minWidth,
    double? minHeight,
    double? defaultWidth,
    double? defaultHeight,
  }) {
    _modelNameBuildMap.addAll({name: model});
    _modelJsonBuildMap.addAll({name: fromJson});
    _widgetNameBuildMap.addAll({name: widget});

    if (minWidth != null) {
      _minimumWidthMap.addAll({name: minWidth});
    }
    if (minHeight != null) {
      _minimumHeightMap.addAll({name: minHeight});
    }
    if (defaultWidth != null) {
      _defaultWidthMap.addAll({name: defaultWidth});
    }
    if (defaultHeight != null) {
      _defaultHeightMap.addAll({name: defaultHeight});
    }
  }

  static void registerWithAlias<ModelType extends SingleTopicNTWidgetModel,
      WidgetType extends NTWidget>({
    required Set<String> names,
    required NTModelProvider model,
    required NTWidgetProvider widget,
    required NTModelJsonProvider fromJson,
    double? minWidth,
    double? minHeight,
    double? defaultWidth,
    double? defaultHeight,
  }) {
    for (String name in names) {
      register(
        name: name,
        model: model,
        widget: widget,
        fromJson: fromJson,
        minHeight: minHeight,
        minWidth: minWidth,
        defaultHeight: defaultHeight,
        defaultWidth: defaultWidth,
      );
    }
  }
}
