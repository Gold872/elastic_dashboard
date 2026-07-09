import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class MotorControllerModel extends MultiTopicNTWidgetModel {
  @override
  String type = MotorController.widgetType;

  String get valueTopic => '$topic/Value';

  NT4Subscription? valueSubscription;

  @override
  List<NT4Subscription> get subscriptions => [?valueSubscription];

  MotorControllerModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
  }) : super();

  MotorControllerModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    if (topic == null) {
      valueSubscription = null;
      return;
    }

    valueSubscription = ntConnection.subscribe(valueTopic, super.period);
  }
}

class MotorController extends NTWidget {
  static const String widgetType = 'Motor Controller';

  const MotorController({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    MotorControllerModel model = cast(context.watch<NTWidgetModel>());

    return ValueListenableBuilder(
      valueListenable: model.valueSubscription ?? ValueNotifier(null),
      builder: (context, data, child) {
        double value = tryCast(data) ?? 0.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value.toStringAsFixed(2),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Flexible(child: SizedBox(height: 5)),
            LinearGauge(
              rulers: RulerStyle(
                rulerPosition: RulerPosition.bottom,
                primaryRulerColor: Colors.grey,
                secondaryRulerColor: Colors.grey,
                textStyle: Theme.of(context).textTheme.bodySmall,
              ),
              extendLinearGauge: 1,
              linearGaugeBoxDecoration: const LinearGaugeBoxDecoration(
                backgroundColor: Color.fromRGBO(87, 87, 87, 1),
                thickness: 5,
              ),
              pointers: [
                Pointer(
                  enableAnimation: false,
                  value: value.clamp(-1.0, 1.0),
                  shape: PointerShape.diamond,
                  color: Theme.of(context).colorScheme.primary,
                  width: 10.0,
                  height: 14.0,
                ),
              ],
              enableGaugeAnimation: false,
              start: -1.0,
              end: 1.0,
              steps: 0.5,
            ),
          ],
        );
      },
    );
  }
}
