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

      _graphData = [
        FlSpot(x - widget.timeDisplayed * 1e6, y),
        FlSpot(x, y),
      ];
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
        .listen((
          data,
        ) {
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

  (double?, double?) _calculateAxisBounds() {
    double? minY = widget.minValue;
    double? maxY = widget.maxValue;

    if (minY != null && maxY != null) {
      return (minY, maxY);
    }

    if (_graphData.isEmpty) {
      return (minY ?? 0.0, maxY ?? 1.0);
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
      if (widget.minValue != null && widget.maxValue == null) {
        maxY = minY + 1;
      } else if (widget.minValue == null && widget.maxValue != null) {
        minY = maxY - 1;
      } else {
        minY = minData - 1;
        maxY = maxData + 1;
      }
    }

    if (minY >= maxY) {
      maxY = minY + 1;
    }
    final niceBounds = _calculateNiceBounds(minY, maxY);
    minY = niceBounds.min;
    maxY = niceBounds.max;

    return (minY, maxY);
  }

  ({double min, double max}) _calculateNiceBounds(double min, double max) {
    if (min == max) {
      return (min: min - 1, max: max + 1);
    }

    const int desiredTickCount = 5;
    final double range = max - min;

    if (range == 0) {
      return (min: min, max: max);
    }

    double spacingSize = range / (desiredTickCount - 1);

    if (spacingSize == 0) {
      return (min: min, max: max);
    }

    // Math taken from https://wiki.tcl-lang.org/page/Chart+generation+support
    final double exponent = pow(
      10,
      -(log(spacingSize.abs()) / ln10).floor(),
    ).toDouble();
    final double niceSpacingSize = (spacingSize * exponent).roundToDouble();

    double niceSpacing;
    if (niceSpacingSize < 1.5) {
      niceSpacing = 1.0;
    } else if (niceSpacingSize < 3.0) {
      niceSpacing = 2.0;
    } else if (niceSpacingSize < 7.0) {
      niceSpacing = 5.0;
    } else {
      niceSpacing = 10.0;
    }
    niceSpacing /= exponent;

    double niceMin = (min / niceSpacing).floor() * niceSpacing;
    double niceMax = (max / niceSpacing).ceil() * niceSpacing;

    // Round to 2 decimal places
    niceMin = (niceMin * 100).floorToDouble() / 100;
    niceMax = (niceMax * 100).ceilToDouble() / 100;

    return (min: niceMin, max: niceMax);
  }

  Size measureText(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.right,
      maxLines: 1,
    );
    textPainter.layout();
    return textPainter.size;
  }

  @override
  Widget build(BuildContext context) {
    final (minY, maxY) = _calculateAxisBounds();

    String graphValueToString(double value) {
      double rounded = double.parse(value.toStringAsFixed(2));
      return rounded % 1 == 0 ? rounded.toInt().toString() : rounded.toString();
    }

    double longestLength = 0;

    if (minY == null || maxY == null) {
      for (final spot in _graphData) {
        longestLength = max(
          longestLength,
          measureText(
            graphValueToString(spot.y),
            DefaultTextStyle.of(context).style,
          ).width,
        );
      }
    } else if (minY % 1 != 0 || maxY % 1 != 0 || (maxY - minY <= 3)) {
      for (double tick = minY; tick < maxY; tick += (maxY - minY) / 5) {
        longestLength = max(
          longestLength,
          measureText(
            graphValueToString(tick),
            DefaultTextStyle.of(context).style,
          ).width,
        );
      }
    } else {
      longestLength = max(
        longestLength,
        measureText(
          graphValueToString(minY),
          DefaultTextStyle.of(context).style,
        ).width,
      );
      longestLength = max(
        longestLength,
        measureText(
          graphValueToString(maxY),
          DefaultTextStyle.of(context).style,
        ).width,
      );
    }

    double reservedSize = 4 + longestLength;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
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
                reservedSize: reservedSize,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    graphValueToString(value),
                    overflow: TextOverflow.visible,
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    style: DefaultTextStyle.of(context).style,
                  ),
                ),
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
      ),
    );
  }
}
