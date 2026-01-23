import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class CommandModel extends MultiTopicNTWidgetModel {
  @override
  String type = CommandWidget.widgetType;

  String get runningTopicName => '$topic/running';
  String get nameTopicName => '$topic/name';

  NT4Subscription? runningSubscription;
  NT4Subscription? nameSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    ?runningSubscription,
    ?nameSubscription,
  ];

  NT4Topic? runningTopic;

  bool _showType = true;

  bool get showType => _showType;

  set showType(bool value) {
    _showType = value;
    refresh();
  }

  bool _maximizeButtonSpace = false;

  bool get maximizeButtonSpace => _maximizeButtonSpace;

  set maximizeButtonSpace(bool value) {
    _maximizeButtonSpace = value;
    refresh();
  }

  CommandModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    bool showType = true,
    bool maximizeButtonSpace = false,
    super.period,
  }) : _showType = showType,
       _maximizeButtonSpace = maximizeButtonSpace,
       super();

  CommandModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _showType = tryCast(jsonData['show_type']) ?? _showType;
    _maximizeButtonSpace =
        tryCast(jsonData['maximize_button_space']) ?? _maximizeButtonSpace;
  }

  @override
  void initializeSubscriptions() {
    if (topic == null) {
      runningSubscription = null;
      nameSubscription = null;
      return;
    }

    runningSubscription = ntConnection.subscribe(
      runningTopicName,
      super.period,
    );
    nameSubscription = ntConnection.subscribe(nameTopicName, super.period);
  }

  @override
  void resetSubscription() {
    runningTopic = null;

    super.resetSubscription();
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'show_type': showType,
    'maximize_button_space': maximizeButtonSpace,
  };

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    Row(
      children: [
        Flexible(
          child: DialogToggleSwitch(
            label: 'Show Type',
            initialValue: _showType,
            onToggle: (value) {
              showType = value;
            },
          ),
        ),
        Flexible(
          child: DialogToggleSwitch(
            label: 'Maximize Button Space',
            initialValue: _maximizeButtonSpace,
            onToggle: (value) {
              maximizeButtonSpace = value;
            },
          ),
        ),
      ],
    ),
  ];
}

class CommandWidget extends NTWidget {
  static const String widgetType = 'Command';

  const CommandWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    CommandModel model = cast(context.watch<NTWidgetModel>());

    String buttonText = (model.topic != null)
        ? model.topic!.substring(model.topic!.lastIndexOf('/') + 1)
        : '';

    ThemeData theme = Theme.of(context);

    Widget commandButton = GestureDetector(
      onTapUp: (_) {
        bool publishTopic = model.runningTopic == null;

        model.runningTopic ??= model.ntConnection.getTopicFromName(
          model.runningTopicName,
        );

        if (model.runningTopic == null) {
          return;
        }

        if (publishTopic) {
          model.ntConnection.publishTopic(model.runningTopic!);
        }

        // Prevents widget from locking up if double pressed fast enough
        bool running =
            model.runningSubscription?.value?.tryCast<bool>() ?? false;

        model.ntConnection.updateDataFromTopic(model.runningTopic!, !running);
      },
      child: ValueListenableBuilder(
        valueListenable: model.runningSubscription ?? ValueNotifier(null),
        builder: (context, data, child) {
          bool running = tryCast(data) ?? false;

          return AnimatedContainer(
            alignment: model.maximizeButtonSpace ? Alignment.center : null,
            duration: const Duration(milliseconds: 50),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: const [
                BoxShadow(
                  offset: Offset(2, 2),
                  blurRadius: 10.0,
                  spreadRadius: -5,
                  color: Colors.black,
                ),
              ],
              color: (running)
                  ? theme.colorScheme.primaryContainer
                  : const Color.fromARGB(255, 50, 50, 50),
            ),
            child: Text(
              buttonText,
              style: theme.textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
    );

    if (model.maximizeButtonSpace) {
      commandButton = Expanded(child: commandButton);
    }

    return Column(
      children: [
        Visibility(
          visible: model.showType,
          child: ValueListenableBuilder(
            valueListenable: model.nameSubscription ?? ValueNotifier(null),
            builder: (context, data, child) {
              String name = tryCast(data) ?? 'Unknown';

              return Text(
                'Type: $name',
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        commandButton,
      ],
    );
  }
}
