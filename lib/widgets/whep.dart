import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:visibility_detector/visibility_detector.dart';

import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/widgets/camera_stream_controller.dart';
import 'package:elastic_dashboard/widgets/custom_loading_indicator.dart';

class WhepController extends CameraStreamController {
  RTCPeerConnection? _pc;
  RTCVideoRenderer? _renderer;
  Uri? _resourceUri;

  Object? _lastError;
  Object? get lastError => _lastError;

  bool _connecting = false;
  int _retryCount = 0;

  int _lastBytesReceived = 0;
  DateTime? _lastStatsAt;

  final Set<Key> _mountedKeys = {};
  final Set<Key> _visibleKeys = {};

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
          'Visibility changed to true, notifying listeners for whep stream',
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
            _lastError = null;
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

  WhepController({
    required super.streams,
    super.timeout = const Duration(seconds: 5),
    super.headers = const {},
  });

  RTCVideoRenderer? get renderer => _renderer;

  bool get isStreamActive => _pc != null;

  @override
  void changeCycleState(StreamCycleState next) {
    if (cycleState == next || cycleState == StreamCycleState.disposed) {
      return;
    }

    logger.debug('Transitioning from $cycleState to $next');
    super.changeCycleState(next);
  }

  @override
  void onCycleStateChanged() {
    _updateCycleState();
  }

  void _updateCycleState() {
    switch (cycleState) {
      case StreamCycleState.idle || StreamCycleState.disposed:
        if (isStreamActive) {
          unawaited(_teardown());
        }
        break;
      case StreamCycleState.connecting:
        unawaited(_connect());
        break;
      case StreamCycleState.streaming:
      case StreamCycleState.failed:
        break;
      case StreamCycleState.reconnecting:
        if (isStreamActive) unawaited(_teardown());
        unawaited(
          Future.delayed(const Duration(milliseconds: 500), () {
            // State changed during delay
            if (cycleState != StreamCycleState.reconnecting) return;
            _retryCount++;
            _switchToNextStream();
            logger.info(
              'WebRTC reconnection attempt for $currentStream (attempt $_retryCount)',
            );
            changeCycleState(StreamCycleState.connecting);
          }),
        );
        break;
    }
  }

  Future<void> _connect() async {
    if (isStreamActive ||
        _connecting ||
        !_shouldStream ||
        cycleState != StreamCycleState.connecting) {
      return;
    }

    _connecting = true;
    notifyListeners();

    RTCPeerConnection? pc;
    try {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      _renderer = renderer;

      pc = await createPeerConnection({
        'iceServers': const [],
        'sdpSemantics': 'unified-plan',
      });
      _pc = pc;
      final sessionPc = pc;

      pc.onTrack = (RTCTrackEvent event) {
        if (!identical(_pc, sessionPc)) return;
        if (event.streams.isNotEmpty) {
          _renderer?.srcObject = event.streams.first;
          notifyListeners();
        }
      };

      pc.onConnectionState = (RTCPeerConnectionState s) {
        if (!identical(_pc, sessionPc)) return;
        logger.debug('WHEP peer connection state: $s for $currentStream');
        if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          _lastError ??= Exception('Peer connection $s');
          changeCycleState(StreamCycleState.reconnecting);
        }
      };

      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.RecvOnly,
        ),
      );

      final offer = await pc.createOffer({});
      await pc.setLocalDescription(offer);
      await _waitForIceGathering(pc);

      final localDesc = await pc.getLocalDescription();
      final offerSdp = localDesc?.sdp;
      if (offerSdp == null) {
        throw Exception('WHEP: failed to generate local SDP offer');
      }

      final endpoint = Uri.parse(currentStream);
      final response = await http
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/sdp',
              'Accept': 'application/sdp',
              ...headers,
            },
            body: offerSdp,
          )
          .timeout(timeout);

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception(
          'WHEP endpoint returned ${response.statusCode}: ${response.body}',
        );
      }

      final location = response.headers['location'];
      if (location != null && location.isNotEmpty) {
        _resourceUri = endpoint.resolve(location);
      }

      await pc.setRemoteDescription(
        RTCSessionDescription(response.body, 'answer'),
      );

      if (!_shouldStream) {
        await _teardown();
        return;
      }

      changeCycleState(StreamCycleState.streaming);
      _lastError = null;
      _retryCount = 0;
      startMetricsTimer();
      notifyListeners();
    } catch (error, stack) {
      logger.error('WHEP connection failed for $currentStream', error, stack);
      _lastError = error;
      await _teardown();
      if (!_shouldStream) return;
      changeCycleState(StreamCycleState.reconnecting);
      notifyListeners();
    } finally {
      _connecting = false;
    }
  }

  Future<void> _waitForIceGathering(RTCPeerConnection pc) async {
    if (pc.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    final completer = Completer<void>();
    pc.onIceGatheringState = (RTCIceGatheringState s) {
      if (s == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !completer.isCompleted) {
        completer.complete();
      }
    };
    await completer.future.timeout(
      timeout,
      onTimeout: () {},
    );
    pc.onIceGatheringState = null;
  }

  @override
  void startMetricsTimer() {
    _lastBytesReceived = 0;
    _lastStatsAt = null;
    super.startMetricsTimer();
  }

  @override
  Future<void> updateMetrics() async {
    final pc = _pc;
    if (pc == null) return;
    try {
      final reports = await pc.getStats();
      int? bytesReceived;
      int? fps;
      for (final report in reports) {
        if (report.type != 'inbound-rtp') continue;
        final values = report.values;
        if (values['kind'] != 'video') continue;
        bytesReceived ??= (values['bytesReceived'] as num?)?.toInt();
        fps ??= (values['framesPerSecond'] as num?)?.toInt();
      }
      final now = DateTime.now();
      if (bytesReceived != null) {
        if (_lastStatsAt != null && _lastBytesReceived > 0) {
          final dt = now.difference(_lastStatsAt!).inMilliseconds / 1000.0;
          final delta = bytesReceived - _lastBytesReceived;
          if (dt > 0 && delta >= 0) {
            bandwidth.value = (delta * 8) / 1e6 / dt;
          }
        }
        _lastBytesReceived = bytesReceived;
        _lastStatsAt = now;
      }
      if (fps != null) framesPerSecond.value = fps;
    } catch (e) {
      logger.trace('WHEP getStats failed: $e');
    }
  }

  @override
  void stopMetricsTimer() {
    super.stopMetricsTimer();
    _lastBytesReceived = 0;
    _lastStatsAt = null;
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

  Future<void> _teardown() async {
    stopMetricsTimer();

    final resource = _resourceUri;
    _resourceUri = null;
    if (resource != null) {
      unawaited(
        http
            .delete(resource, headers: headers)
            .timeout(const Duration(seconds: 2))
            .catchError((_) => http.Response('', 0)),
      );
    }

    final pc = _pc;
    _pc = null;
    if (pc != null) {
      try {
        await pc.close();
      } catch (_) {}
    }

    final renderer = _renderer;
    _renderer = null;
    if (renderer != null) {
      try {
        renderer.srcObject = null;
        await renderer.dispose();
      } catch (_) {}
    }
  }

  @override
  void dispose() async {
    await _teardown();
    changeCycleState(StreamCycleState.disposed);
    super.dispose();
  }

  // todo add tests
  @visibleForTesting
  void debugSetState(StreamCycleState state, {Object? lastError}) {
    changeCycleState(state);
    _lastError = lastError;
    notifyListeners();
  }
}

class Whep extends StatefulWidget {
  final WhepController controller;
  final RTCVideoViewObjectFit objectFit;
  final int quarterTurns;

  const Whep({
    required this.controller,
    this.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    this.quarterTurns = 0,
    super.key,
  });

  @override
  State<Whep> createState() => _WhepState();
}

class _WhepState extends State<Whep> {
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
  void didUpdateWidget(Whep oldWidget) {
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
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    controller.setMounted(streamKey, context.mounted);

    final renderer = controller.renderer;

    late Widget streamView;

    if (renderer == null ||
        controller.cycleState != StreamCycleState.streaming) {
      streamView = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CustomLoadingIndicator(),
          const SizedBox(height: 10),
          const Text(
            'Negotiating WHEP stream...',
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      streamView = ValueListenableBuilder(
        valueListenable: renderer,
        builder: (context, _, _) {
          final hasSize = renderer.videoWidth > 0 && renderer.videoHeight > 0;
          final aspect = hasSize
              ? renderer.videoWidth / renderer.videoHeight
              : 4.0 / 3.0;
          Widget video = ExcludeSemantics(
            child: AspectRatio(
              aspectRatio: aspect,
              child: RTCVideoView(renderer, objectFit: widget.objectFit),
            ),
          );
          if (widget.quarterTurns != 0) {
            video = RotatedBox(quarterTurns: widget.quarterTurns, child: video);
          }
          return video;
        },
      );
    }

    return VisibilityDetector(
      key: streamKey,
      onVisibilityChanged: (VisibilityInfo info) {
        if (controller.isMounted(streamKey)) {
          controller.setVisible(streamKey, info.visibleFraction != 0);
        }
      },
      child: streamView,
    );
  }
}
