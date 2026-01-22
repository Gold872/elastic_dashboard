import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class MatchTimeModel extends SingleTopicNTWidgetModel {
  @override
  String type = MatchTimeWidget.widgetType;

  String _timeDisplayMode = 'Minutes and Seconds';

  String get timeDisplayMode => _timeDisplayMode;

  set timeDisplayMode(String value) {
    _timeDisplayMode = value;
    refresh();
  }

  static final List<String> _timeDisplayOptions = [
    'Minutes and Seconds',
    'Seconds Only',
  ];

  int _redStartTime = 20;
  int _yellowStartTime = 30;

  int get redStartTime => _redStartTime;

  set redStartTime(int value) {
    _redStartTime = value;
    refresh();
  }

  int get yellowStartTime => _yellowStartTime;

  set yellowStartTime(int value) {
    _yellowStartTime = value;
    refresh();
  }

  MatchTimeModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    String timeDisplayMode = 'Minutes and Seconds',
    int redStartTime = 20,
    int yellowStartTime = 30,
    super.ntStructMeta,
    super.dataType,
    super.period,
  }) : _timeDisplayMode = timeDisplayMode,
       _yellowStartTime = yellowStartTime,
       _redStartTime = redStartTime,
       super();

  MatchTimeModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _timeDisplayMode =
        tryCast(jsonData['time_display_mode']) ?? 'Minutes and Seconds';

    _timeDisplayOptions.firstWhere(
      (e) => e.toUpperCase() == _timeDisplayMode.toUpperCase(),
      orElse: () => 'Minutes and Seconds',
    );

    _redStartTime =
        tryCast<num>(jsonData['red_start_time'])?.toInt() ?? _redStartTime;
    _yellowStartTime =
        tryCast<num>(jsonData['yellow_start_time'])?.toInt() ??
        _yellowStartTime;
  }

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    Column(
      children: [
        const Text('Time Display Mode'),
        DialogDropdownChooser<String>(
          initialValue: _timeDisplayMode,
          choices: const ['Minutes and Seconds', 'Seconds Only'],
          onSelectionChanged: (value) {
            if (value == null) {
              return;
            }

            timeDisplayMode = value;
          },
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Flexible(
              child: Tooltip(
                message:
                    'The time (in seconds) where time will begin to display in red',
                waitDuration: const Duration(milliseconds: 750),
                child: DialogTextInput(
                  label: 'Red Start Time',
                  initialText: _redStartTime.toString(),
                  onSubmit: (value) {
                    int? newRedTime = int.tryParse(value);

                    if (newRedTime == null) {
                      return;
                    }

                    redStartTime = newRedTime;
                  },
                  formatter: FilteringTextInputFormatter.digitsOnly,
                ),
              ),
            ),
            Flexible(
              child: Tooltip(
                message:
                    'The time (in seconds) where time will begin to display in yellow',
                waitDuration: const Duration(milliseconds: 750),
                child: DialogTextInput(
                  label: 'Yellow Start Time',
                  initialText: _yellowStartTime.toString(),
                  onSubmit: (value) {
                    int? newYellowTime = int.tryParse(value);

                    if (newYellowTime == null) {
                      return;
                    }

                    yellowStartTime = newYellowTime;
                  },
                  formatter: FilteringTextInputFormatter.digitsOnly,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ];

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'time_display_mode': _timeDisplayMode,
    'red_start_time': _redStartTime,
    'yellow_start_time': _yellowStartTime,
  };
}

class MatchTimeWidget extends NTWidget {
  static const String widgetType = 'Match Time';

  const MatchTimeWidget({super.key});

  Color _getTimeColor(MatchTimeModel model, num time) {
    if (time <= model.redStartTime) {
      return Colors.red;
    } else if (time <= model.yellowStartTime) {
      return Colors.yellow;
    } else if (time <= 60.0) {
      return Colors.green;
    }

    return Colors.blue;
  }

  String _secondsToMinutes(num time) =>
      '${(time / 60.0).floor()}:${(time % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    MatchTimeModel model = cast(context.watch<NTWidgetModel>());

    return ValueListenableBuilder(
      valueListenable: model.subscription ?? ValueNotifier(null),
      builder: (context, data, child) {
        double time = tryCast(data) ?? -1.0;
        time = time.floorToDouble();

        String timeDisplayString;
        if (model.timeDisplayMode == 'Minutes and Seconds' && time >= 0) {
          timeDisplayString = _secondsToMinutes(time.toInt());
        } else {
          timeDisplayString = time.toInt().toString();
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(
                  timeDisplayString,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.0,
                    color: _getTimeColor(model, time),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
