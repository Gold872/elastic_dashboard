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

class NumberSliderModel extends SingleTopicNTWidgetModel {
  @override
  String type = NumberSlider.widgetType;

  double _minValue = -1.0;
  double _maxValue = 1.0;
  int _divisions = 5;
  bool updateContinuously = false;

  ValueNotifier<double> displayValue = ValueNotifier(0.0);
  ValueNotifier<bool> dragging = ValueNotifier(false);

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

  NumberSliderModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.ntStructMeta,
    double minValue = -1.0,
    double maxValue = 1.0,
    int divisions = 5,
    this.updateContinuously = false,
    super.dataType,
    super.period,
  }) : _divisions = divisions,
       _minValue = minValue,
       _maxValue = maxValue,
       super();

  NumberSliderModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _minValue =
        tryCast(jsonData['min_value']) ?? tryCast(jsonData['min']) ?? -1.0;
    _maxValue =
        tryCast(jsonData['max_value']) ?? tryCast(jsonData['max']) ?? 1.0;
    _divisions =
        tryCast(jsonData['divisions']) ??
        tryCast(jsonData['numOfTickMarks']) ??
        5;

    updateContinuously =
        tryCast(jsonData['update_continuously']) ??
        tryCast(jsonData['publish_all']) ??
        false;
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'min_value': _minValue,
    'max_value': _maxValue,
    'divisions': _divisions,
    'update_continuously': updateContinuously,
  };

  @override
  List<Widget> getEditProperties(BuildContext context) => [
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
    // Number of divisions
    Row(
      children: [
        Flexible(
          flex: 2,
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
        if (ntStructMeta == null)
          Flexible(
            flex: 3,
            child: DialogToggleSwitch(
              initialValue: updateContinuously,
              label: 'Update While Dragging',
              onToggle: (value) {
                updateContinuously = value;
              },
            ),
          ),
      ],
    ),
  ];

  void publishValue(double value) {
    bool publishTopic =
        ntTopic == null || !ntConnection.isTopicPublished(ntTopic);

    createTopicIfNull();

    if (ntTopic == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(ntTopic!);
    }

    if (dataType == NT4Type.int()) {
      ntConnection.updateDataFromTopic(ntTopic!, value.round());
    } else {
      ntConnection.updateDataFromTopic(ntTopic!, value);
    }
  }
}

class NumberSlider extends NTWidget {
  static const String widgetType = 'Number Slider';

  const NumberSlider({super.key});

  @override
  Widget build(BuildContext context) {
    NumberSliderModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge([
        model.subscription,
        model.displayValue,
        model.dragging,
      ]),
      builder: (context, child) {
        double value =
            tryCast<num>(model.subscription?.value)?.toDouble() ?? 0.0;

        double clampedValue = value.clamp(model.minValue, model.maxValue);

        if (!model.dragging.value) {
          model.displayValue.value = clampedValue;
        }

        double divisionSeparation =
            (model.maxValue - model.minValue) / (model.divisions - 1);

        int fractionDigits = (model.dataType == NT4Type.int()) ? 0 : 2;

        return Column(
          children: [
            Text(
              model.displayValue.value.toStringAsFixed(fractionDigits),
              style: Theme.of(context).textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
            Expanded(
              child: LinearGauge(
                rulers: RulerStyle(
                  rulerPosition: RulerPosition.bottom,
                  showLabel: true,
                  textStyle: Theme.of(context).textTheme.bodyMedium,
                  primaryRulerColor: Colors.grey,
                  secondaryRulerColor: Colors.grey,
                ),
                extendLinearGauge: 1,
                linearGaugeBoxDecoration: const LinearGaugeBoxDecoration(
                  backgroundColor: Color.fromRGBO(87, 87, 87, 1),
                  thickness: 5,
                ),
                pointers: [
                  Pointer(
                    color: Theme.of(context).colorScheme.primary,
                    value: model.displayValue.value,
                    shape: PointerShape.circle,
                    enableAnimation: false,
                    height: 15,
                    isInteractive: model.ntStructMeta == null,
                    onChangeStart: () {
                      model.dragging.value = true;
                    },
                    onChanged: (value) {
                      if (model.dataType == NT4Type.int()) {
                        model.displayValue.value = value.roundToDouble();
                      } else {
                        model.displayValue.value = value;
                      }

                      if (model.updateContinuously) {
                        model.publishValue(model.displayValue.value);
                      }
                    },
                    onChangeEnd: () {
                      model.publishValue(model.displayValue.value);
                      model.dragging.value = false;
                    },
                  ),
                ],
                customLabels: [
                  for (int i = 0; i < model.divisions; i++)
                    CustomRulerLabel(
                      text: (model.minValue + divisionSeparation * i)
                          .toStringAsFixed(2),
                      value: model.minValue + divisionSeparation * i,
                    ),
                ],
                enableGaugeAnimation: false,
                start: model.minValue,
                end: model.maxValue,
                steps: divisionSeparation,
              ),
            ),
          ],
        );
      },
    );
  }
}
