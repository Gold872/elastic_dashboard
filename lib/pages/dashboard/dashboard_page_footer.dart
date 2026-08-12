import 'package:material_ui/material_ui.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/settings.dart';

class DashboardPageFooter extends StatelessWidget {
  final DashboardPageViewModel model;
  final SharedPreferences preferences;
  final TextStyle? footerStyle;
  final double windowWidth;

  const DashboardPageFooter({
    super.key,
    required this.model,
    required this.preferences,
    required this.footerStyle,
    required this.windowWidth,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: const Color.fromARGB(255, 20, 20, 20),
    height: 32,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: ValueListenableBuilder(
        valueListenable: model.ntConnection.ntConnected,
        builder: (context, connected, child) {
          String connectedText = (connected)
              ? 'Network Tables: Connected (${preferences.getString(PrefKeys.ipAddress) ?? Defaults.ipAddress})'
              : 'Network Tables: Disconnected';

          String teamNumberText =
              'Team ${preferences.getInt(PrefKeys.teamNumber)?.toString() ?? 'Unknown'}';

          double connectedWidth = (TextPainter(
            text: TextSpan(text: connectedText, style: footerStyle),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          )..layout()).size.width;

          double teamNumberWidth = (TextPainter(
            text: TextSpan(text: teamNumberText, style: footerStyle),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          )..layout()).size.width;

          double availableSpace = windowWidth - 20 - connectedWidth;

          return Stack(
            alignment: Alignment.center,
            children: [
              if (availableSpace >= (windowWidth + teamNumberWidth) / 2)
                Text(teamNumberText, textAlign: TextAlign.center),
              if (availableSpace >= 115)
                Align(
                  alignment: Alignment.centerRight,
                  child: StreamBuilder(
                    stream: model.ntConnection.latencyStream(),
                    builder: (context, snapshot) {
                      double latency = snapshot.data ?? 0.0;

                      return Text(
                        'Latency: ${latency.toStringAsFixed(2).padLeft(5)} ms',
                        textAlign: TextAlign.right,
                      );
                    },
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  connectedText,
                  style: footerStyle?.copyWith(
                    color: (connected) ? Colors.green : Colors.red,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
