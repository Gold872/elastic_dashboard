import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:elastic_dashboard/services/log.dart';

class DSInteropClient {
  final String serverBaseAddress = '127.0.0.1';
  bool _serverConnectionActive = false;

  ValueNotifier<bool> connectionStatus = ValueNotifier(false);
  ValueNotifier<String?> ipNotifier = ValueNotifier(null);
  ValueNotifier<int?> dsHeightNotifier = ValueNotifier(null);

  WebSocketChannel? _socket;

  DSInteropClient() {
    _connect();
  }

  Future<void> _connect() async {
    if (_serverConnectionActive) {
      return;
    }
    return _dsSocketConnect();
  }

  Future<void> _dsSocketConnect() async {
    if (_serverConnectionActive) {
      return;
    }
    try {
      _socket = WebSocketChannel.connect(
        Uri.parse('ws://$serverBaseAddress:6768/ipws'),
      );
      await _socket!.ready;
    } catch (e) {
      _socket = null;
      logger.debug(
        'Failed to connect to Driver Station on Websocket port 6768, attempting to reconnect in 1 second.',
      );
      Future.delayed(const Duration(seconds: 1), _dsSocketConnect);
      return;
    }

    _socket!.stream.listen(
      (data) {
        if (!_serverConnectionActive) {
          logger.info('Driver Station connected on Websocket port 6768');
          _serverConnectionActive = true;
          connectionStatus.value = true;
        }
        if (data is String) {
          _dsSocketOnMessage(data);
        } else {
          logger.warning(
            '[DS INTEROP] Received data from Websocket 6768: "$data" with unknown type ${data.runtimeType}',
          );
        }
      },
      onDone: _dsSocketClose,
      onError: (err) {
        logger.error('DS Interop Error', err);
      },
    );
  }

  void _dsSocketOnMessage(String data) {
    logger.debug('Received data from Websocket 6768: "$data"');
    var jsonData = jsonDecode(data.toString());

    if (jsonData is! Map) {
      logger.warning('[DS INTEROP] Ignoring text message, not a Json Object');
      return;
    }

    if (jsonData.containsKey('robotIp')) {
      var rawIp = jsonData['robotIp'];
      if (rawIp is String) {
        if (rawIp != '0.0.0.0') {
          logger.info('Received robot IP from DS Interop: $rawIp');
          ipNotifier.value = rawIp;
        }
      } else {
        logger.warning(
          '[DS INTEROP] Invalid robotIP field type: ${rawIp.runtimeType}',
        );
      }
    }

    if (jsonData.containsKey('dockedHeight')) {
      var rawDockedHeight = jsonData['dockedHeight'];
      if (rawDockedHeight is int) {
        logger.info('Received docked height from DS Interop: $rawDockedHeight');
        dsHeightNotifier.value = rawDockedHeight > 0 ? rawDockedHeight : null;
      } else {
        logger.warning(
          '[DS INTEROP] Invalid dockedHeight field type: ${rawDockedHeight.runtimeType}',
        );
      }
    }
  }

  void _dsSocketClose() {
    if (!_serverConnectionActive) {
      return;
    }

    _socket?.sink.close(status.goingAway);
    _socket = null;

    _serverConnectionActive = false;

    dsHeightNotifier.value = null;
    connectionStatus.value = false;

    logger.info(
      'Driver Station connection on Websocket port 6768 closed, attempting to reconnect in 1 second.',
    );

    Future.delayed(const Duration(seconds: 1), _connect);
  }
}
