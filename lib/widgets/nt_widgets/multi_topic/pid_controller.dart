import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/text_formatter_builder.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class PIDControllerModel extends MultiTopicNTWidgetModel {
  @override
  String type = PIDControllerWidget.widgetType;

  String get kpTopicName => '$topic/p';
  String get kiTopicName => '$topic/i';
  String get kdTopicName => '$topic/d';
  String get setpointTopicName => '$topic/setpoint';

  NT4Topic? _kpTopic;
  NT4Topic? _kiTopic;
  NT4Topic? _kdTopic;
  NT4Topic? _setpointTopic;

  NT4Subscription? kpSubscription;
  NT4Subscription? kiSubscription;
  NT4Subscription? kdSubscription;
  NT4Subscription? setpointSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    ?kpSubscription,
    ?kiSubscription,
    ?kdSubscription,
    ?setpointSubscription,
  ];

  TextEditingController? kpTextController;
  TextEditingController? kiTextController;
  TextEditingController? kdTextController;
  TextEditingController? setpointTextController;

  double kpLastValue = 0.0;
  double kiLastValue = 0.0;
  double kdLastValue = 0.0;
  double setpointLastValue = 0.0;

  PIDControllerModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.period,
  }) : super();

  PIDControllerModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    if (topic == null) {
      kpSubscription = null;
      kiSubscription = null;
      kdSubscription = null;
      setpointSubscription = null;
      return;
    }

    kpSubscription = ntConnection.subscribe(kpTopicName, super.period);
    kiSubscription = ntConnection.subscribe(kiTopicName, super.period);
    kdSubscription = ntConnection.subscribe(kdTopicName, super.period);
    setpointSubscription = ntConnection.subscribe(
      setpointTopicName,
      super.period,
    );
  }

  @override
  void resetSubscription() {
    _kpTopic = null;
    _kiTopic = null;
    _kdTopic = null;
    _setpointTopic = null;

    super.resetSubscription();
  }

  void publishKP() {
    bool publishTopic = _kpTopic == null;

    _kpTopic ??= ntConnection.getTopicFromName(kpTopicName);

    double? data = double.tryParse(kpTextController?.text ?? '');

    if (_kpTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_kpTopic!);
    }

    ntConnection.updateDataFromTopic(_kpTopic!, data);
  }

  void publishKI() {
    bool publishTopic = _kiTopic == null;

    _kiTopic ??= ntConnection.getTopicFromName(kiTopicName);

    double? data = double.tryParse(kiTextController?.text ?? '');

    if (_kiTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_kiTopic!);
    }

    ntConnection.updateDataFromTopic(_kiTopic!, data);
  }

  void publishKD() {
    bool publishTopic = _kdTopic == null;

    _kdTopic ??= ntConnection.getTopicFromName(kdTopicName);

    double? data = double.tryParse(kdTextController?.text ?? '');

    if (_kdTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_kdTopic!);
    }

    ntConnection.updateDataFromTopic(_kdTopic!, data);
  }

  void publishSetpoint() {
    bool publishTopic = _setpointTopic == null;

    _setpointTopic ??= ntConnection.getTopicFromName(setpointTopicName);

    double? data = double.tryParse(setpointTextController?.text ?? '');

    if (_setpointTopic == null || data == null) {
      return;
    }

    if (publishTopic) {
      ntConnection.publishTopic(_setpointTopic!);
    }

    ntConnection.updateDataFromTopic(_setpointTopic!, data);
  }
}

class PIDControllerWidget extends NTWidget {
  static const String widgetType = 'PIDController';

  const PIDControllerWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    PIDControllerModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge([
        ...model.subscriptions,
        model.kpTextController,
        model.kiTextController,
        model.kdTextController,
        model.setpointTextController,
      ]),
      builder: (context, child) {
        double kP = tryCast(model.kpSubscription?.value) ?? 0.0;
        double kI = tryCast(model.kiSubscription?.value) ?? 0.0;
        double kD = tryCast(model.kdSubscription?.value) ?? 0.0;
        double setpoint = tryCast(model.setpointSubscription?.value) ?? 0.0;

        // Creates the text editing controllers if they are null
        bool wasNull =
            model.kpTextController == null ||
            model.kiTextController == null ||
            model.kdTextController == null ||
            model.setpointTextController == null;

        model.kpTextController ??= TextEditingController(text: kP.toString());
        model.kiTextController ??= TextEditingController(text: kI.toString());
        model.kdTextController ??= TextEditingController(text: kD.toString());
        model.setpointTextController ??= TextEditingController(
          text: setpoint.toString(),
        );

        // Since they were null they're not being listened to when created during build
        if (wasNull) {
          Future(() => model.refresh());
        }

        // Updates the text of the text editing controller if the kp value has changed
        if (kP != model.kpLastValue) {
          model.kpTextController!.text = kP.toString();
        }
        model.kpLastValue = kP;

        // Updates the text of the text editing controller if the ki value has changed
        if (kI != model.kiLastValue) {
          model.kiTextController!.text = kI.toString();
        }
        model.kiLastValue = kI;

        // Updates the text of the text editing controller if the kd value has changed
        if (kD != model.kdLastValue) {
          model.kdTextController!.text = kD.toString();
        }
        model.kdLastValue = kD;

        // Updates the text of the text editing controller if the setpoint value has changed
        if (setpoint != model.setpointLastValue) {
          model.setpointTextController!.text = setpoint.toString();
        }
        model.setpointLastValue = setpoint;

        TextStyle labelStyle = Theme.of(
          context,
        ).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold);

        bool showWarning =
            kP != double.tryParse(model.kpTextController!.text) ||
            kI != double.tryParse(model.kiTextController!.text) ||
            kD != double.tryParse(model.kdTextController!.text) ||
            setpoint != double.tryParse(model.setpointTextController!.text);

        // The text fields can't be DialogTextInput since DialogTextInput
        // manages its own state which causes setState() while build errors
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // kP
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(),
                Text('P', style: labelStyle),
                const Spacer(),
                Flexible(
                  flex: 5,
                  child: TextField(
                    controller: model.kpTextController,
                    textAlign: TextAlign.left,
                    inputFormatters: [
                      TextFormatterBuilder.decimalTextFormatter(),
                    ],
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      labelText: 'kP',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onSubmitted: (value) {},
                  ),
                ),
                const Spacer(),
              ],
            ),
            // kI
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(),
                Text('I', style: labelStyle),
                const Spacer(),
                Flexible(
                  flex: 5,
                  child: TextField(
                    controller: model.kiTextController,
                    textAlign: TextAlign.left,
                    inputFormatters: [
                      TextFormatterBuilder.decimalTextFormatter(),
                    ],
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      labelText: 'kI',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onSubmitted: (value) {},
                  ),
                ),
                const Spacer(),
              ],
            ),
            // kD
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(),
                Text('D', style: labelStyle),
                const Spacer(),
                Flexible(
                  flex: 5,
                  child: TextField(
                    controller: model.kdTextController,
                    textAlign: TextAlign.left,
                    inputFormatters: [
                      TextFormatterBuilder.decimalTextFormatter(),
                    ],
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      labelText: 'kD',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onSubmitted: (value) {},
                  ),
                ),
                const Spacer(),
              ],
            ),
            Row(
              children: [
                const Spacer(),
                Text('Setpoint', style: labelStyle),
                const Spacer(),
                Flexible(
                  flex: 5,
                  child: TextField(
                    controller: model.setpointTextController,
                    textAlign: TextAlign.left,
                    inputFormatters: [
                      TextFormatterBuilder.decimalTextFormatter(),
                    ],
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      labelText: 'Setpoint',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onSubmitted: (value) {},
                  ),
                ),
                const Spacer(),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () {
                    model.publishKP();
                    model.publishKI();
                    model.publishKD();
                    model.publishSetpoint();
                  },
                  style: ButtonStyle(
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                    ),
                  ),
                  child: const Text('Publish Values'),
                ),
                const SizedBox(width: 10),
                Icon(
                  (showWarning) ? Icons.priority_high : Icons.check,
                  color: (showWarning) ? Colors.red : Colors.green,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
