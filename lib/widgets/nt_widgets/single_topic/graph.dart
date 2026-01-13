import 'dart:async';

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

class _GraphWidgetGraphState extends State<_GraphWidgetGraph>
    with WidgetsBindingObserver {
  late List<FlSpot> _graphData;
  StreamSubscription<Object?>? _subscriptionListener;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

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
    WidgetsBinding.instance.removeObserver(this);

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

  @override
  Widget build(BuildContext context) => LineChart(
    LineChartData(
      minY: widget.minValue,
      maxY: widget.maxValue,
      lineTouchData: LineTouchData(enabled: false),
      clipData: const FlClipData.all(),
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: true),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) =>
                Text(double.parse(value.toStringAsFixed(2)).toString()),
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
  );
}
