import 'package:flutter/material.dart';

import 'package:decimal/decimal.dart';
import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class TextDisplayModel extends SingleTopicNTWidgetModel {
  @override
  String type = TextDisplay.widgetType;

  final TextEditingController controller = TextEditingController();

  Object? previousValue;

  bool _showSubmitButton = false;

  bool get showSubmitButton => _showSubmitButton;

  set showSubmitButton(bool value) {
    _showSubmitButton = value;
    refresh();
  }

  bool typing = false;

  TextDisplayModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    bool? showSubmitButton,
    super.ntStructMeta,
    super.dataType,
    super.period,
  }) : super() {
    if (preferences.getBool(PrefKeys.autoTextSubmitButton) ?? false) {
      showSubmitButton ??= true;
    } else {
      if (topic != null) {
        showSubmitButton ??= ntConnection
            .getTopicFromName(topic!)
            ?.isPersistent;
      }
      showSubmitButton ??= false;
    }
    _showSubmitButton = showSubmitButton;
  }

  TextDisplayModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _showSubmitButton =
        tryCast(jsonData['show_submit_button']) ?? _showSubmitButton;
  }

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    DialogToggleSwitch(
      label: 'Show Submit Button',
      initialValue: _showSubmitButton,
      onToggle: (value) {
        showSubmitButton = value;
      },
    ),
  ];

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'show_submit_button': showSubmitButton,
  };

  void publishData(String value) {
    bool publishTopic =
        ntTopic == null || !ntConnection.isTopicPublished(ntTopic!);

    createTopicIfNull();

    if (ntTopic == null) {
      return;
    }

    NT4Type dataType = ntStructMeta?.type ?? ntTopic!.type;
    Object? formattedData = dataType.convertString(value);

    if (publishTopic) {
      ntConnection.publishTopic(ntTopic!);
    }

    if (formattedData != null) {
      ntConnection.updateDataFromTopic(ntTopic!, formattedData);
    }

    previousValue = value;
  }
}

class TextDisplay extends NTWidget {
  static const String widgetType = 'Text Display';

  const TextDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    TextDisplayModel model = cast(context.watch<NTWidgetModel>());

    ThemeData themeData = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([model.subscription, model.controller]),
      builder: (context, child) {
        Object? data = model.subscription?.value;

        if (data?.toString() != model.previousValue?.toString()) {
          // Needed to prevent errors
          Future(() async {
            String displayString = data?.toString() ?? '';
            if (data is double) {
              if (cast<double>(data).abs() > 1e-10) {
                displayString = Decimal.parse(data.toString()).toString();
              } else {
                data = 0.0 * cast<double>(data).sign;
                displayString = data.toString();
              }
            }
            model.controller.text = displayString;
            model.typing = false;

            model.previousValue = data;
          });
        }

        bool showWarning =
            model.controller.text != (data?.toString() ?? '') && model.typing;

        return Row(
          children: [
            Flexible(
              child: Theme(
                // Idk why, but this is the only way to properly change the error
                // color without affecting the input border behavior
                data: themeData.copyWith(
                  colorScheme: themeData.colorScheme.copyWith(
                    error: Colors.red[400],
                  ),
                ),
                child: TextField(
                  controller: model.controller,
                  textAlign: TextAlign.left,
                  textAlignVertical: TextAlignVertical.bottom,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 0.0,
                      vertical: 10.0,
                    ),
                    isDense: true,
                    error: (showWarning) ? const SizedBox() : null,
                  ),
                  readOnly: model.ntStructMeta != null,
                  onChanged: (value) {
                    model.typing = true;
                  },
                  onSubmitted: (value) {
                    model.publishData(value);
                    model.typing = false;
                  },
                ),
              ),
            ),
            // Don't show submit button if it's displaying a struct value
            if (model.showSubmitButton && model.ntStructMeta == null) ...[
              const SizedBox(width: 1.5),
              Tooltip(
                message: 'Publish Data',
                waitDuration: const Duration(milliseconds: 250),
                child: Container(
                  padding: EdgeInsets.zero,
                  width: 32.0,
                  height: 32.0,
                  child: IconButton(
                    iconSize: 18.0,
                    onPressed: () {
                      model.publishData(model.controller.text);
                      model.typing = false;
                    },
                    icon: const Icon(Icons.exit_to_app),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
