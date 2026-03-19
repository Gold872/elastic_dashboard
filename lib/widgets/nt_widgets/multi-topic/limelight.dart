import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class LimelightModel extends MultiTopicNTWidgetModel {
  @override
  String type = LimelightWiget.widgetType;

  String get txTopic => '$topic/tx';
  String get tyTopic => '$topic/ty';
  String get pipeline => '$topic/pipeline';
  String get sensor_grain => '$topic/sensor_grain';
  String get black_level_offset => '$topic/black_level_offset';
  String get exposure => '$topic/exposure';

  late NT4Subscription txSubscription;
  late NT4Subscription tySubscription;
  late NT4Subscription pipelineSubscription;
  late NT4Subscription sensor_grainSubscription;  
  late NT4Subscription black_level_offsetSubscription;
  late NT4Subscription exposureLevel;

  @override
    List<NT4Subscription> get subscriptions => [
        txSubscription,
        tySubscription,
        pipelineSubscription,
        sensor_grainSubscription,
        black_level_offsetSubscription,
        exposureLevel,
      ];
      LimelightModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.dataType,
    super.period,
  });

  @override
  void init(){
    super.init();
    
    txSubscription = ntConnection.subscribe(txTopic, period);
    tySubscription = ntConnection.subscribe(tyTopic, period);
    pipelineSubscription = ntConnection.subscribe(pipeline, period);
    sensor_grainSubscription = ntConnection.subscribe(sensor_grain, period);
    black_level_offsetSubscription = ntConnection.subscribe(black_level_offset, period);
    exposureLevel = ntConnection.subscribe(exposure, period);
    
  }


  LimelightModel.fromJson({    required super.ntConnection,
    required super.preferences,
   required Map<String, dynamic> jsonData,}) : super.fromJson(jsonData: jsonData);
      
  
}


class LimelightWiget extends NTWidget{
  static const String widgetType = "Limelight";

  const LimelightWiget({super.key});
  
  
  @override
  Widget build(BuildContext context) {
    LimelightModel model = cast(context.watch<NTWidgetModel>());
    double value = model.subscriptions[5].value as double;
    return Stack(
      children: [
        Row(children:[ Text('Exposure'),Slider(value: value, onChanged: (double value) {  value = value;},min: 0, max: 5,)])
      ]
    );
  }


}
