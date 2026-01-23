import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class RelayModel extends MultiTopicNTWidgetModel {
  @override
  String type = RelayWidget.widgetType;

  String get valueTopicName => '$topic/Value';

  NT4Subscription? valueSubscription;

  @override
  List<NT4Subscription> get subscriptions => [?valueSubscription];

  NT4Topic? valueTopic;

  final List<String> selectedOptions = ['Off', 'On', 'Forward', 'Reverse'];

  RelayModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
  }) : super();

  RelayModel.fromJson({
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

    valueSubscription = ntConnection.subscribe(valueTopicName, super.period);
  }

  @override
  void resetSubscription() {
    valueTopic = null;

    super.resetSubscription();
  }

  @override
  void unSubscribe() {
    valueTopic = null;

    super.unSubscribe();
  }
}

class RelayWidget extends NTWidget {
  static const String widgetType = 'Relay';

  const RelayWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    RelayModel model = cast(context.watch<NTWidgetModel>());

    return ValueListenableBuilder(
      valueListenable: model.valueSubscription ?? ValueNotifier(null),
      builder: (context, data, child) {
        String selected = tryCast(data) ?? 'Off';

        if (!model.selectedOptions.contains(selected)) {
          selected = 'Off';
        }

        return SingleChildScrollView(
          child: Row(
            children: [
              Expanded(
                child: ToggleButtons(
                  constraints: const BoxConstraints(
                    minWidth: double.infinity,
                    maxWidth: double.infinity,
                    minHeight: 40,
                    maxHeight: 40,
                  ),
                  direction: Axis.vertical,
                  onPressed: (index) {
                    String option = model.selectedOptions[index];

                    bool publishTopic = model.valueTopic == null;

                    model.valueTopic ??= model.ntConnection.getTopicFromName(
                      model.valueTopicName,
                    );

                    if (model.valueTopic == null) {
                      return;
                    }

                    if (publishTopic) {
                      model.ntConnection.publishTopic(model.valueTopic!);
                    }

                    model.ntConnection.updateDataFromTopic(
                      model.valueTopic!,
                      option,
                    );
                  },
                  isSelected: model.selectedOptions
                      .map((e) => selected == e)
                      .toList(),
                  children: model.selectedOptions
                      .map(
                        (element) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 0.0,
                          ),
                          child: Text(element),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
