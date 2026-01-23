import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class CommandSchedulerModel extends MultiTopicNTWidgetModel {
  @override
  String type = CommandSchedulerWidget.widgetType;

  NT4Topic? _cancelTopic;

  String get namesTopicName => '$topic/Names';
  String get idsTopicName => '$topic/Ids';
  String get cancelTopicName => '$topic/Cancel';

  NT4Subscription? namesSubscription;
  NT4Subscription? idsSubscription;
  NT4Subscription? cancelSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    ?namesSubscription,
    ?idsSubscription,
    ?cancelSubscription,
  ];

  CommandSchedulerModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
  }) : super();

  CommandSchedulerModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    if (topic == null) {
      namesSubscription = null;
      idsSubscription = null;
      cancelSubscription = null;
      return;
    }

    namesSubscription = ntConnection.subscribe(namesTopicName, super.period);
    idsSubscription = ntConnection.subscribe(idsTopicName, super.period);
    cancelSubscription = ntConnection.subscribe(cancelTopicName, super.period);
  }

  @override
  void resetSubscription() {
    _cancelTopic = null;

    super.resetSubscription();
  }

  void cancelCommand(int id) {
    List<Object?> currentCancellationsRaw =
        cancelSubscription?.value?.tryCast<List<Object?>>() ?? [];

    List<int> currentCancellations = currentCancellationsRaw
        .whereType<int>()
        .toList();

    currentCancellations.add(id);

    _cancelTopic ??= ntConnection.publishNewTopic(
      cancelTopicName,
      NT4Type.array(NT4Type.int()),
    );

    if (_cancelTopic == null) {
      return;
    }

    ntConnection.updateDataFromTopic(_cancelTopic!, currentCancellations);
  }
}

class CommandSchedulerWidget extends NTWidget {
  static const String widgetType = 'Scheduler';

  const CommandSchedulerWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    CommandSchedulerModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge(model.subscriptions),
      builder: (context, child) {
        List<Object?> rawNames =
            model.namesSubscription?.value?.tryCast<List<Object?>>() ?? [];

        List<Object?> rawIds =
            model.idsSubscription?.value?.tryCast<List<Object?>>() ?? [];

        List<String> names = rawNames.whereType<String>().toList();
        List<int> ids = rawIds.whereType<int>().toList();

        int commandsLength = min(names.length, ids.length);

        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4.0, top: 4.0, right: 4.0),
              child: Text(
                'Scheduled Commands:',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                itemCount: commandsLength,
                itemBuilder: (context, index) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(
                    left: 16.0,
                    right: 8.0,
                  ),
                  visualDensity: const VisualDensity(
                    vertical: VisualDensity.minimumDensity,
                  ),
                  title: Text(names[index], overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    tooltip: 'Cancel Command',
                    onPressed: () {
                      model.cancelCommand(ids[index]);
                    },
                    color: Colors.red,
                    icon: const Icon(Icons.cancel_outlined),
                  ),
                  subtitle: Text(
                    'ID: ${ids[index].toString()}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall!.copyWith(color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
