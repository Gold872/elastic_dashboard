import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ToggleButton extends NTWidget {
  static const String widgetType = 'Toggle Button';

  const ToggleButton({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    SingleTopicNTWidgetModel model = cast(context.watch<NTWidgetModel>());

    return ValueListenableBuilder(
      valueListenable: model.subscription ?? ValueNotifier(null),
      builder: (context, data, child) {
        bool value = tryCast(data) ?? false;

        String buttonText = (model.topic != null)
            ? model.topic!.substring(
                model.topic!.lastIndexOf('/') + 1,
              )
            : '';

        Size buttonSize = MediaQuery.of(context).size;

        ThemeData theme = Theme.of(context);

        return GestureDetector(
          onTapUp: (_) {
            if (model.ntStructMeta != null) return;

            bool publishTopic =
                model.ntTopic == null ||
                !model.ntConnection.isTopicPublished(model.ntTopic);

            model.createTopicIfNull();

            if (model.ntTopic == null) {
              return;
            }

            if (publishTopic) {
              model.ntConnection.publishTopic(model.ntTopic!);
            }

            model.ntConnection.updateDataFromTopic(model.ntTopic!, !value);
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: buttonSize.width * 0.01,
              vertical: buttonSize.height * 0.01,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 10),
              width: buttonSize.width,
              height: buttonSize.height,
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
                color: (value)
                    ? theme.colorScheme.primaryContainer
                    : const Color.fromARGB(255, 50, 50, 50),
              ),
              child: Center(
                child: Text(
                  buttonText,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
