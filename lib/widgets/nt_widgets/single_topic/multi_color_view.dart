import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class MultiColorView extends NTWidget {
  static const String widgetType = 'Multi Color View';

  const MultiColorView({super.key});

  @override
  Widget build(BuildContext context) {
    SingleTopicNTWidgetModel model = cast(context.watch<NTWidgetModel>());

    return ValueListenableBuilder(
      valueListenable: model.subscription ?? ValueNotifier(null),
      builder: (context, data, child) {
        List<Object?> hexStringsRaw = tryCast<List<Object?>>(data) ?? [];
        List<String> hexStrings = hexStringsRaw.whereType<String>().toList();

        List<Color> colors = [];

        for (String hexString in hexStrings) {
          hexString = hexString.toUpperCase().replaceAll('#', '');

          if (hexString.length == 6) {
            hexString = 'FF$hexString';
          }

          int? hexCode = int.tryParse(hexString, radix: 16);

          if (hexCode != null) {
            colors.add(Color(hexCode));
          }
        }

        if (colors.length < 2) {
          if (colors.length == 1) {
            colors.add(colors[0]);
          } else {
            colors.add(Colors.transparent);
            colors.add(Colors.transparent);
          }
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15.0),
            gradient: LinearGradient(colors: colors),
          ),
        );
      },
    );
  }
}
