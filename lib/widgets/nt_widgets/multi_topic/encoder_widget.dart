import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class EncoderModel extends MultiTopicNTWidgetModel {
  @override
  String type = EncoderWidget.widgetType;

  String get distanceTopic => '$topic/Distance';
  String get speedTopic => '$topic/Speed';

  NT4Subscription? distanceSubscription;
  NT4Subscription? speedSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    ?distanceSubscription,
    ?speedSubscription,
  ];

  EncoderModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
  }) : super();

  EncoderModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    distanceSubscription = ntConnection.subscribe(distanceTopic, super.period);
    speedSubscription = ntConnection.subscribe(speedTopic, super.period);
  }
}

class EncoderWidget extends NTWidget {
  static const String widgetType = 'Encoder';

  const EncoderWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    EncoderModel model = cast(context.watch<NTWidgetModel>());

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          children: [
            const Text('Distance'),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade700, width: 1.5),
                  ),
                ),
                child: ValueListenableBuilder(
                  valueListenable:
                      model.distanceSubscription ?? ValueNotifier(null),
                  builder: (context, value, child) {
                    double distance = tryCast(value) ?? 0.0;
                    return SelectableText(
                      distance.toStringAsPrecision(10),
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
        ),
        Row(
          children: [
            const Text('Speed'),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade700, width: 1.5),
                  ),
                ),
                child: ValueListenableBuilder(
                  valueListenable:
                      model.speedSubscription ?? ValueNotifier(null),
                  builder: (context, value, child) {
                    double speed = tryCast(value) ?? 0.0;
                    return SelectableText(
                      speed.toStringAsPrecision(10),
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
        ),
      ],
    );
  }
}
