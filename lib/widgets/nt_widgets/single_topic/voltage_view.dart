import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class VoltageViewModel extends SingleTopicNTWidgetModel {
  @override
  String type = VoltageView.widgetType;

  double _minValue = 4.0;
  double _maxValue = 13.0;
  int _divisions = 5;
  bool _inverted = false;
  String _orientation = 'horizontal';

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

  int get divisions => _divisions;

  set divisions(int value) {
    _divisions = value;
    refresh();
  }

  bool get inverted => _inverted;

  set inverted(bool value) {
    _inverted = value;
    refresh();
  }

  String get orientation => _orientation;

  set orientation(String value) {
    _orientation = value;
    refresh();
  }

  VoltageViewModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    double minValue = 4.0,
    double maxValue = 13.0,
    int divisions = 5,
    bool inverted = false,
    String orientation = 'horizontal',
    super.ntStructMeta,
    super.dataType,
    super.period,
  }) : _orientation = orientation,
       _divisions = divisions,
       _inverted = inverted,
       _maxValue = maxValue,
       _minValue = minValue,
       super();

  VoltageViewModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _minValue = tryCast(jsonData['min_value']) ?? 4.0;
    _maxValue = tryCast(jsonData['max_value']) ?? 13.0;
    _divisions = tryCast(jsonData['divisions']) ?? 5;
    _inverted = tryCast(jsonData['inverted']) ?? false;
    _orientation = tryCast(jsonData['orientation']) ?? 'horizontal';
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'min_value': minValue,
    'max_value': maxValue,
    'divisions': divisions,
    'inverted': inverted,
    'orientation': orientation,
  };

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    // Orientation
    Column(
      children: [
        const Text('Orientation'),
        DialogDropdownChooser<String>(
          initialValue:
              '${_orientation[0].toUpperCase()}${_orientation.substring(1)}',
          choices: const ['Horizontal', 'Vertical'],
          onSelectionChanged: (value) {
            if (value == null) {
              return;
            }

            orientation = value.toLowerCase();
          },
        ),
      ],
    ),
    const SizedBox(height: 5),
    // Min and max values
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          child: DialogTextInput(
            onSubmit: (value) {
              double? newMin = double.tryParse(value);
              if (newMin == null) {
                return;
              }
              minValue = newMin;
            },
            formatter: TextFormatterBuilder.decimalTextFormatter(
              allowNegative: true,
            ),
            label: 'Min Value',
            initialText: _minValue.toString(),
          ),
        ),
        Flexible(
          child: DialogTextInput(
            onSubmit: (value) {
              double? newMax = double.tryParse(value);
              if (newMax == null) {
                return;
              }
              maxValue = newMax;
            },
            formatter: TextFormatterBuilder.decimalTextFormatter(
              allowNegative: true,
            ),
            label: 'Max Value',
            initialText: _maxValue.toString(),
          ),
        ),
      ],
    ),
    const SizedBox(height: 5),
    // Number of divisions and orientation
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: DialogTextInput(
            onSubmit: (value) {
              int? newDivisions = int.tryParse(value);
              if (newDivisions == null || newDivisions < 2) {
                return;
              }
              divisions = newDivisions;
            },
            formatter: FilteringTextInputFormatter.digitsOnly,
            label: 'Divisions',
            initialText: _divisions.toString(),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Center(
            child: DialogToggleSwitch(
              initialValue: _inverted,
              label: 'Inverted',
              onToggle: (value) {
                inverted = value;
              },
            ),
          ),
        ),
      ],
    ),
  ];
}

class VoltageView extends NTWidget {
  static const String widgetType = 'Voltage View';

  const VoltageView({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    VoltageViewModel model = cast(context.watch<NTWidgetModel>());

    String formatLabel(num input) =>
        input.toStringAsFixed(input.truncateToDouble() == input ? 0 : 2);

    return ValueListenableBuilder(
      valueListenable: model.subscription ?? ValueNotifier(null),
      builder: (context, data, child) {
        double voltage = tryCast<num>(data)?.toDouble() ?? 0.0;

        double clampedVoltage = voltage.clamp(model.minValue, model.maxValue);

        double? divisionInterval =
            (model.maxValue - model.minValue) / (model.divisions - 1);

        int fractionDigits = (model.dataType?.dataType == NT4DataType.int32)
            ? 0
            : 2;

        GaugeOrientation gaugeOrientation = (model.orientation == 'vertical')
            ? GaugeOrientation.vertical
            : GaugeOrientation.horizontal;

        RulerPosition rulerPosition =
            (gaugeOrientation == GaugeOrientation.vertical)
            ? RulerPosition.right
            : RulerPosition.bottom;

        List<Widget> children = [
          Text(
            '${voltage.toStringAsFixed(fractionDigits)} V',
            style: Theme.of(context).textTheme.bodyLarge,
            overflow: TextOverflow.ellipsis,
          ),
          const Flexible(child: SizedBox(width: 5.0, height: 5.0)),
          LinearGauge(
            key: UniqueKey(),
            rulers: RulerStyle(
              rulerPosition: rulerPosition,
              inverseRulers: model.inverted,
              showLabel: true,
              textStyle: Theme.of(context).textTheme.bodyMedium,
              primaryRulerColor: Colors.grey,
              secondaryRulerColor: Colors.grey,
            ),
            gaugeOrientation: gaugeOrientation,
            valueBar: [
              ValueBar(
                color: Colors.yellow,
                value: clampedVoltage,
                borderRadius: 5,
                valueBarThickness: 7.5,
                enableAnimation: false,
                animationDuration: 0,
              ),
            ],
            customLabels: [
              for (int i = 0; i < model.divisions; i++)
                CustomRulerLabel(
                  text:
                      '${formatLabel(model.minValue + divisionInterval * i)} V',
                  value: model.minValue + divisionInterval * i,
                ),
            ],
            enableGaugeAnimation: false,
            start: model.minValue,
            end: model.maxValue,
            steps: divisionInterval,
          ),
        ];

        if (gaugeOrientation == GaugeOrientation.vertical) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          );
        } else {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          );
        }
      },
    );
  }
}
