import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class UltrasonicModel extends MultiTopicNTWidgetModel {
  @override
  String type = Ultrasonic.widgetType;

  String get valueTopic => '$topic/Value';

  NT4Subscription? valueSubscription;

  @override
  List<NT4Subscription> get subscriptions => [?valueSubscription];

  UltrasonicModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
  }) : super();

  UltrasonicModel.fromJson({
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

class Ultrasonic extends NTWidget {
  static const String widgetType = 'Ultrasonic';

  const Ultrasonic({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    UltrasonicModel model = cast(context.watch<NTWidgetModel>());

    return Row(
      children: [
        const Text('Range'),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade700, width: 1.5),
              ),
            ),
            child: ValueListenableBuilder(
              valueListenable: model.valueSubscription ?? ValueNotifier(null),
              builder: (context, data, child) {
                double value = tryCast(data) ?? 0.0;
                return SelectableText(
                  '${value.toStringAsPrecision(5)} in',
                  maxLines: 1,
                  showCursor: true,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
