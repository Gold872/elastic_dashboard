import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/custom_loading_indicator.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/mjpeg.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class CameraStreamModel extends MultiTopicNTWidgetModel {
  @override
  String type = CameraStreamWidget.widgetType;

  String get streamsTopic => '$topic/streams';

  NT4Subscription? streamsSubscription;

  @override
  List<NT4Subscription> get subscriptions => [?streamsSubscription];

  int? quality;
  int? fps;
  Size? resolution;
  int _rotationTurns = 0;

  MjpegController? controller;

  int get rotationTurns => _rotationTurns;

  set rotationTurns(int value) {
    _rotationTurns = value;
    notifyListeners();
  }

  String getUrlWithParameters(String urlString) {
    Uri url = Uri.parse(urlString);

    Map<String, String> parameters = Map<String, String>.from(
      url.queryParameters,
    );

    parameters.addAll({
      if (resolution != null &&
          resolution!.width != 0.0 &&
          resolution!.height != 0.0)
        'resolution':
            '${resolution!.width.floor()}x${resolution!.height.floor()}',
      if (fps != null) 'fps': '$fps',
      if (quality != null) 'compression': '$quality',
    });

    return url.replace(queryParameters: parameters).toString();
  }

  CameraStreamModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    int? compression,
    this.fps,
    this.resolution,
    int rotation = 0,
    super.period,
  }) : quality = compression,
       _rotationTurns = rotation,
       super();

  CameraStreamModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    quality = tryCast(jsonData['compression']);
    fps = tryCast(jsonData['fps']);
    _rotationTurns = tryCast(jsonData['rotation_turns']) ?? 0;

    List<num>? resolution = tryCast<List<Object?>>(
      jsonData['resolution'],
    )?.whereType<num>().toList();

    if (resolution != null && resolution.length > 1) {
      if (resolution[0] % 2 != 0) {
        resolution[0] += 1;
      }
      if (resolution[0] > 0 && resolution[1] > 0) {
        this.resolution = Size(
          resolution[0].toDouble(),
          resolution[1].toDouble(),
        );
      }
    }
  }

  @override
  void init() {
    ntConnection.ntConnected.addListener(onNTConnected);
    super.init();
  }

  @override
  void initializeSubscriptions() {
    if (topic == null) {
      streamsSubscription = null;
      return;
    }

    streamsSubscription = ntConnection.subscribe(streamsTopic, super.period);
  }

  @override
  void resetSubscription() {
    closeClient();

    super.resetSubscription();
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'rotation_turns': rotationTurns,
    if (quality != null) 'compression': quality,
    if (fps != null) 'fps': fps,
    if (resolution != null)
      'resolution': [resolution!.width, resolution!.height],
  };

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    StatefulBuilder(
      builder: (context, setState) => Row(
        children: [
          Flexible(
            child: DialogTextInput(
              allowEmptySubmission: true,
              initialText: fps?.toString() ?? '-1',
              label: 'FPS',
              formatter: FilteringTextInputFormatter.digitsOnly,
              onSubmit: (value) {
                int? newFPS = int.tryParse(value);

                setState(() {
                  if (newFPS == -1 || newFPS == 0) {
                    fps = null;
                    return;
                  }

                  fps = newFPS;
                });
              },
            ),
          ),
          const SizedBox(width: 10.0),
          const Text('Resolution'),
          Flexible(
            child: DialogTextInput(
              allowEmptySubmission: true,
              initialText: resolution?.width.floor().toString() ?? '-1',
              label: 'Width',
              formatter: FilteringTextInputFormatter.digitsOnly,
              onSubmit: (value) {
                int? newWidth = int.tryParse(value);

                setState(() {
                  if (newWidth == null || newWidth == 0) {
                    resolution = null;
                    return;
                  }

                  if (newWidth! % 2 != 0) {
                    // Won't allow += for some reason
                    newWidth = newWidth! + 1;
                  }

                  resolution = Size(
                    newWidth!.toDouble(),
                    resolution?.height.toDouble() ?? 0,
                  );
                });
              },
            ),
          ),
          const Text('x'),
          Flexible(
            child: DialogTextInput(
              allowEmptySubmission: true,
              initialText: resolution?.height.floor().toString() ?? '-1',
              label: 'Height',
              formatter: FilteringTextInputFormatter.digitsOnly,
              onSubmit: (value) {
                int? newHeight = int.tryParse(value);

                setState(() {
                  if (newHeight == null || newHeight == 0) {
                    resolution = null;
                    return;
                  }

                  resolution = Size(
                    resolution?.width.toDouble() ?? 0,
                    newHeight.toDouble(),
                  );
                });
              },
            ),
          ),
        ],
      ),
    ),
    StatefulBuilder(
      builder: (context, setState) => Row(
        children: [
          const Text('Quality:'),
          Expanded(
            child: Slider(
              value: quality?.toDouble() ?? -5.0,
              min: -5.0,
              max: 100.0,
              divisions: 104,
              label: '${quality ?? -1}',
              onChanged: (value) {
                setState(() {
                  if (value < 0) {
                    quality = null;
                  } else {
                    quality = value.floor();
                  }
                });
              },
            ),
          ),
        ],
      ),
    ),
    TextButton(
      onPressed: () => refresh(),
      child: const Text('Apply Quality Settings'),
    ),
    const SizedBox(height: 5),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.0),
                ),
              ),
              label: const Text('Rotate Left'),
              icon: const Icon(Icons.rotate_90_degrees_ccw),
              onPressed: () {
                int newRotation = rotationTurns - 1;
                if (newRotation < 0) {
                  newRotation += 4;
                }
                rotationTurns = newRotation;
              },
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.0),
                ),
              ),
              label: const Text('Rotate Right'),
              icon: const Icon(Icons.rotate_90_degrees_cw),
              onPressed: () {
                int newRotation = rotationTurns + 1;
                if (newRotation >= 4) {
                  newRotation -= 4;
                }
                rotationTurns = newRotation;
              },
            ),
          ),
        ),
      ],
    ),
  ];

  @override
  void softDispose({bool deleting = false}) {
    if (deleting) {
      controller?.dispose();
      ntConnection.ntConnected.removeListener(onNTConnected);
    }

    super.softDispose(deleting: deleting);
  }

  void onNTConnected() {
    if (ntConnection.ntConnected.value) {
      closeClient();
    } else {
      controller?.changeCycleState(StreamCycleState.idle);
    }
  }

  void closeClient() {
    controller?.dispose();
    controller = null;
  }
}

class CameraStreamWidget extends NTWidget {
  static const String widgetType = 'Camera Stream';

  const CameraStreamWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    CameraStreamModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge([
        model.streamsSubscription,
        model.ntConnection.ntConnected,
      ]),
      builder: (context, child) {
        List<Object?> rawStreams =
            tryCast(model.streamsSubscription?.value) ?? [];

        List<String> streams = [];
        for (Object? stream in rawStreams) {
          if (stream == null ||
              stream is! String ||
              !stream.startsWith('mjpg:')) {
            continue;
          }

          streams.add(stream.substring('mjpg:'.length));
        }

        if (streams.isEmpty || !model.ntConnection.ntConnected.value) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (model.controller?.previousImage != null)
                Opacity(
                  opacity: 0.35,
                  child: Image.memory(
                    Uint8List.fromList(model.controller!.previousImage!),
                    fit: BoxFit.contain,
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CustomLoadingIndicator(),
                  const SizedBox(height: 10),
                  Text(
                    (model.ntConnection.isNT4Connected)
                        ? 'Waiting for Camera Stream connection...'
                        : 'Waiting for Network Tables connection...',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          );
        }

        bool createNewWidget = model.controller == null;

        List<String> streamUrls = streams
            .map((stream) => model.getUrlWithParameters(stream))
            .toList();

        createNewWidget =
            createNewWidget ||
            !(model.controller?.streams.equals(streamUrls) ?? false);

        if (createNewWidget) {
          model.controller?.dispose();

          model.controller = MjpegController(
            streams: streamUrls,
            timeout: const Duration(milliseconds: 500),
          );
        }

        return IntrinsicWidth(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  ValueListenableBuilder(
                    valueListenable: model.controller!.framesPerSecond,
                    builder: (context, value, child) => Text('FPS: $value'),
                  ),
                  const Spacer(),
                  ValueListenableBuilder(
                    valueListenable: model.controller!.bandwidth,
                    builder: (context, value, child) =>
                        Text('Bandwidth: ${value.toStringAsFixed(2)} Mbps'),
                  ),
                ],
              ),
              Flexible(
                child: Mjpeg(
                  controller: model.controller!,
                  fit: BoxFit.contain,
                  expandToFit: true,
                  quarterTurns: model.rotationTurns,
                ),
              ),
              const Text(''),
            ],
          ),
        );
      },
    );
  }
}
