import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/multi_topic_dialog_editor.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class TopicProperties {
  String topic;
  Color color;
  double lineWidth;

  TopicProperties({
    required this.topic,
    this.color = Colors.cyan,
    this.lineWidth = 2.0,
  });

  TopicProperties.fromJson(Map<String, dynamic> jsonData)
    : topic = jsonData['topic'] ?? '',
      color = Color(tryCast(jsonData['color']) ?? Colors.cyan.toARGB32()),
      lineWidth = tryCast(jsonData['line_width']) ?? 2.0;

  Map<String, dynamic> toJson() => {
    'topic': topic,
    'color': color.toARGB32(),
    'line_width': lineWidth,
  };
}

class MultiTopicGraphModel extends MultiTopicNTWidgetModel {
  @override
  String type = MultiTopicGraphWidget.widgetType;

  late double _timeDisplayed;
  double? _minValue;
  double? _maxValue;

  List<TopicProperties> topicProperties = [];

  final List<NT4Subscription> _subscriptions = [];

  @override
  List<NT4Subscription> get subscriptions => _subscriptions;

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

  MultiTopicGraphModel({
    required super.ntConnection,

    required super.preferences,

    required super.topic,

    List<Color> colors = const [],

    double timeDisplayed = 5.0,

    double? minValue,

    double? maxValue,

    super.period,
  }) : _timeDisplayed = timeDisplayed,

       _minValue = minValue,

       _maxValue = maxValue,

       super() {
    topicProperties.add(TopicProperties(topic: topic));
  }

  MultiTopicGraphModel.fromJson({
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

    List<dynamic>? propertiesJson = jsonData['topic_properties'];

    if (propertiesJson != null) {
      topicProperties = propertiesJson
          .map((data) => TopicProperties.fromJson(data))
          .toList();
    } else {
      topicProperties.add(TopicProperties(topic: topic));
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'time_displayed': _timeDisplayed,
    'min_value': _minValue,
    'max_value': _maxValue,
    'topic_properties': topicProperties.map((data) => data.toJson()).toList(),
  };

  @override
  void initializeSubscriptions() {
    super.initializeSubscriptions();
    _subscriptions.clear();
    for (var properties in topicProperties) {
      _subscriptions.add(
        ntConnection.subscribeWithOptions(
          properties.topic,
          NT4SubscriptionOptions(periodicRateSeconds: period),
        ),
      );
    }
  }

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          child: DialogTextInput(
            onSubmit: (value) {
              double? newMinimum = double.tryParse(value);
              minValue = newMinimum;
            },
            formatter: TextFormatterBuilder.decimalTextFormatter(
              allowNegative: true,
            ),
            label: 'Minimum Value',
            initialText: _minValue?.toString(),
            allowEmptySubmission: true,
          ),
        ),
        Flexible(
          child: DialogTextInput(
            onSubmit: (value) {
              double? newMaximum = double.tryParse(value);
              maxValue = newMaximum;
            },
            formatter: TextFormatterBuilder.decimalTextFormatter(
              allowNegative: true,
            ),
            label: 'Maximum Value',
            initialText: _maxValue?.toString(),
            allowEmptySubmission: true,
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
              double? newTime = double.tryParse(value);

              if (newTime == null) {
                return;
              }
              timeDisplayed = newTime;
            },
            formatter: TextFormatterBuilder.decimalTextFormatter(),
            label: 'Time Displayed',
            initialText: _timeDisplayed.toString(),
          ),
        ),
      ],
    ),
    const Divider(),
    MultiTopicDialogEditor(
      ntConnection: ntConnection,
      model: this,
      topicProperties: topicProperties,
      onTopicPropertyChanged: (newProperties) {
        topicProperties = newProperties;
        resetSubscription();
      },
      customPropertyBuilder: (context, properties, onDataChanged) => Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Flexible(
            flex: 1,
            child: DialogColorPicker(
              onColorPicked: (color) {
                properties.color = color;
                onDataChanged.call();
              },
              label: 'Graph Color',
              initialColor: properties.color,
              defaultColor: Colors.cyan,
            ),
          ),
          Flexible(
            flex: 1,
            child: DialogTextInput(
              onSubmit: (value) {
                double? newWidth = double.tryParse(value);

                if (newWidth == null || newWidth < 0.01) {
                  return;
                }

                properties.lineWidth = newWidth;
                onDataChanged.call();
              },
              formatter: TextFormatterBuilder.decimalTextFormatter(),
              label: 'Line Width',
              initialText: properties.lineWidth.toString(),
            ),
          ),
        ],
      ),
    ),
  ];
}

class MultiTopicGraphWidget extends NTWidget {
  static const String widgetType = 'Multi-Topic Graph';

  const MultiTopicGraphWidget({super.key});

  @override
  Widget build(BuildContext context) {
    MultiTopicGraphModel model = cast(context.watch<NTWidgetModel>());

    return _GraphWidgetGraph(
      subscriptions: Map.fromEntries(
        model.subscriptions.map((e) => MapEntry(e.topic, e)),
      ),
      topicProperties: model.topicProperties,
      timeDisplayed: model.timeDisplayed,
      minValue: model.minValue,
      maxValue: model.maxValue,
    );
  }
}

class _GraphWidgetGraph extends StatefulWidget {
  final Map<String, NT4Subscription> subscriptions;
  final List<TopicProperties> topicProperties;
  final double? minValue;
  final double? maxValue;
  final double timeDisplayed;

  const _GraphWidgetGraph({
    required this.subscriptions,
    required this.topicProperties,
    required this.timeDisplayed,
    this.minValue,
    this.maxValue,
  });

  @override
  State<_GraphWidgetGraph> createState() => _GraphWidgetGraphState();
}

class _GraphWidgetGraphState extends State<_GraphWidgetGraph>
    with WidgetsBindingObserver {
  final Map<String, ChartSeriesController> _seriesControllers = {};
  late Map<String, List<_GraphPoint>> _graphData;
  final List<StreamSubscription<Object?>> _subscriptionListeners = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _graphData = {};

    _initializeListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    for (var listener in _subscriptionListeners) {
      listener.cancel();
    }

    super.dispose();
  }

  @override
  void didUpdateWidget(_GraphWidgetGraph oldWidget) {
    if (oldWidget.subscriptions != widget.subscriptions) {
      for (var listener in _subscriptionListeners) {
        listener.cancel();
      }

      _initializeListeners();
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      logger.debug('State resumed, refreshing multi-topic graph');
      setState(() {});
    }
  }

  void _initializeListeners() {
    _subscriptionListeners.clear();
    _seriesControllers.clear();
    _graphData.clear();

    for (NT4Subscription subscription in widget.subscriptions.values) {
      _graphData[subscription.topic] = [];

      final double x = DateTime.now().microsecondsSinceEpoch.toDouble();
      final double y =
          tryCast<num>(subscription.value)?.toDouble() ??
          widget.minValue ??
          0.0;

      final initialPoints = [
        _GraphPoint(x: x - widget.timeDisplayed * 1e6, y: y),
        _GraphPoint(x: x, y: y),
      ];

      _graphData[subscription.topic]!.addAll(initialPoints);

      _subscriptionListeners.add(
        subscription.periodicStream(yieldAll: true).listen(
          (data) {
            if (data != null) {
              if (!mounted) {
                return;
              }
              setState(() {
                final double time = DateTime.now().microsecondsSinceEpoch
                    .toDouble();
                final double windowStart = time - widget.timeDisplayed * 1e6;
                final double y =
                    tryCast<num>(data)?.toDouble() ?? widget.minValue ?? 0.0;

                final List<_GraphPoint> newPoints = [];
                final List<int> removedIndexes = [];

                // Remove points older than the display time
                for (int i = 0; i < _graphData[subscription.topic]!.length;) {
                  if (_graphData[subscription.topic]![i].x < windowStart) {
                    _graphData[subscription.topic]!.removeAt(i);
                    removedIndexes.add(i);
                  } else {
                    i++;
                  }
                }

                if (_graphData[subscription.topic]!.isEmpty ||
                    _graphData[subscription.topic]!.first.x > windowStart) {
                  _GraphPoint padding = _GraphPoint(
                    x: windowStart,
                    y: _graphData[subscription.topic]!.isEmpty
                        ? y
                        : _graphData[subscription.topic]!.first.y,
                  );
                  _graphData[subscription.topic]!.insert(0, padding);
                  newPoints.add(padding);
                }

                final _GraphPoint newPoint = _GraphPoint(x: time, y: y);
                _graphData[subscription.topic]!.add(newPoint);
                newPoints.add(newPoint);

                List<int> addedIndexes = newPoints
                    .map(
                      (point) => _graphData[subscription.topic]!.indexOf(point),
                    )
                    .toList();

                try {
                  _seriesControllers[subscription.topic]?.updateDataSource(
                    addedDataIndexes: addedIndexes,
                    removedDataIndexes: removedIndexes.isEmpty
                        ? null
                        : removedIndexes,
                  );
                } catch (_) {
                  // The update data source can get very finicky, so if there's an error,
                  // just refresh everything
                  logger.debug(
                    'Error in graph for topic ${subscription.topic}, resetting',
                  );
                }
              });
            }
          },
        ),
      );
    }
    setState(() {});
  }

  List<FastLineSeries<_GraphPoint, num>> _getChartData() {
    List<FastLineSeries<_GraphPoint, num>> series = [];

    for (TopicProperties properties in widget.topicProperties) {
      if (!_graphData.containsKey(properties.topic)) {
        continue;
      }
      series.add(
        FastLineSeries<_GraphPoint, num>(
          animationDuration: 0.0,
          animationDelay: 0.0,
          sortingOrder: SortingOrder.ascending,
          onRendererCreated: (controller) =>
              _seriesControllers[properties.topic] = controller,
          name: properties.topic,
          color: properties.color,
          width: properties.lineWidth,
          dataSource: _graphData[properties.topic]!,
          xValueMapper: (value, index) => value.x,
          yValueMapper: (value, index) => value.y,
          sortFieldValueMapper: (datum, index) => datum.x,
        ),
      );
    }
    return series;
  }

  @override
  Widget build(BuildContext context) => SfCartesianChart(
    series: _getChartData(),
    margin: const EdgeInsets.fromLTRB(24, 16, 16, 16),
    legend: const Legend(isVisible: true),
    primaryXAxis: const NumericAxis(
      labelStyle: TextStyle(color: Colors.transparent, fontSize: 0),
      majorTickLines: MajorTickLines(width: 0),
      majorGridLines: MajorGridLines(width: 0),
    ),
    primaryYAxis: NumericAxis(
      minimum: widget.minValue,
      maximum: widget.maxValue,
    ),
  );
}

class _GraphPoint {
  final double x;
  final double y;

  const _GraphPoint({required this.x, required this.y});
}
