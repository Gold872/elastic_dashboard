import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class LargeTextDisplay extends NTWidget {
  static const String widgetType = 'Large Text Display';

  const LargeTextDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    SingleTopicNTWidgetModel model = cast(context.watch<NTWidgetModel>());

    return ValueListenableBuilder(
      valueListenable: model.subscription ?? ValueNotifier(null),
      builder: (context, value, _) {
        String data = value?.toString() ?? '';

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(data, textAlign: TextAlign.center),
              ),
            ),
          ],
        );
      },
    );
  }
}
