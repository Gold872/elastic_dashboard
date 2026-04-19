import 'dart:async';

import 'package:flutter/foundation.dart';

enum StreamCycleState {
  idle,
  connecting,
  reconnecting,
  streaming,
  disposed,
  failed,
}

abstract class CameraStreamController extends ChangeNotifier {
  final List<String> streams;
  final Duration timeout;
  final Map<String, String> headers;

  int currentStreamIndex = 0;

  String get currentStream =>
      streams[currentStreamIndex.clamp(0, streams.length - 1)];

  final ValueNotifier<double> bandwidth = ValueNotifier(0);
  final ValueNotifier<int> framesPerSecond = ValueNotifier(0);

  Timer? metricsTimer;

  StreamCycleState _cycleState = StreamCycleState.idle;
  StreamCycleState get cycleState => _cycleState;

  void startMetricsTimer() {
    metricsTimer?.cancel();
    metricsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => updateMetrics(),
    );
  }

  void stopMetricsTimer() {
    metricsTimer?.cancel();
    metricsTimer = null;
    bandwidth.value = 0;
    framesPerSecond.value = 0;
  }

  Future<void> updateMetrics() async {}

  CameraStreamController({
    required this.streams,
    this.timeout = const Duration(seconds: 5),
    this.headers = const {},
  });

  void changeCycleState(StreamCycleState next) {
    if (_cycleState == next || _cycleState == StreamCycleState.disposed) {
      return;
    }
    _cycleState = next;
    onCycleStateChanged();
  }

  void onCycleStateChanged() {}

  @override
  @mustCallSuper
  void dispose() {
    stopMetricsTimer();
    bandwidth.dispose();
    framesPerSecond.dispose();
    _cycleState = StreamCycleState.disposed;
    super.dispose();
  }
}
