import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

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

  Timer? _reconnectTimer;
  int _retryCount = 0;

  int _lastBytesReceived = 0;
  DateTime? _lastStatsAt;

  WhepController({
    required super.streams,
    super.timeout = const Duration(seconds: 5),
    super.headers = const {},
  });

  RTCVideoRenderer? get renderer => _renderer;

  Future<void> ensureStarted() async {
    if (cycleState == StreamCycleState.disposed) return;
    if (_pc != null || _connecting) return;
    if (streams.isEmpty) return;

    _connecting = true;
    changeCycleState(StreamCycleState.connecting);
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
          changeCycleState(StreamCycleState.failed);
          _lastError ??= Exception('Peer connection $s');
          notifyListeners();
          _scheduleReconnect();
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

      changeCycleState(StreamCycleState.streaming);
      _lastError = null;
      _retryCount = 0;
      startMetricsTimer();
      notifyListeners();
    } catch (error, stack) {
      logger.error('WHEP connection failed for $currentStream', error, stack);
      _lastError = error;
      changeCycleState(StreamCycleState.failed);
      await _teardown();
      notifyListeners();
      _scheduleReconnect();
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
      const Duration(seconds: 2),
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

  void _scheduleReconnect() {
    if (cycleState == StreamCycleState.disposed) return;
    _reconnectTimer?.cancel();
    _retryCount++;
    _switchToNextStream();
    const delay = Duration(milliseconds: 500);
    logger.info(
      'WebRTC reconnection attempt in ${delay.inMilliseconds}ms for $currentStream (attempt $_retryCount)',
    );
    _reconnectTimer = Timer(delay, () {
      if (cycleState == StreamCycleState.disposed) return;
      unawaited(_restart());
    });
  }

  Future<void> _restart() async {
    await _teardown();
    if (cycleState == StreamCycleState.disposed) return;
    changeCycleState(StreamCycleState.idle);
    notifyListeners();
    await ensureStarted();
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
  void dispose() {
    changeCycleState(StreamCycleState.disposed);
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    unawaited(_teardown());
    super.dispose();
  }

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
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
    unawaited(widget.controller.ensureStarted());
  }

  @override
  void didUpdateWidget(covariant Whep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onUpdate);
      widget.controller.addListener(_onUpdate);
      unawaited(widget.controller.ensureStarted());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final renderer = controller.renderer;

    if (renderer == null ||
        controller.cycleState != StreamCycleState.streaming) {
      final errText = controller.lastError?.toString();
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CustomLoadingIndicator(),
          const SizedBox(height: 10),
          Text(
            controller.cycleState == StreamCycleState.failed
                ? (kDebugMode && errText != null
                      ? 'WHEP error: $errText\nReconnecting...'
                      : 'WHEP connection lost. Reconnecting...')
                : 'Negotiating WHEP stream...',
            textAlign: TextAlign.center,
            style: controller.cycleState == StreamCycleState.failed
                ? const TextStyle(color: Colors.red)
                : null,
          ),
        ],
      );
    }

    return ValueListenableBuilder(
      valueListenable: renderer,
      builder: (context, _, _) {
        final hasSize = renderer.videoWidth > 0 && renderer.videoHeight > 0;
        final aspect = hasSize
            ? renderer.videoWidth / renderer.videoHeight
            : 16.0 / 9.0;
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
}
