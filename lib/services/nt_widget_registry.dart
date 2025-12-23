import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/accelerometer.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/basic_swerve_drive.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/camera_stream.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/command_scheduler.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/command_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/differential_drive.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/encoder_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/field_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/fms_info.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/gyro.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/motor_controller.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/network_alerts.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/pid_controller.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/power_distribution.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/profiled_pid_controller.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/relay_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/robot_preferences.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/split_button_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/subsystem_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/three_axis_accelerometer.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/ultrasonic.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/yagsl_swerve_drive.dart';
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

typedef NTModelJsonProvider<T extends NTWidgetModel> =
    T Function({
      required Map<String, dynamic> jsonData,
      required NTConnection ntConnection,
      required SharedPreferences preferences,
    });

typedef NTModelProvider<T extends NTWidgetModel> =
    T Function({
      required NTConnection ntConnection,
      required SharedPreferences preferences,
      required String topic,
      NT4Type? dataType,
      double? period,
      NT4StructMeta? ntStructMeta,
    });

typedef MultiTopicNTModelProvider<T extends MultiTopicNTWidgetModel> =
    T Function({
      required NTConnection ntConnection,
      required SharedPreferences preferences,
      required String topic,
      double? period,
    });

typedef NTWidgetProvider<T extends NTWidget> = T Function({Key? key});

class NTWidgetRegistry {
  static final Map<String, NTWidgetProvider> _widgetNameBuildMap = {};

  static final Map<String, NTModelProvider> _modelNameBuildMap = {};

  static final Map<String, NTModelJsonProvider> _modelJsonBuildMap = {};

  static final Map<String, double> _minimumWidthMap = {};
  static final Map<String, double> _minimumHeightMap = {};

  static final Map<String, double> _defaultWidthMap = {};
  static final Map<String, double> _defaultHeightMap = {};

  static const double _normalSize = 128.0;

  NTWidgetRegistry._();

  static bool _initialized = false;
  static void ensureInitialized() {
    if (_initialized) {
      return;
    }

    logger.info('Configuring NT Widget Builder');

    registerSingleTopic(
      name: BooleanBox.widgetType,
      model: BooleanBoxModel.new,
      widget: BooleanBox.new,
      fromJson: BooleanBoxModel.fromJson,
    );

    registerSingleTopic(
      name: GraphWidget.widgetType,
      model: GraphModel.new,
      widget: GraphWidget.new,
      fromJson: GraphModel.fromJson,
      minWidth: _normalSize * 2,
      minHeight: _normalSize * 2,
    );

    registerSingleTopic(
      name: MatchTimeWidget.widgetType,
      model: MatchTimeModel.new,
      widget: MatchTimeWidget.new,
      fromJson: MatchTimeModel.fromJson,
    );

    registerSingleTopic(
      name: NumberBar.widgetType,
      model: NumberBarModel.new,
      widget: NumberBar.new,
      fromJson: NumberBarModel.fromJson,
      minHeight: _normalSize,
    );

    registerSingleTopic(
      name: NumberSlider.widgetType,
      model: NumberSliderModel.new,
      widget: NumberSlider.new,
      fromJson: NumberSliderModel.fromJson,
      minHeight: _normalSize,
    );

    registerSingleTopic(
      name: RadialGaugeWidget.widgetType,
      aliases: {'Simple Dial'},
      model: RadialGaugeModel.new,
      widget: RadialGaugeWidget.new,
      fromJson: RadialGaugeModel.fromJson,
      minWidth: _normalSize * 1.6,
      minHeight: _normalSize * 1.6,
    );

    registerSingleTopic(
      name: TextDisplay.widgetType,
      aliases: {'Text View'},
      model: TextDisplayModel.new,
      widget: TextDisplay.new,
      fromJson: TextDisplayModel.fromJson,
    );

    registerSingleTopic(
      name: VoltageView.widgetType,
      model: VoltageViewModel.new,
      widget: VoltageView.new,
      fromJson: VoltageViewModel.fromJson,
      minHeight: _normalSize,
    );

    registerMultiTopic(
      name: AccelerometerWidget.widgetType,
      model: AccelerometerModel.new,
      widget: AccelerometerWidget.new,
      fromJson: AccelerometerModel.fromJson,
    );

    registerMultiTopic(
      name: SwerveDriveWidget.widgetType,
      model: BasicSwerveModel.new,
      widget: SwerveDriveWidget.new,
      fromJson: BasicSwerveModel.fromJson,
      minWidth: _normalSize * 2,
      minHeight: _normalSize * 2,
      defaultWidth: 2,
      defaultHeight: 2,
    );

    registerMultiTopic(
      name: CameraStreamWidget.widgetType,
      model: CameraStreamModel.new,
      widget: CameraStreamWidget.new,
      fromJson: CameraStreamModel.fromJson,
      minWidth: _normalSize * 2,
      minHeight: _normalSize * 2,
      defaultWidth: 2,
      defaultHeight: 2,
    );

    registerMultiTopic(
      name: ComboBoxChooser.widgetType,
      aliases: {'String Chooser'},
      model: ComboBoxChooserModel.new,
      widget: ComboBoxChooser.new,
      fromJson: ComboBoxChooserModel.fromJson,
      minHeight: _normalSize * 0.85,
    );

    registerMultiTopic(
      name: CommandSchedulerWidget.widgetType,
      model: CommandSchedulerModel.new,
      widget: CommandSchedulerWidget.new,
      fromJson: CommandSchedulerModel.fromJson,
      minWidth: _normalSize * 2,
      minHeight: _normalSize * 2,
      defaultWidth: 2,
      defaultHeight: 3,
    );

    registerMultiTopic(
      name: CommandWidget.widgetType,
      model: CommandModel.new,
      widget: CommandWidget.new,
      fromJson: CommandModel.fromJson,
      minWidth: _normalSize * 2,
      minHeight: _normalSize * 0.90,
      defaultWidth: 2,
    );

    registerMultiTopic(
      name: DifferentialDrive.widgetType,
      aliases: {'Differential Drivebase'},
      model: DifferentialDriveModel.new,
      widget: DifferentialDrive.new,
      fromJson: DifferentialDriveModel.fromJson,
      minWidth: _normalSize * 2,
      minHeight: _normalSize * 2,
      defaultWidth: 3,
      defaultHeight: 2,
    );

    registerMultiTopic(
      name: EncoderWidget.widgetType,
      aliases: {'Quadrature Encoder'},
      model: EncoderModel.new,
      widget: EncoderWidget.new,
      fromJson: EncoderModel.fromJson,
      minWidth: _normalSize * 2,
      minHeight: _normalSize * 0.86,
      defaultWidth: 2,
    );

    registerMultiTopic(
      name: FieldWidget.widgetType,
      aliases: {'Field2d'},
      model: FieldWidgetModel.new,
      widget: FieldWidget.new,
      fromJson: FieldWidgetModel.fromJson,
      minWidth: _normalSize * 2,
      minHeight: _normalSize * 2,
      defaultWidth: 2,
      defaultHeight: 2,
    );

    registerMultiTopic(
      name: FMSInfo.widgetType,
      model: FMSInfoModel.new,
      widget: FMSInfo.new,
      fromJson: FMSInfoModel.fromJson,
      minWidth: _normalSize * 3,
      minHeight: _normalSize,
      defaultWidth: 3,
    );

    registerMultiTopic(
      name: Gyro.widgetType,
      model: GyroModel.new,
      widget: Gyro.new,
      fromJson: GyroModel.fromJson,
      minWidth: _normalSize * 2,
      minHeight: _normalSize * 2,
      defaultWidth: 2,
      defaultHeight: 2,
    );

    registerMultiTopic(
      name: MotorController.widgetType,
      aliases: {'Nidec Brushless'},
      model: MotorControllerModel.new,
      widget: MotorController.new,
      fromJson: MotorControllerModel.fromJson,
      minHeight: _normalSize * 0.92,
    );

    registerMultiTopic(
      name: NetworkAlerts.widgetType,
      model: NetworkAlertsModel.new,
      widget: NetworkAlerts.new,
      fromJson: NetworkAlertsModel.fromJson,
      minWidth: _normalSize * 2,
      minHeight: _normalSize * 2,
      defaultWidth: 2,
      defaultHeight: 3,
    );

    registerMultiTopic(
      name: PIDControllerWidget.widgetType,
      aliases: {'PID Controller'},
      model: PIDControllerModel.new,
      widget: PIDControllerWidget.new,
      fromJson: PIDControllerModel.fromJson,
      minWidth: _normalSize * 2,
      minHeight: _normalSize * 3,
      defaultWidth: 2,
      defaultHeight: 3,
    );

    registerMultiTopic(
      name: PowerDistribution.widgetType,
      aliases: {'PDP'},
      model: PowerDistributionModel.new,
      widget: PowerDistribution.new,
      fromJson: PowerDistributionModel.fromJson,
      minWidth: _normalSize * 3,
      minHeight: _normalSize * 3,
      defaultWidth: 3,
      defaultHeight: 4,
    );

    registerMultiTopic(
      name: ProfiledPIDControllerWidget.widgetType,
      model: ProfiledPIDControllerModel.new,
      widget: ProfiledPIDControllerWidget.new,
      fromJson: ProfiledPIDControllerModel.fromJson,
      minWidth: _normalSize * 2,
      minHeight: _normalSize * 3,
      defaultWidth: 2,
      defaultHeight: 3,
    );

    registerMultiTopic(
      name: RelayWidget.widgetType,
      model: RelayModel.new,
      widget: RelayWidget.new,
      fromJson: RelayModel.fromJson,
      minHeight: _normalSize * 2,
      defaultHeight: 2,
    );

    registerMultiTopic(
      name: RobotPreferences.widgetType,
      model: RobotPreferencesModel.new,
      widget: RobotPreferences.new,
      fromJson: RobotPreferencesModel.fromJson,
      minWidth: _normalSize * 2,
      minHeight: _normalSize * 2,
      defaultWidth: 2,
      defaultHeight: 3,
    );

    registerMultiTopic(
      name: SplitButtonChooser.widgetType,
      model: SplitButtonChooserModel.new,
      widget: SplitButtonChooser.new,
      fromJson: SplitButtonChooserModel.fromJson,
    );

    registerMultiTopic(
      name: SubsystemWidget.widgetType,
      model: SubsystemModel.new,
      widget: SubsystemWidget.new,
      fromJson: SubsystemModel.fromJson,
      minWidth: _normalSize * 2,
      defaultWidth: 2,
    );

    registerMultiTopic(
      name: ThreeAxisAccelerometer.widgetType,
      aliases: {'3AxisAccelerometer'},
      model: ThreeAxisAccelerometerModel.new,
      widget: ThreeAxisAccelerometer.new,
      fromJson: ThreeAxisAccelerometerModel.fromJson,
    );

    registerMultiTopic(
      name: Ultrasonic.widgetType,
      model: UltrasonicModel.new,
      widget: Ultrasonic.new,
      fromJson: UltrasonicModel.fromJson,
      minWidth: _normalSize * 2,
      defaultWidth: 2,
    );

    registerMultiTopic(
      name: YAGSLSwerveDrive.widgetType,
      model: YAGSLSwerveDriveModel.new,
      widget: YAGSLSwerveDrive.new,
      fromJson: YAGSLSwerveDriveModel.fromJson,
      minWidth: _normalSize * 2,
      minHeight: _normalSize * 2,
      defaultWidth: 2,
      defaultHeight: 2,
    );

    registerWithoutModel(
      name: LargeTextDisplay.widgetType,
      widget: LargeTextDisplay.new,
      minHeight: _normalSize * 0.8,
    );

    registerWithoutModel(
      name: ToggleButton.widgetType,
      widget: ToggleButton.new,
      minHeight: _normalSize * 0.8,
    );

    registerWithoutModel(
      name: ToggleSwitch.widgetType,
      widget: ToggleSwitch.new,
    );

    registerWithoutModel(
      name: SingleColorView.widgetType,
      widget: SingleColorView.new,
    );

    registerWithoutModel(
      name: MultiColorView.widgetType,
      widget: MultiColorView.new,
    );

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
    NT4StructMeta? ntStructMeta,
    String type,
    String topic, {
    NT4Type? dataType,
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
        ntStructMeta: ntStructMeta,
        dataType: dataType,
        period: period,
      );
    }

    return SingleTopicNTWidgetModel.createDefault(
      ntConnection: ntConnection,
      preferences: preferences,
      type: type,
      topic: topic,
      ntStructMeta: ntStructMeta,
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

    onWidgetTypeNotFound?.call(
      'Unknown widget type: \'$type\', defaulting to Empty Model.',
    );
    return SingleTopicNTWidgetModel.createDefault(
      ntConnection: ntConnection,
      preferences: preferences,
      type: type,
      topic: tryCast(jsonData['topic']) ?? '',
      dataType: NT4Type.parseNullable(tryCast(jsonData['data_type'])),
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
      _normalSize,
      widget.preferences.getInt(PrefKeys.gridSize),
    );

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
      _normalSize,
      widget.preferences.getInt(PrefKeys.gridSize),
    );

    if (snappedNormal < _normalSize) {
      snappedNormal +=
          widget.preferences.getInt(PrefKeys.gridSize) ?? Defaults.gridSize;
    }

    if (_defaultHeightMap.containsKey(widget.type)) {
      return snappedNormal * _defaultHeightMap[widget.type]!;
    }
    return snappedNormal;
  }

  static double getNormalSize([int? gridSize]) =>
      DraggableWidgetContainer.snapToGrid(_normalSize, gridSize);

  static bool isRegistered(String name) {
    ensureInitialized();

    return (_modelNameBuildMap.containsKey(name) &&
            _modelJsonBuildMap.containsKey(name)) ||
        _widgetNameBuildMap.containsKey(name);
  }

  static void registerSingleTopic<
    ModelType extends SingleTopicNTWidgetModel,
    WidgetType extends NTWidget
  >({
    required String name,
    Set<String>? aliases,
    required NTModelProvider<ModelType> model,
    required NTWidgetProvider<WidgetType> widget,
    required NTModelJsonProvider<ModelType> fromJson,
    double? minWidth,
    double? minHeight,
    double? defaultWidth,
    double? defaultHeight,
  }) => registerWithAlias(
    names: {name, ...?aliases},
    model: model,
    widget: widget,
    fromJson: fromJson,
    minWidth: minWidth,
    minHeight: minHeight,
    defaultWidth: defaultWidth,
    defaultHeight: defaultHeight,
  );

  static void registerMultiTopic<
    ModelType extends MultiTopicNTWidgetModel,
    WidgetType extends NTWidget
  >({
    required String name,
    Set<String>? aliases,
    required MultiTopicNTModelProvider<ModelType> model,
    required NTWidgetProvider<WidgetType> widget,
    required NTModelJsonProvider<ModelType> fromJson,
    double? minWidth,
    double? minHeight,
    double? defaultWidth,
    double? defaultHeight,
  }) => registerWithAlias(
    names: {name, ...?aliases},
    model:
        ({
          required NTConnection ntConnection,
          required SharedPreferences preferences,
          required String topic,
          double? period,
          NT4Type? dataType,
          NT4StructMeta? ntStructMeta,
        }) => model(
          ntConnection: ntConnection,
          preferences: preferences,
          topic: topic,
          period: period,
        ),
    widget: widget,
    fromJson: fromJson,
    minWidth: minWidth,
    minHeight: minHeight,
    defaultWidth: defaultWidth,
    defaultHeight: defaultHeight,
  );

  static void registerWithoutModel<WidgetType extends NTWidget>({
    required String name,
    Set<String>? aliases,
    required NTWidgetProvider<WidgetType> widget,
    double? minWidth,
    double? minHeight,
    double? defaultWidth,
    double? defaultHeight,
  }) => registerWithAlias(
    names: {name, ...?aliases},
    model:
        ({
          required NTConnection ntConnection,
          required SharedPreferences preferences,
          required String topic,
          double? period,
          NT4Type? dataType,
          NT4StructMeta? ntStructMeta,
        }) => SingleTopicNTWidgetModel.createDefault(
          ntConnection: ntConnection,
          preferences: preferences,
          topic: topic,
          period: period,
          type: name,
          dataType: dataType,
          ntStructMeta: ntStructMeta,
        ),
    widget: widget,
    fromJson:
        ({required jsonData, required ntConnection, required preferences}) =>
            SingleTopicNTWidgetModel.createDefaultFromJson(
              ntConnection: ntConnection,
              preferences: preferences,
              jsonData: jsonData,
              type: name,
            ),
    minWidth: minWidth,
    minHeight: minHeight,
    defaultWidth: defaultWidth,
    defaultHeight: defaultHeight,
  );

  static void
  register<ModelType extends NTWidgetModel, WidgetType extends NTWidget>({
    required String name,
    required NTModelProvider<ModelType> model,
    required NTWidgetProvider<WidgetType> widget,
    required NTModelJsonProvider<ModelType> fromJson,
    required double? minWidth,
    required double? minHeight,
    required double? defaultWidth,
    required double? defaultHeight,
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

  static void registerWithAlias<
    ModelType extends NTWidgetModel,
    WidgetType extends NTWidget
  >({
    required Set<String> names,
    required NTModelProvider<ModelType> model,
    required NTWidgetProvider<WidgetType> widget,
    required NTModelJsonProvider<ModelType> fromJson,
    required double? minWidth,
    required double? minHeight,
    required double? defaultWidth,
    required double? defaultHeight,
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
