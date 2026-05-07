import 'dart:typed_data';

import 'package:elastic_dashboard/services/struct_schemas/nt_struct.dart';
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
  String get controlWordTopic => '$topic/ControlWord';
  String get allianceTopic => '$topic/IsRedAlliance';
  String get matchNumberTopic => '$topic/MatchNumber';
  String get matchTypeTopic => '$topic/MatchType';
  String get replayNumberTopic => '$topic/ReplayNumber';
  String get stationNumberTopic => '$topic/StationNumber';

  late NT4Subscription eventNameSubscription;
  late NT4Subscription controlWordSubscription;
  late NT4Subscription allianceSubscription;
  late NT4Subscription matchNumberSubscription;
  late NT4Subscription matchTypeSubscription;
  late NT4Subscription replayNumberSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    eventNameSubscription,
    controlWordSubscription,
    allianceSubscription,
    matchNumberSubscription,
    matchTypeSubscription,
    replayNumberSubscription,
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
    eventNameSubscription = ntConnection.subscribe(
      eventNameTopic,
      super.period,
    );
    controlWordSubscription = ntConnection.subscribe(
      controlWordTopic,
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

  @override
  Widget build(BuildContext context) {
    FMSInfoModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge(model.subscriptions),
      builder: (context, child) {
        String eventName = tryCast(model.eventNameSubscription.value) ?? '';
        List<int> controlWordRaw =
            tryCast(model.controlWordSubscription.value) ?? [];
        NTStruct? controlDataStruct;
        if (model.ntConnection.schemaManager.getSchema('ControlWord') != null) {
          NTStructSchema controlWordSchema = model.ntConnection.schemaManager
              .getSchema('ControlWord')!;
          try {
            controlDataStruct = NTStruct.parse(
              schema: controlWordSchema,
              data: Uint8List.fromList(controlWordRaw),
            );
          } catch (_) {}
        }
        bool redAlliance = tryCast(model.allianceSubscription.value) ?? true;
        int matchNumber = tryCast(model.matchNumberSubscription.value) ?? 0;
        int matchType = tryCast(model.matchTypeSubscription.value) ?? 0;
        int replayNumber = tryCast(model.replayNumberSubscription.value) ?? 0;

        String eventNameDisplay = '$eventName${(eventName != '') ? ' ' : ''}';
        String matchTypeString = _getMatchTypeString(matchType);
        String replayNumberDisplay = (replayNumber != 0)
            ? ' (replay $replayNumber)'
            : '';

        bool fmsConnected = controlDataStruct?['fmsAttached'] ?? false;
        bool dsAttached = controlDataStruct?['dsAttached'] ?? false;

        bool emergencyStopped = controlDataStruct?['eStop'] ?? false;

        String robotControlState = 'Disabled';
        if (controlDataStruct?['enabled'] ?? false) {
          robotControlState = controlDataStruct?['robotMode'] ?? 'Unknown';
          if (robotControlState.isNotEmpty) {
            robotControlState =
                robotControlState.substring(0, 1).toUpperCase() +
                robotControlState.substring(1);
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
