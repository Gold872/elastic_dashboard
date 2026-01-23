// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:patterns_canvas/patterns_canvas.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class FMSInfoModel extends MultiTopicNTWidgetModel {
  @override
  String type = FMSInfo.widgetType;

  String get eventNameTopic => '$topic/EventName';
  String get controlDataTopic => '$topic/FMSControlData';
  String get allianceTopic => '$topic/IsRedAlliance';
  String get matchNumberTopic => '$topic/MatchNumber';
  String get matchTypeTopic => '$topic/MatchType';
  String get replayNumberTopic => '$topic/ReplayNumber';
  String get stationNumberTopic => '$topic/StationNumber';

  NT4Subscription? eventNameSubscription;
  NT4Subscription? controlDataSubscription;
  NT4Subscription? allianceSubscription;
  NT4Subscription? matchNumberSubscription;
  NT4Subscription? matchTypeSubscription;
  NT4Subscription? replayNumberSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    ?eventNameSubscription,
    ?controlDataSubscription,
    ?allianceSubscription,
    ?matchNumberSubscription,
    ?matchTypeSubscription,
    ?replayNumberSubscription,
  ];

  FMSInfoModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
  });

  FMSInfoModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    if (topic == null) {
      eventNameSubscription = null;
      controlDataSubscription = null;
      allianceSubscription = null;
      matchNumberSubscription = null;
      matchTypeSubscription = null;
      replayNumberSubscription = null;

      return;
    }
    eventNameSubscription = ntConnection.subscribe(
      eventNameTopic,
      super.period,
    );
    controlDataSubscription = ntConnection.subscribe(
      controlDataTopic,
      super.period,
    );
    allianceSubscription = ntConnection.subscribe(allianceTopic, super.period);
    matchNumberSubscription = ntConnection.subscribe(
      matchNumberTopic,
      super.period,
    );
    matchTypeSubscription = ntConnection.subscribe(
      matchTypeTopic,
      super.period,
    );
    replayNumberSubscription = ntConnection.subscribe(
      replayNumberTopic,
      super.period,
    );
  }
}

class FMSInfo extends NTWidget {
  static const String widgetType = 'FMSInfo';

  static const int ENABLED_FLAG = 0x01;
  static const int AUTO_FLAG = 0x02;
  static const int TEST_FLAG = 0x04;
  static const int EMERGENCY_STOP_FLAG = 0x08;
  static const int FMS_ATTACHED_FLAG = 0x10;
  static const int DS_ATTACHED_FLAG = 0x20;

  const FMSInfo({super.key}) : super();

  String _getMatchTypeString(int matchType) {
    switch (matchType) {
      case 1:
        return 'Practice';
      case 2:
        return 'Qualification';
      case 3:
        return 'Elimination';
      default:
        return 'Unknown';
    }
  }

  bool _flagMatches(int word, int flag) => (word & flag) != 0;

  @override
  Widget build(BuildContext context) {
    FMSInfoModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge(model.subscriptions),
      builder: (context, child) {
        String eventName = tryCast(model.eventNameSubscription?.value) ?? '';
        int controlData = tryCast(model.controlDataSubscription?.value) ?? 32;
        bool redAlliance = tryCast(model.allianceSubscription?.value) ?? true;
        int matchNumber = tryCast(model.matchNumberSubscription?.value) ?? 0;
        int matchType = tryCast(model.matchTypeSubscription?.value) ?? 0;
        int replayNumber = tryCast(model.replayNumberSubscription?.value) ?? 0;

        String eventNameDisplay = '$eventName${(eventName != '') ? ' ' : ''}';
        String matchTypeString = _getMatchTypeString(matchType);
        String replayNumberDisplay = (replayNumber != 0)
            ? ' (replay $replayNumber)'
            : '';

        bool fmsConnected = _flagMatches(controlData, FMS_ATTACHED_FLAG);
        bool dsAttached = _flagMatches(controlData, DS_ATTACHED_FLAG);

        bool emergencyStopped = _flagMatches(controlData, EMERGENCY_STOP_FLAG);

        String robotControlState = 'Disabled';
        if (_flagMatches(controlData, ENABLED_FLAG)) {
          if (_flagMatches(controlData, TEST_FLAG)) {
            robotControlState = 'Test';
          } else if (_flagMatches(controlData, AUTO_FLAG)) {
            robotControlState = 'Autonomous';
          } else {
            robotControlState = 'Teleoperated';
          }
        }

        String matchDisplayString =
            '$eventNameDisplay$matchTypeString match $matchNumber$replayNumberDisplay';
        Widget matchDisplayWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 5.0),
              decoration: BoxDecoration(
                color: (redAlliance)
                    ? Colors.red.shade900
                    : Colors.blue.shade900,
                borderRadius: BorderRadius.circular(5.0),
              ),
              child: Text(
                matchDisplayString,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        );

        String fmsDisplayString = (fmsConnected)
            ? 'FMS Connected'
            : 'FMS Disconnected';
        String dsDisplayString = (dsAttached)
            ? 'DriverStation Connected'
            : 'DriverStation Disconnected';

        Icon fmsDisplayIcon = (fmsConnected)
            ? const Icon(Icons.check, color: Colors.green, size: 18)
            : const Icon(Icons.clear, color: Colors.red, size: 18);
        Icon dsDisplayIcon = (dsAttached)
            ? const Icon(Icons.check, color: Colors.green, size: 18)
            : const Icon(Icons.clear, color: Colors.red, size: 18);

        String robotStateDisplayString = 'Robot State: $robotControlState';

        late Widget robotStateWidget;
        if (emergencyStopped) {
          robotStateWidget = Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                flex: 25,
                child: CustomPaint(
                  size: const Size(80, 15),
                  painter: _BlackAndYellowStripes(),
                ),
              ),
              const Spacer(),
              const Text(
                'EMERGENCY STOPPED',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Expanded(
                flex: 25,
                child: CustomPaint(
                  size: const Size(80, 15),
                  painter: _BlackAndYellowStripes(),
                ),
              ),
            ],
          );
        } else {
          robotStateWidget = Text(robotStateDisplayString);
        }

        return Column(
          children: [
            matchDisplayWidget,
            const Spacer(flex: 2),
            // DS and FMS connected
            Row(
              children: [
                const Spacer(),
                Row(
                  children: [
                    fmsDisplayIcon,
                    const SizedBox(width: 5),
                    Text(fmsDisplayString),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    dsDisplayIcon,
                    const SizedBox(width: 5),
                    Text(dsDisplayString),
                  ],
                ),
                const Spacer(),
              ],
            ),
            const Spacer(),
            // Robot State
            robotStateWidget,
          ],
        );
      },
    );
  }
}

class _BlackAndYellowStripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);

    const DiagonalStripesThick(
      bgColor: Colors.black,
      fgColor: Colors.yellow,
      featuresCount: 10,
    ).paintOnRect(canvas, size, rect);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
