import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ThreeAxisAccelerometerModel extends MultiTopicNTWidgetModel {
  @override
  String type = ThreeAxisAccelerometer.widgetType;

  String get xTopic => '$topic/X';
  String get yTopic => '$topic/Y';
  String get zTopic => '$topic/Z';

  NT4Subscription? xSubscription;
  NT4Subscription? ySubscription;
  NT4Subscription? zSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    ?xSubscription,
    ?ySubscription,
    ?zSubscription,
  ];

  ThreeAxisAccelerometerModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
  }) : super();

  ThreeAxisAccelerometerModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    if (topic == null) {
      xSubscription = null;
      ySubscription = null;
      zSubscription = null;
      return;
    }

    xSubscription = ntConnection.subscribe(xTopic, super.period);
    ySubscription = ntConnection.subscribe(yTopic, super.period);
    zSubscription = ntConnection.subscribe(zTopic, super.period);
  }
}

class ThreeAxisAccelerometer extends NTWidget {
  static const String widgetType = '3-Axis Accelerometer';

  const ThreeAxisAccelerometer({super.key});

  @override
  Widget build(BuildContext context) {
    ThreeAxisAccelerometerModel model = cast(context.watch<NTWidgetModel>());

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: [
        // X Acceleration
        Flexible(
          flex: 16,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('X'),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ValueListenableBuilder(
                    valueListenable: model.xSubscription ?? ValueNotifier(null),
                    builder: (context, value, child) {
                      double xAccel = tryCast(value) ?? 0.0;
                      return Text(
                        '${xAccel.toStringAsFixed(2)} g',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          overflow: TextOverflow.ellipsis,
                          fontSize: 12.0,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const Flexible(child: SizedBox(height: 4.0)),
        // Y Acceleration
        Flexible(
          flex: 16,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Y'),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ValueListenableBuilder(
                    valueListenable: model.ySubscription ?? ValueNotifier(null),
                    builder: (context, value, child) {
                      double yAccel = tryCast(value) ?? 0.0;
                      return Text(
                        '${yAccel.toStringAsFixed(2)} g',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          overflow: TextOverflow.ellipsis,
                          fontSize: 12.0,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const Flexible(child: SizedBox(height: 4.0)),
        // Z Acceleration
        Flexible(
          flex: 16,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Z'),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ValueListenableBuilder(
                    valueListenable: model.zSubscription ?? ValueNotifier(null),
                    builder: (context, value, child) {
                      double zAccel = tryCast(value) ?? 0.0;
                      return Text(
                        '${zAccel.toStringAsFixed(2)} g',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          overflow: TextOverflow.ellipsis,
                          fontSize: 12.0,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
