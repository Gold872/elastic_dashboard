import 'package:flutter/foundation.dart';

import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/services/log.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

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

  void _connect() {
    if (_serverConnectionActive) {
      return;
    }
    _tcpSocketConnect();
  }

  void _tcpSocketConnect() async {
    if (_serverConnectionActive) {
      return;
    }
    try {
      _socket = WebSocketChannel.connect(Uri.parse('ws://$serverBaseAddress:6768/ipws'));
      await _socket!.ready;
    } catch (e) {
      _socket = null;
      logger.debug(
        'Failed to connect to Driver Station on Websocket port 6768, attempting to reconnect in 5 seconds.',
      );
      Future.delayed(const Duration(seconds: 5), _tcpSocketConnect);
      return;
    }

    _socket!.stream.listen(
      (data) {
        if (!_serverConnectionActive) {
          logger.info('Driver Station connected on Websocket port 6768');
          _serverConnectionActive = true;
          connectionStatus.value = true;
        }
        if (data is Uint8List) {
          _tcpSocketOnMessage(data);
        } else {
          logger.warning('[DS INTEROP] Received data from Websocket 6768: "$data" with unknown type ${data.runtimeType}');
        }
      },
      onDone: _socketClose,
      onError: (err) {
        logger.error('DS Interop Error', err);
      },
    );
  }

  void _tcpSocketOnMessage(Uint8List data) {
    logger.debug('Received data from Websocket 6768: "$data"');
    var blob = ByteData.sublistView(data);

    var tag = blob.getUint8(2);
    if (tag == 50) {
      var rawIP = blob.getUint32(3, Endian.big);
      if (rawIP == 0) {
        return;
      }
      String ipAddress = IPAddressUtil.getIpFromInt32Value(rawIP);
      logger.info('Received IP Address from Driver Station: $ipAddress');
      ipNotifier.value = ipAddress;
    }
    else if (tag == 51) {
      var dockedHeight = blob.getUint32(3, Endian.big);
      logger.debug('[DS INTEROP] Received docked height: $dockedHeight');
      dsHeightNotifier.value = dockedHeight > 0 ? dockedHeight : null;
    } else {
      logger.warning('[DS INTEROP] Received d1ata with unknown tag: $tag');
    }
  }

  void _socketClose() {
    if (!_serverConnectionActive) {
      return;
    }

    _socket?.sink.close(status.goingAway);
    _socket = null;

    _serverConnectionActive = false;

    dsHeightNotifier.value = null;
    connectionStatus.value = false;

    logger.info(
      'Driver Station connection on Websocket port 6768 closed, attempting to reconnect in 5 seconds.',
    );

    Future.delayed(const Duration(seconds: 5), _connect);
  }
}
