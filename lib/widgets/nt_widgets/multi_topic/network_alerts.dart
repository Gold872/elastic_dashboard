import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class NetworkAlertsModel extends MultiTopicNTWidgetModel {
  @override
  String type = NetworkAlerts.widgetType;

  String get errorsTopicName => '$topic/errors';
  String get warningsTopicName => '$topic/warnings';
  String get infosTopicName => '$topic/infos';

  NT4Subscription? errorsSubscription;
  NT4Subscription? warningsSubscription;
  NT4Subscription? infosSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    ?errorsSubscription,
    ?warningsSubscription,
    ?infosSubscription,
  ];

  NetworkAlertsModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
  }) : super();

  NetworkAlertsModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    if (topic == null) {
      errorsSubscription = null;
      warningsSubscription = null;
      infosSubscription = null;
      return;
    }

    errorsSubscription = ntConnection.subscribe(errorsTopicName, super.period);
    warningsSubscription = ntConnection.subscribe(
      warningsTopicName,
      super.period,
    );
    infosSubscription = ntConnection.subscribe(infosTopicName, super.period);
  }
}

class NetworkAlerts extends NTWidget {
  static const String widgetType = 'Alerts';

  const NetworkAlerts({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    ScrollController scrollController = ScrollController();

    NetworkAlertsModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge(model.subscriptions),
      builder: (context, child) {
        List<Object?> errorsRaw =
            model.errorsSubscription?.value?.tryCast<List<Object?>>() ?? [];

        List<Object?> warningsRaw =
            model.warningsSubscription?.value?.tryCast<List<Object?>>() ?? [];

        List<Object?> infosRaw =
            model.infosSubscription?.value?.tryCast<List<Object?>>() ?? [];

        List<String> errors = errorsRaw.whereType<String>().toList();
        List<String> warnings = warningsRaw.whereType<String>().toList();
        List<String> infos = infosRaw.whereType<String>().toList();

        return Scrollbar(
          thumbVisibility: true,
          controller: scrollController,
          child: ListView.builder(
            controller: scrollController,
            itemCount: errors.length + warnings.length + infos.length,
            itemBuilder: (context, index) {
              String alertType = 'error';
              String alertMessage;
              if (index >= errors.length) {
                index -= errors.length;
                alertType = 'warning';
              }
              if (index >= warnings.length && alertType == 'warning') {
                index -= warnings.length;
                alertType = 'info';
              }
              if (index >= infos.length && alertType == 'info') {
                alertType = 'none';
              }

              TextStyle? messageStyle = Theme.of(context).textTheme.bodyMedium;

              switch (alertType) {
                case 'error':
                  alertMessage = errors[index];
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                    leading: const Icon(
                      Icons.cancel,
                      size: 24,
                      color: Colors.red,
                    ),
                    title: Text(alertMessage, style: messageStyle),
                  );
                case 'warning':
                  alertMessage = warnings[index];
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                    leading: const Icon(
                      Icons.warning,
                      size: 24,
                      color: Colors.yellow,
                    ),
                    title: Text(alertMessage, style: messageStyle),
                  );
                case 'info':
                  alertMessage = infos[index];
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                    leading: const Icon(
                      Icons.info,
                      size: 24,
                      color: Colors.green,
                    ),
                    title: Text(alertMessage, style: messageStyle),
                  );
                default:
                  return Container();
              }
            },
          ),
        );
      },
    );
  }
}
