import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class SubsystemModel extends MultiTopicNTWidgetModel {
  @override
  String type = SubsystemWidget.widgetType;

  String get defaultCommandTopic => '$topic/.default';
  String get currentCommandTopic => '$topic/.command';

  late NT4Subscription defaultCommandSubscription;
  late NT4Subscription currentCommandSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    defaultCommandSubscription,
    currentCommandSubscription,
  ];

  SubsystemModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
  }) : super();

  SubsystemModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    defaultCommandSubscription = ntConnection.subscribe(
      defaultCommandTopic,
      super.period,
    );
    currentCommandSubscription = ntConnection.subscribe(
      currentCommandTopic,
      super.period,
    );
  }
}

class SubsystemWidget extends NTWidget {
  static const String widgetType = 'Subsystem';

  const SubsystemWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    SubsystemModel model = cast(context.watch<NTWidgetModel>());

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        ValueListenableBuilder(
          valueListenable: model.defaultCommandSubscription,
          builder: (context, value, child) {
            String defaultCommand = tryCast(value) ?? 'none';

            return Text(
              'Default Command: $defaultCommand',
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        const SizedBox(height: 5),
        ValueListenableBuilder(
          valueListenable: model.currentCommandSubscription,
          builder: (context, value, child) {
            String currentCommand = tryCast(value) ?? 'none';

            return Text(
              'Current Command: $currentCommand',
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
      ],
    );
  }
}
