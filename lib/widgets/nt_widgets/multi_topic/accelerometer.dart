import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class AccelerometerModel extends MultiTopicNTWidgetModel {
  @override
  String type = AccelerometerWidget.widgetType;

  NT4Subscription? _valueSubscription;
  NT4Subscription? get valueSubscription => _valueSubscription;

  String get valueTopic => '$topic/Value';

  @override
  List<NT4Subscription> get subscriptions => [?_valueSubscription];

  AccelerometerModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
  }) : super();

  AccelerometerModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    if (topic == null) {
      _valueSubscription = null;
      return;
    }

    _valueSubscription = ntConnection.subscribe(valueTopic, super.period);
  }
}

class AccelerometerWidget extends NTWidget {
  static const String widgetType = 'Accelerometer';

  const AccelerometerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    AccelerometerModel model = cast(context.watch<NTWidgetModel>());

    return ValueListenableBuilder(
      valueListenable: model.valueSubscription ?? ValueNotifier(null),
      builder: (context, data, child) {
        double value = tryCast(data) ?? 0.0;

        return Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(5.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '${value.toStringAsFixed(2)} g',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
