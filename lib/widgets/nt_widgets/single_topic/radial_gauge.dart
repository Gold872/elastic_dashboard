import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class RadialGaugeModel extends SingleTopicNTWidgetModel {
  @override
  String type = RadialGaugeWidget.widgetType;

  double _startAngle = -140.0;
  double _endAngle = 140.0;
  double _minValue = 0.0;
  double _maxValue = 100.0;

  int _numberOfLabels = 8;

  bool _wrapValue = false;
  bool _showPointer = true;
  bool _showTicks = true;

  double get startAngle => _startAngle;

  set startAngle(double value) {
    _startAngle = value;
    refresh();
  }

  double get endAngle => _endAngle;

  set endAngle(double value) {
    _endAngle = value;
    refresh();
  }

  double get minValue => _minValue;

  set minValue(double value) {
    _minValue = value;
    refresh();
  }

  double get maxValue => _maxValue;

  set maxValue(double value) {
    _maxValue = value;
    refresh();
  }

  int get numberOfLabels => _numberOfLabels;

  set numberOfLabels(int value) {
    _numberOfLabels = value;
    refresh();
  }

  bool get wrapValue => _wrapValue;

  set wrapValue(bool value) {
    _wrapValue = value;
    refresh();
  }

  bool get showPointer => _showPointer;

  set showPointer(bool value) {
    _showPointer = value;
    refresh();
  }

  bool get showTicks => _showTicks;

  set showTicks(bool value) {
    _showTicks = value;
    refresh();
  }

  RadialGaugeModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    double startAngle = -140.0,
    double endAngle = 140.0,
    double minValue = 0.0,
    double maxValue = 100.0,
    int numberOfLabels = 8,
    bool wrapValue = false,
    bool showPointer = true,
    bool showTicks = true,
    super.ntStructMeta,
    super.dataType,
    super.period,
  }) : _wrapValue = wrapValue,
       _showTicks = showTicks,
       _showPointer = showPointer,
       _numberOfLabels = numberOfLabels,
       _maxValue = maxValue,
       _minValue = minValue,
       _startAngle = startAngle,
       _endAngle = endAngle,
       super();

  RadialGaugeModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _startAngle = tryCast(jsonData['start_angle']) ?? _startAngle;
    _endAngle = tryCast(jsonData['end_angle']) ?? _endAngle;
    _minValue = tryCast(jsonData['min_value']) ?? _minValue;
    _maxValue = tryCast(jsonData['max_value']) ?? _maxValue;

    _numberOfLabels = tryCast(jsonData['number_of_labels']) ?? _numberOfLabels;

    _wrapValue = tryCast(jsonData['wrap_value']) ?? _wrapValue;
    _showPointer = tryCast(jsonData['show_pointer']) ?? _showPointer;
    _showTicks = tryCast(jsonData['show_ticks']) ?? _showTicks;
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'start_angle': _startAngle,
    'end_angle': _endAngle,
    'min_value': _minValue,
    'max_value': _maxValue,
    'number_of_labels': _numberOfLabels,
    'wrap_value': _wrapValue,
    'show_pointer': _showPointer,
    'show_ticks': _showTicks,
  };

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    // Start/End angles
    Row(
      children: [
        Flexible(
          child: DialogTextInput(
            label: 'Start Angle (CW+)',
            initialText: _startAngle.toString(),
            formatter: TextFormatterBuilder.decimalTextFormatter(
              allowNegative: true,
            ),
            onSubmit: (value) {
              double? newStartAngle = double.tryParse(value);

              if (newStartAngle == null) {
                return;
              }
              startAngle = newStartAngle;
            },
          ),
        ),
        Flexible(
          child: DialogTextInput(
            label: 'End Angle (CW+)',
            initialText: _endAngle.toString(),
            formatter: TextFormatterBuilder.decimalTextFormatter(
              allowNegative: true,
            ),
            onSubmit: (value) {
              double? newEndAngle = double.tryParse(value);

              if (newEndAngle == null) {
                return;
              }
              endAngle = newEndAngle;
            },
          ),
        ),
      ],
    ),
    const SizedBox(height: 5),
    // Min/Max values
    Row(
      children: [
        Flexible(
          child: DialogTextInput(
            label: 'Min Value',
            initialText: _minValue.toString(),
            formatter: TextFormatterBuilder.decimalTextFormatter(
              allowNegative: true,
            ),
            onSubmit: (value) {
              double? newMin = double.tryParse(value);

              if (newMin == null) {
                return;
              }
              minValue = newMin;
            },
          ),
        ),
        Flexible(
          child: DialogTextInput(
            label: 'Max Value',
            initialText: _maxValue.toString(),
            formatter: TextFormatterBuilder.decimalTextFormatter(
              allowNegative: true,
            ),
            onSubmit: (value) {
              double? newMax = double.tryParse(value);

              if (newMax == null) {
                return;
              }
              maxValue = newMax;
            },
          ),
        ),
      ],
    ),
    const SizedBox(height: 5),
    // Wrap value & Show pointer
    Row(
      children: [
        Flexible(
          child: DialogToggleSwitch(
            label: 'Wrap Value',
            initialValue: _wrapValue,
            onToggle: (value) {
              wrapValue = value;
            },
          ),
        ),
        Flexible(
          child: DialogToggleSwitch(
            label: 'Show Pointer',
            initialValue: _showPointer,
            onToggle: (value) {
              showPointer = value;
            },
          ),
        ),
      ],
    ),
    const SizedBox(height: 5),
    // Label & tick customization
    Row(
      children: [
        Flexible(
          child: DialogTextInput(
            label: 'Number of Labels',
            initialText: _numberOfLabels.toString(),
            formatter: FilteringTextInputFormatter.digitsOnly,
            onSubmit: (value) {
              int? newLabelCount = int.tryParse(value);

              if (newLabelCount == null) {
                return;
              }

              numberOfLabels = newLabelCount;
            },
          ),
        ),
        Flexible(
          child: DialogToggleSwitch(
            label: 'Show Ticks',
            initialValue: _showTicks,
            onToggle: (value) {
              showTicks = value;
            },
          ),
        ),
      ],
    ),
  ];
}

class RadialGaugeWidget extends NTWidget {
  static const String widgetType = 'Radial Gauge';

  const RadialGaugeWidget({super.key});

  static double _getWrappedValue(double value, double min, double max) {
    if (value >= min && value <= max) {
      return value;
    }
    double modulus = max - min;

    // Wrap input if it's above the maximum input
    int numMax = (value - min) ~/ modulus;
    value -= numMax * modulus;

    // Wrap input if it's below the minimum input
    int numMin = (value - max) ~/ modulus;
    value -= numMin * modulus;

    return value;
  }

  @override
  Widget build(BuildContext context) {
    RadialGaugeModel model = cast(context.watch<NTWidgetModel>());

    return ValueListenableBuilder(
      valueListenable: model.subscription ?? ValueNotifier(null),
      builder: (context, data, child) {
        double value = tryCast<num>(data)?.toDouble() ?? 0.0;

        if (model.wrapValue) {
          value = _getWrappedValue(value, model.minValue, model.maxValue);
        }

        value = value.clamp(model.minValue, model.maxValue);

        int fractionDigits = (model.dataType == NT4Type.int()) ? 0 : 2;

        return LayoutBuilder(
          builder: (context, constraints) {
            double squareSide = min(
              constraints.maxWidth,
              constraints.maxHeight,
            );

            return Stack(
              alignment: Alignment.center,
              children: [
                RadialGauge(
                  track: RadialTrack(
                    start: model.minValue,
                    end: model.maxValue,
                    startAngle: model.startAngle + 90,
                    endAngle: model.endAngle + 90,
                    steps: model.numberOfLabels,
                    color: const Color.fromRGBO(97, 97, 97, 1),
                    trackStyle: TrackStyle(
                      primaryRulerColor: Colors.grey,
                      secondaryRulerColor: Colors.grey,
                      showPrimaryRulers: model.showTicks,
                      showSecondaryRulers: model.showTicks,
                      labelStyle: Theme.of(context).textTheme.bodySmall,
                      primaryRulersHeight: model.showTicks ? 10 : 0,
                      secondaryRulersHeight: model.showTicks ? 8 : 0,
                      rulersOffset: -5,
                      labelOffset: -10,
                      showLastLabel:
                          _getWrappedValue(
                            model.endAngle - model.startAngle,
                            -180.0,
                            180.0,
                          ) !=
                          0.0,
                    ),
                    trackLabelFormater: (value) =>
                        num.parse(value.toStringAsFixed(2)).toString(),
                  ),
                  needlePointer: [
                    if (model.showPointer)
                      NeedlePointer(
                        needleWidth: squareSide * 0.02,
                        needleEndWidth: squareSide * 0.004,
                        needleHeight: squareSide * 0.25,
                        tailColor: Colors.grey,
                        tailRadius: squareSide * 0.075,
                        value: value,
                      ),
                  ],
                  valueBar: [
                    RadialValueBar(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      value: value,
                      startPosition: (model.minValue < 0.0) ? 0.0 : null,
                    ),
                  ],
                ),
                if (model.showPointer)
                  Container(
                    width: squareSide * 0.05,
                    height: squareSide * 0.05,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[300]!,
                    ),
                  ),
                Positioned(
                  bottom: squareSide * 0.3,
                  child: Text(
                    value.toStringAsFixed(fractionDigits),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
