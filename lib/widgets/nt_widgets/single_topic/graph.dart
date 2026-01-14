import 'dart:async';
import 'dart:math' show ln10, log, max, min, pow;

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

extension on double {
  String toGraphValueString() {
    double rounded = double.parse(toStringAsFixed(2));
    return rounded % 1 == 0 ? rounded.toInt().toString() : rounded.toString();
  }
}

class GraphModel extends SingleTopicNTWidgetModel {
  @override
  String type = GraphWidget.widgetType;

  late double _timeDisplayed;
  double? _minValue;
  double? _maxValue;
  late Color _mainColor;
  late double _lineWidth;

  double get timeDisplayed => _timeDisplayed;

  set timeDisplayed(double value) {
    _timeDisplayed = value;
    refresh();
  }

  double? get minValue => _minValue;

  set minValue(double? value) {
    _minValue = value;
    refresh();
  }

  double? get maxValue => _maxValue;

  set maxValue(double? value) {
    _maxValue = value;
    refresh();
  }

  Color get mainColor => _mainColor;

  set mainColor(Color value) {
    _mainColor = value;
    refresh();
  }

  double get lineWidth => _lineWidth;

  set lineWidth(double value) {
    _lineWidth = value;
    refresh();
  }

  List<FlSpot> _graphData = [];
  _GraphWidgetGraph? _graphWidget;

  GraphModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    double timeDisplayed = 5.0,
    double? minValue,
    double? maxValue,
    Color mainColor = Colors.cyan,
    double lineWidth = 2.0,
    super.ntStructMeta,
    super.dataType,
    super.period,
  }) : _timeDisplayed = timeDisplayed,
       _minValue = minValue,
       _maxValue = maxValue,
       _mainColor = mainColor,
       _lineWidth = lineWidth,
       super();

  GraphModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _timeDisplayed =
        tryCast(jsonData['time_displayed']) ??
        tryCast(jsonData['visibleTime']) ??
        5.0;
    _minValue = tryCast(jsonData['min_value']);
    _maxValue = tryCast(jsonData['max_value']);
    _mainColor = Color(
      tryCast(jsonData['color']) ?? Colors.cyan.shade500.toARGB32(),
    );
    _lineWidth = tryCast(jsonData['line_width']) ?? 2.0;
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'time_displayed': _timeDisplayed,
    if (_minValue != null) 'min_value': _minValue,
    if (_maxValue != null) 'max_value': _maxValue,
    'color': _mainColor.toARGB32(),
    'line_width': _lineWidth,
  };

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          child: DialogColorPicker(
            onColorPicked: (color) {
              mainColor = color;
            },
            label: 'Graph Color',
            initialColor: _mainColor,
            defaultColor: Colors.cyan,
          ),
        ),
        Flexible(
          child: DialogTextInput(
            onSubmit: (value) {
              double? newTime = double.tryParse(value);

              if (newTime == null) {
                return;
              }
              timeDisplayed = newTime;
            },
            formatter: TextFormatterBuilder.decimalTextFormatter(),
            label: 'Time Displayed (Seconds)',
            initialText: _timeDisplayed.toString(),
          ),
        ),
      ],
    ),
    const SizedBox(height: 5),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          child: DialogTextInput(
            onSubmit: (value) {
              double? newMinimum = double.tryParse(value);
              bool refreshGraph = newMinimum != _minValue;

              _minValue = newMinimum;

              if (refreshGraph) {
                refresh();
              }
            },
            formatter: TextFormatterBuilder.decimalTextFormatter(
              allowNegative: true,
            ),
            label: 'Minimum',
            initialText: _minValue?.toString(),
            allowEmptySubmission: true,
          ),
        ),
        Flexible(
          child: DialogTextInput(
            onSubmit: (value) {
              double? newMaximum = double.tryParse(value);
              bool refreshGraph = newMaximum != _maxValue;

              _maxValue = newMaximum;

              if (refreshGraph) {
                refresh();
              }
            },
            formatter: TextFormatterBuilder.decimalTextFormatter(
              allowNegative: true,
            ),
            label: 'Maximum',
            initialText: _maxValue?.toString(),
            allowEmptySubmission: true,
          ),
        ),
        Flexible(
          child: DialogTextInput(
            onSubmit: (value) {
              double? newWidth = double.tryParse(value);

              if (newWidth == null || newWidth < 0.01) {
                return;
              }

              lineWidth = newWidth;
            },
            formatter: TextFormatterBuilder.decimalTextFormatter(),
            label: 'Line Width',
            initialText: _lineWidth.toString(),
          ),
        ),
      ],
    ),
  ];
}

class GraphWidget extends NTWidget {
  static const String widgetType = 'Graph';

  const GraphWidget({super.key});

  @override
  Widget build(BuildContext context) {
    GraphModel model = cast(context.watch<NTWidgetModel>());

    List<FlSpot>? currentGraphData = model._graphWidget?.getCurrentData();

    if (currentGraphData != null) {
      model._graphData = currentGraphData;
    }

    return model._graphWidget = _GraphWidgetGraph(
      initialData: model._graphData,
      subscription: model.subscription,
      timeDisplayed: model.timeDisplayed,
      lineWidth: model.lineWidth,
      mainColor: model.mainColor,
      minValue: model.minValue,
      maxValue: model.maxValue,
    );
  }
}

class _GraphWidgetGraph extends StatefulWidget {
  final NT4Subscription? subscription;
  final double? minValue;
  final double? maxValue;
  final Color mainColor;
  final double timeDisplayed;
  final double lineWidth;

  final List<FlSpot> initialData;

  final List<FlSpot> _currentData;

  set currentData(List<FlSpot> data) => _currentData
    ..clear()
    ..addAll(data);

  const _GraphWidgetGraph({
    required this.initialData,
    required this.subscription,
    required this.timeDisplayed,
    required this.mainColor,
    required this.lineWidth,
    this.minValue,
    this.maxValue,
  }) : _currentData = initialData;

  List<FlSpot> getCurrentData() => _currentData;

  @override
  State<_GraphWidgetGraph> createState() => _GraphWidgetGraphState();
}

class _GraphWidgetGraphState extends State<_GraphWidgetGraph> {
  late List<FlSpot> _graphData;
  StreamSubscription<Object?>? _subscriptionListener;

  @override
  void initState() {
    super.initState();

    _graphData = List.of(widget.initialData);

    if (_graphData.length < 2) {
      final double x = DateTime.now().microsecondsSinceEpoch.toDouble();
      final double y =
          tryCast(widget.subscription?.value) ?? widget.minValue ?? 0.0;

      _graphData = [FlSpot(x - widget.timeDisplayed * 1e6, y), FlSpot(x, y)];
    }

    widget.currentData = _graphData;

    _initializeListener();
  }

  @override
  void dispose() {
    _subscriptionListener?.cancel();

    super.dispose();
  }

  @override
  void didUpdateWidget(_GraphWidgetGraph oldWidget) {
    if (oldWidget.subscription != widget.subscription) {
      _resetGraphData();
      _subscriptionListener?.cancel();
      _initializeListener();
    }

    super.didUpdateWidget(oldWidget);
  }

  void _resetGraphData() {
    final double x = DateTime.now().microsecondsSinceEpoch.toDouble();
    final double y =
        tryCast<num>(widget.subscription?.value)?.toDouble() ??
        widget.minValue ??
        0.0;

    setState(() {
      _graphData
        ..clear()
        ..addAll([
          FlSpot(x - widget.timeDisplayed * 1e6, y),
          FlSpot(x, y),
        ]);

      widget.currentData = _graphData;
    });
  }

  void _initializeListener() {
    _subscriptionListener?.cancel();
    _subscriptionListener = widget.subscription
        ?.periodicStream(yieldAll: true)
        .listen((data) {
          if (!mounted) {
            return;
          }
          if (data != null) {
            final double time = DateTime.now().microsecondsSinceEpoch
                .toDouble();
            final double windowStart = time - widget.timeDisplayed * 1e6;
            final double y =
                tryCast<num>(data)?.toDouble() ?? widget.minValue ?? 0.0;

            // Remove points older than the display time
            _graphData.removeWhere((element) => element.x < windowStart);

            if (_graphData.isEmpty || _graphData.first.x > windowStart) {
              FlSpot padding = FlSpot(
                windowStart,
                _graphData.isEmpty ? y : _graphData.first.y,
              );
              _graphData.insert(0, padding);
            }

            final FlSpot newPoint = FlSpot(time, y);
            _graphData.add(newPoint);

            setState(() {});
          } else if (_graphData.length > 2) {
            // Only reset if there's more than 2 points to prevent infinite resetting
            _resetGraphData();
          }

          widget.currentData = _graphData;
        });
  }

  (double, double) getValueRange() {
    if (_graphData.isEmpty) {
      return (widget.minValue ?? 0.0, widget.maxValue ?? 1.0);
    }

    double minData = _graphData.first.y;
    double maxData = _graphData.first.y;

    for (final spot in _graphData.skip(1)) {
      minData = min(minData, spot.y);
      maxData = max(maxData, spot.y);
    }

    return (minData, maxData);
  }

  ({double min, double max, double interval}) _calculateAxisBounds(
    BuildContext context,
    double graphHeight,
  ) {
    final style = DefaultTextStyle.of(context).style;

    final textPainter = TextPainter(
      text: TextSpan(text: '0', style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final double roughLabelHeight = textPainter.height * 1.5;
    final int desiredTickCount = max(
      2,
      (graphHeight / roughLabelHeight).floor(),
    );

    double? minY = widget.minValue;
    double? maxY = widget.maxValue;

    if (minY != null && maxY != null) {
      final niceBounds = _calculateNiceBounds(minY, maxY, desiredTickCount);
      return (
        min: niceBounds.min,
        max: niceBounds.max,
        interval: niceBounds.interval,
      );
    }

    final (minData, maxData) = getValueRange();

    double calculatedMin;
    double calculatedMax;

    if (minData == maxData) {
      // Snap either min or max to 0
      if (minData >= 0) {
        calculatedMin = 0.0;
        calculatedMax = (minData == 0) ? 1.0 : minData + minData.abs() * 0.05;
      } else {
        calculatedMax = 0.0;
        calculatedMin = minData - minData.abs() * 0.05;
      }
    } else {
      final double range = maxData - minData;

      calculatedMax = maxData + range * 0.05;

      const double zeroMarginFraction = 0.05;
      final bool isMinCloseToZero =
          minData >= 0 && maxData > 0 && minData < maxData * zeroMarginFraction;

      if (isMinCloseToZero) {
        calculatedMin = 0.0;
      } else {
        calculatedMin = minData - range * 0.05;
      }
    }

    minY ??= calculatedMin;
    maxY ??= calculatedMax;

    if (minY >= maxY) {
      maxY = minY + 1;
    }

    final niceBounds = _calculateNiceBounds(minY, maxY, desiredTickCount);
    return (
      min: niceBounds.min,
      max: niceBounds.max,
      interval: niceBounds.interval,
    );
  }

  ({double min, double max, double interval}) _calculateNiceBounds(
    double min,
    double max,
    int tickCount,
  ) {
    if (tickCount < 2) {
      return (min: min, max: max, interval: max - min);
    }

    if (min == max) {
      return (min: min - 1, max: max + 1, interval: 0.5);
    }

    final double range = max - min;
    double interval = range / (tickCount - 1);

    if (interval == 0) {
      return (min: min, max: max, interval: 0.5);
    }

    final double exponent = pow(
      10,
      -(log(interval.abs()) / ln10).floor(),
    ).toDouble();
    final double niceIntervalSize = (interval * exponent).roundToDouble();

    double niceInterval;
    if (niceIntervalSize < 1.5) {
      niceInterval = 1.0;
    } else if (niceIntervalSize < 3.0) {
      niceInterval = 2.0;
    } else if (niceIntervalSize < 7.0) {
      niceInterval = 5.0;
    } else {
      niceInterval = 10.0;
    }
    niceInterval /= exponent;

    double niceMin = (min / niceInterval).floor() * niceInterval;
    double niceMax = (max / niceInterval).ceil() * niceInterval;

    return (min: niceMin, max: niceMax, interval: niceInterval);
  }

  double _calculateReservedSize(
    BuildContext context,
    double min,
    double max,
    double interval,
  ) {
    final style = DefaultTextStyle.of(context).style;
    if (interval <= 0) {
      return style.fontSize ?? 14;
    }

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    double maxWidth = 0;

    final int stepCount = ((max - min) / interval).round();

    for (int i = 0; i <= stepCount; i++) {
      final double value = min + i * interval;

      final String label = value.toGraphValueString();

      textPainter.text = TextSpan(text: label, style: style);
      textPainter.layout();

      if (textPainter.width > maxWidth) {
        maxWidth = textPainter.width;
      }
    }

    return maxWidth;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double chartHeight = constraints.maxHeight;

        final (:min, :max, :interval) = _calculateAxisBounds(
          context,
          chartHeight,
        );

        final double reservedSize = _calculateReservedSize(
          context,
          min,
          max,
          interval,
        );

        return LineChart(
          LineChartData(
            minY: min,
            maxY: max,
            lineTouchData: LineTouchData(enabled: false),
            clipData: const FlClipData.all(),
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.blueGrey, width: 0.4),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: reservedSize + 4,
                  interval: interval,
                  getTitlesWidget: (value, meta) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      value.toGraphValueString(),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: DefaultTextStyle.of(context).style,
                    ),
                  ),
                ),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: _graphData,
                isCurved: false,
                color: widget.mainColor,
                barWidth: widget.lineWidth,
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
          duration: Duration.zero,
        );
      },
    ),
  );
}
