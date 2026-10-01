import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:http/http.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/widgets/custom_loading_indicator.dart';

/// A preprocessor for each JPEG frame from an MJPEG stream.
class MjpegPreprocessor {
  List<int>? process(List<int> frame) => frame;
}

/// An Mjpeg.
class Mjpeg extends StatefulWidget {
  final MjpegController controller;
  final BoxFit? fit;
  final bool expandToFit;
  final int quarterTurns;
  final double? width;
  final double? height;

  final WidgetBuilder? loading;
  final Widget Function(BuildContext contet, dynamic error, dynamic stack)?
  error;

  const Mjpeg({
    required this.controller,
    this.width,
    this.height,
    this.fit,
    this.expandToFit = false,
    this.quarterTurns = 0,
    this.error,
    this.loading,
    super.key,
  });

  @override
  State<Mjpeg> createState() => _MjpegState();
}

class _MjpegState extends State<Mjpeg> {
  final streamKey = UniqueKey();

  @override
  void initState() {
    widget.controller.addListener(_onControllerUpdate);
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);

    widget.controller.setMounted(streamKey, false);
    widget.controller.setVisible(streamKey, false);

    super.dispose();
  }

  @override
  void didUpdateWidget(Mjpeg oldWidget) {
    final controller = widget.controller;
    final oldController = oldWidget.controller;

    if (oldController != controller) {
      oldController.removeListener(_onControllerUpdate);
      controller.addListener(_onControllerUpdate);

      controller.setMounted(streamKey, oldController.isMounted(streamKey));
      controller.setVisible(streamKey, oldController.isVisible(streamKey));
    }
    super.didUpdateWidget(oldWidget);
  }

  void _onControllerUpdate() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    controller.setMounted(streamKey, context.mounted);

    late Widget streamView;

    if (controller.errorState.value != null && kDebugMode) {
      String errorText =
          '${controller.errorState.value!.first}\n${controller.errorState.value!.last.toString()}';
      streamView = SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.error == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    errorText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            : widget.error!(
                context,
                controller.errorState.value!.first,
                controller.errorState.value!.last,
              ),
      );
    } else {
      streamView = StreamBuilder<List<int>?>(
        stream: controller.imageStream.stream,
        builder: (context, snapshot) {
          if (!controller.isStreamActive) {
            // Request has been sent but no status received yet
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CustomLoadingIndicator(),
                const SizedBox(height: 10),
                const Text('Attempting to establish HTTP connection.'),
              ],
            );
          }
          if (snapshot.data == null && controller.previousImage == null) {
            return SizedBox(
              width: widget.width,
              height: widget.height,
              child:
                  widget.loading?.call(context) ??
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CustomLoadingIndicator(),
                      const SizedBox(height: 10),
                      const Text(
                        'Connection established but no data received.\nCamera may be disconnected from device.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
            );
          }

          return RotatedBox(
            quarterTurns: widget.quarterTurns,
            child: Image.memory(
              Uint8List.fromList(snapshot.data ?? controller.previousImage!),
              width: widget.width,
              height: widget.height,
              gaplessPlayback: true,
              fit: widget.fit,
              scale: (widget.expandToFit) ? 1e-6 : 1.0,
            ),
          );
        },
      );
    }

    return VisibilityDetector(
      key: streamKey,
      child: streamView,
      onVisibilityChanged: (VisibilityInfo info) {
        if (controller.isMounted(streamKey)) {
          controller.setVisible(streamKey, info.visibleFraction != 0);
        }
      },
    );
  }
}

enum StreamCycleState { idle, connecting, reconnecting, streaming, disposed }

class MjpegController extends ChangeNotifier {
  static const _trigger = 0xFF;
  static const _soi = 0xD8;
  static const _eoi = 0xD9;

  final List<String> streams;
  final bool isLive;
  final Duration timeout;
  final Map<String, String> headers;

  int currentStreamIndex = 0;

  String get currentStream =>
      streams[currentStreamIndex.clamp(0, streams.length - 1)];

  Client httpClient = Client();

  StreamSubscription<List<int>>? _rawSubscription;

  ValueNotifier<double> bandwidth = ValueNotifier(0);
  ValueNotifier<int> framesPerSecond = ValueNotifier(0);

  Timer? _metricsTimer;

  final List<int> _buffer = [];

  int _bitCount = 0;
  int _frameCount = 0;

  ValueNotifier<List<dynamic>?> errorState = ValueNotifier(null);
  StreamController<List<int>?> imageStream = StreamController.broadcast();
  List<int>? previousImage;

  final MjpegPreprocessor? preprocessor;

  final Set<Key> _mountedKeys = {};
  final Set<Key> _visibleKeys = {};

  StreamCycleState _cycleState = StreamCycleState.idle;
  StreamCycleState get cycleState => _cycleState;

  bool get _inUse =>
      cycleState != StreamCycleState.disposed && _mountedKeys.isNotEmpty;

  bool get _shouldStream => _visibleKeys.isNotEmpty && _inUse;

  bool isVisible(Key key) => _visibleKeys.contains(key);

  void setVisible(Key key, bool value) {
    logger.trace('Setting visibility to $value for $currentStream');
    if (value) {
      bool hasChanged = !_visibleKeys.contains(key);
      _visibleKeys.add(key);

      if (hasChanged) {
        logger.trace(
          'Visibility changed to true, notifying listeners for mjpeg stream',
        );
        if (!isStreamActive && cycleState != StreamCycleState.reconnecting) {
          changeCycleState(StreamCycleState.connecting);
        }
        notifyListeners();
      }
    } else {
      _visibleKeys.remove(key);

      if (_visibleKeys.isEmpty) {
        Future(() {
          if (_inUse) {
            errorState.value = null;
          }
        });
        changeCycleState(StreamCycleState.idle);
      }
    }
  }

  bool isMounted(Key key) => _mountedKeys.contains(key);

  void setMounted(Key key, bool value) {
    logger.trace('Setting mounted to $value for $currentStream');
    if (value) {
      _mountedKeys.add(key);
    } else {
      _mountedKeys.remove(key);
    }
  }

  void changeCycleState(StreamCycleState next) {
    if (cycleState == next || cycleState == StreamCycleState.disposed) {
      return;
    }

    logger.debug('Transitioning from $cycleState to $next');
    _cycleState = next;
    _updateCycleState();
  }

  void _updateCycleState() {
    switch (cycleState) {
      case StreamCycleState.idle || StreamCycleState.disposed:
        if (isStreamActive) {
          stopStream();
        }
        break;
      case StreamCycleState.connecting:
        startStream();
        break;
      case StreamCycleState.streaming:
        break;
      case StreamCycleState.reconnecting:
        if (isStreamActive) stopStream();
        unawaited(
          Future.delayed(const Duration(milliseconds: 100), () {
            // State changed during delay
            if (cycleState != StreamCycleState.reconnecting) return;
            _switchToNextStream();
            changeCycleState(StreamCycleState.connecting);
          }),
        );
        break;
    }
  }

  bool get isStreamActive => _rawSubscription != null;

  MjpegController({
    required this.streams,
    this.isLive = true,
    this.timeout = const Duration(seconds: 5),
    this.headers = const {},
    this.preprocessor,
  }) {
    errorState.addListener(_onError);
  }

  @visibleForTesting
  MjpegController.withMockClient({
    required this.streams,
    this.isLive = true,
    this.timeout = const Duration(seconds: 5),
    this.headers = const {},
    this.preprocessor,
    required this.httpClient,
  }) {
    errorState.addListener(_onError);
  }

  void _onError() {
    if (errorState.value != null) {
      logger.error(
        'Error on Mjpeg stream for URL $currentStream',
        errorState.value?.firstOrNull,
        errorState.value?.lastOrNull,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() async {
    errorState.removeListener(_onError);
    await stopStream();
    await imageStream.close();
    changeCycleState(StreamCycleState.disposed);
    super.dispose();
  }

  Future<void> startStream() async {
    if (isStreamActive ||
        !_shouldStream ||
        cycleState != StreamCycleState.connecting) {
      return;
    }
    String stream = streams[currentStreamIndex];
    logger.info('Starting camera stream on URL $stream');
    ByteStream? byteStream;
    try {
      final request = Request('GET', Uri.parse(stream));
      request.headers.addAll(headers);
      final response = await httpClient
          .send(request)
          .timeout(
            timeout,
          ); //timeout is to prevent process to hang forever in some case

      if (response.statusCode >= 200 && response.statusCode < 300) {
        byteStream = response.stream;
      } else {
        if (_inUse) {
          errorState.value = [
            HttpException(
              'Stream returned status code ${response.statusCode}: "${response.reasonPhrase}"',
            ),
            StackTrace.current,
          ];
          imageStream.add(null);
        }
      }
    } catch (error, stack) {
      // Timed out
      if (error.toString().contains('Connection attempt cancelled')) {
        errorState.value = [
          HttpException('Connection timed out', uri: Uri.tryParse(stream)),
          stack,
        ];
      } else if (!error // we ignore those errors in case play/pause is triggers
          .toString()
          .contains('Connection closed before full header was received')) {
        if (_inUse) {
          errorState.value = [error, stack];
          imageStream.add(null);
        }
      }
    }

    if (!_shouldStream) {
      return;
    }

    if (byteStream == null) {
      changeCycleState(StreamCycleState.reconnecting);
      return;
    }

    changeCycleState(StreamCycleState.streaming);

    previousImage = null;
    _buffer.clear();

    _rawSubscription = byteStream.listen(
      (data) {
        _bitCount += data.length * Uint8List.bytesPerElement * 8;
        _handleData(data);
      },
      onDone: () {
        changeCycleState(StreamCycleState.reconnecting);
        notifyListeners();
      },
    );

    _metricsTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      _updateMetrics,
    );

    notifyListeners();
  }

  void _updateMetrics(dynamic _) {
    bandwidth.value = _bitCount / 1e6;
    framesPerSecond.value = _frameCount;

    _bitCount = 0;
    _frameCount = 0;
  }

  void _switchToNextStream() {
    currentStreamIndex++;
    if (currentStreamIndex >= streams.length) {
      currentStreamIndex = 0;
    }
    logger.info(
      'Switching to stream at index $currentStreamIndex: $currentStream',
    );
  }

  Future<void> stopStream() async {
    logger.info('Stopping camera stream on URL $currentStream');
    _metricsTimer?.cancel();
    _metricsTimer = null;
    await _rawSubscription?.cancel();
    _rawSubscription = null;
    _buffer.clear();
    _bitCount = 0;
    _frameCount = 0;
    httpClient.close();
    httpClient = Client();
  }

  void _handleNewPacket() {
    logger.trace('Handling a ${_buffer.length} byte packet');
    List<int> imageData = preprocessor?.process(_buffer) ?? List.from(_buffer);
    previousImage = imageData;
    imageStream.add(imageData);
    _frameCount++;
    _buffer.clear();
    errorState.value = null;
  }

  void _handleData(List<int> data) {
    if (_buffer.isNotEmpty && _buffer.last == _trigger) {
      if (data.first == _eoi) {
        _buffer.add(data.first);
        _handleNewPacket();
        if (!isLive) {
          dispose();
        }
      }
    }
    for (var i = 0; i < data.length - 1; i++) {
      final d = data[i];
      final d1 = data[i + 1];

      if (d == _trigger && d1 == _soi) {
        _buffer.clear();
        _buffer.add(d);
      } else if (d == _trigger && d1 == _eoi && _buffer.isNotEmpty) {
        _buffer.add(d);
        _buffer.add(d1);

        _handleNewPacket();
        if (!isLive) {
          dispose();
        }
      } else if (_buffer.isNotEmpty) {
        _buffer.add(d);
        if (i == data.length - 2) {
          _buffer.add(d1);
        }
      }
    }
  }
}
