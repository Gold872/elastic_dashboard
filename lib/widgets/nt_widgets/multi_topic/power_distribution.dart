import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class PowerDistributionModel extends MultiTopicNTWidgetModel {
  @override
  String type = PowerDistribution.widgetType;

  static const int numberOfChannels = 23;

  final List<String> channelTopics = [];

  String get voltageTopic => '$topic/Voltage';
  String get currentTopic => '$topic/TotalCurrent';

  NT4Subscription? voltageSubscription;
  NT4Subscription? currentSubscription;

  final List<NT4Subscription> channelSubscriptions = [];

  @override
  List<NT4Subscription> get subscriptions => [
    ?voltageSubscription,
    ?currentSubscription,
    ...channelSubscriptions,
  ];

  PowerDistributionModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
  }) : super();

  PowerDistributionModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    channelTopics.clear();
    channelSubscriptions.clear();

    if (topic == null) {
      voltageSubscription = null;
      currentSubscription = null;
      return;
    }

    voltageSubscription = ntConnection.subscribe(voltageTopic, super.period);
    currentSubscription = ntConnection.subscribe(currentTopic, super.period);

    for (int channel = 0; channel <= numberOfChannels; channel++) {
      channelTopics.add('$topic/Chan$channel');
    }

    for (String topic in channelTopics) {
      channelSubscriptions.add(ntConnection.subscribe(topic, super.period));
    }
  }
}

class PowerDistribution extends NTWidget {
  static const String widgetType = 'PowerDistribution';

  const PowerDistribution({super.key}) : super();

  Widget _getChannelsColumn(
    PowerDistributionModel model,
    BuildContext context,
    int start,
    int end,
  ) {
    List<Widget> channels = [];

    for (int channel = start; channel <= end; channel++) {
      channels.add(
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            ValueListenableBuilder(
              valueListenable:
                  model.channelSubscriptions.elementAtOrNull(channel) ??
                  ValueNotifier(null),
              builder: (context, value, child) {
                double current = tryCast(value) ?? 0.0;

                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 4.0,
                  ),
                  child: Text(
                    '${current.toStringAsFixed(2).padLeft(5, '0')} A',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            Text('Ch. ${channel.toString().padRight(2)}'),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [...channels],
    );
  }

  Widget _getReversedChannelsColumn(
    PowerDistributionModel model,
    BuildContext context,
    int start,
    int end,
  ) {
    List<Widget> channels = [];

    for (int channel = start; channel >= end; channel--) {
      channels.add(
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ch. $channel'),
            const SizedBox(width: 10),
            ValueListenableBuilder(
              valueListenable:
                  model.channelSubscriptions.elementAtOrNull(channel) ??
                  ValueNotifier(null),
              builder: (context, value, child) {
                double current = tryCast(value) ?? 0.0;
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 4.0,
                  ),
                  child: Text(
                    '${current.toStringAsFixed(2).padLeft(5, '0')} A',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [...channels],
    );
  }

  @override
  Widget build(BuildContext context) {
    PowerDistributionModel model = cast(context.watch<NTWidgetModel>());

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Voltage
            Column(
              children: [
                const Text('Voltage'),
                const SizedBox(height: 2.5),
                ValueListenableBuilder(
                  valueListenable:
                      model.voltageSubscription ?? ValueNotifier(null),
                  builder: (context, value, child) {
                    double voltage = tryCast(value) ?? 0.0;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text(
                        '${voltage.toStringAsFixed(2).padLeft(5, '0')} V',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            // Current
            Column(
              children: [
                const Text('Total Current'),
                const SizedBox(height: 2.5),
                ValueListenableBuilder(
                  valueListenable:
                      model.currentSubscription ?? ValueNotifier(null),
                  builder: (context, value, child) {
                    double totalCurrent = tryCast(value) ?? 0.0;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text(
                        '${totalCurrent.toStringAsFixed(2).padLeft(5, '0')} A',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 5),
        // Channel current
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // First 12 channels
              _getChannelsColumn(model, context, 0, 11),
              _getReversedChannelsColumn(model, context, 23, 12),
            ],
          ),
        ),
      ],
    );
  }
}
