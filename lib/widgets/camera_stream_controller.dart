import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:elastic_dashboard/services/log.dart';

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

  final Set<Key> _mountedKeys = {};
  final Set<Key> _visibleKeys = {};

  @protected
  bool get inUse =>
      cycleState != StreamCycleState.disposed && _mountedKeys.isNotEmpty;

  @protected
  bool get shouldStream => _visibleKeys.isNotEmpty && inUse;

  bool get isStreamActive;

  void clearError();

  bool isVisible(Key key) => _visibleKeys.contains(key);

  void setVisible(Key key, bool value) {
    logger.trace('Setting visibility to $value for $currentStream');
    if (value) {
      bool hasChanged = !_visibleKeys.contains(key);
      _visibleKeys.add(key);

      if (hasChanged) {
        logger.trace(
          'Visibility changed to true, notifying listeners for stream',
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
          if (inUse) {
            clearError();
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

  @protected
  void switchToNextStream() {
    currentStreamIndex++;
    if (currentStreamIndex >= streams.length) {
      currentStreamIndex = 0;
    }
    logger.info(
      'Switching to stream at index $currentStreamIndex: $currentStream',
    );
  }

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

    logger.debug('Transitioning from $_cycleState to $next');
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
