import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:dot_cast/dot_cast.dart';

import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/services/log.dart';

class DSInteropClient {
  final String serverBaseAddress = '127.0.0.1';
  bool _serverConnectionActive = false;

  ValueNotifier<bool> connectionStatus = ValueNotifier(false);
  ValueNotifier<String?> ipNotifier = ValueNotifier(null);
  ValueNotifier<int?> dsHeightNotifier = ValueNotifier(null);

  Socket? _socket;

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
      _socket = await Socket.connect(serverBaseAddress, 1742);
    } catch (e) {
      logger.debug(
        'Failed to connect to Driver Station on port 1742, attempting to reconnect in 5 seconds.',
      );
      Future.delayed(const Duration(seconds: 5), _tcpSocketConnect);
      return;
    }

    _socket!.listen(
      (data) {
        if (!_serverConnectionActive) {
          logger.info('Driver Station connected on TCP port 1742');
          _serverConnectionActive = true;
          connectionStatus.value = true;
        }
        _tcpSocketOnMessage(utf8.decode(data));
      },
      onDone: _socketClose,
      onError: (err) {
        logger.error('DS Interop Error', err);
      },
    );
  }

  void _tcpSocketOnMessage(String data) {
    logger.debug('Received data from TCP 1742: "$data"');
    var jsonData = jsonDecode(data.toString());

    if (jsonData is! Map) {
      logger.warning('[DS INTEROP] Ignoring text message, not a Json Object');
      return;
    }

    int? dockedHeight = tryCast(jsonData['dockedHeight']);
    if (dockedHeight != null) {
      logger.debug('[DS INTEROP] Received docked height: $dockedHeight');
      dsHeightNotifier.value = dockedHeight > 0 ? dockedHeight : null;
    }

    int? rawIP = tryCast(jsonData['robotIP']);
    if (rawIP == null) {
      logger.warning(
        '[DS INTEROP] Ignoring Json message, robot IP is not valid',
      );
      return;
    }

    if (rawIP == 0) {
      return;
    }

    String ipAddress = IPAddressUtil.getIpFromInt32Value(rawIP);

    logger.info('Received IP Address from Driver Station: $ipAddress');

    ipNotifier.value = ipAddress;
  }

  void _socketClose() {
    if (!_serverConnectionActive) {
      return;
    }

    _socket?.close();
    _socket = null;

    _serverConnectionActive = false;

    dsHeightNotifier.value = null;
    connectionStatus.value = false;

    logger.info(
      'Driver Station connection on TCP port 1742 closed, attempting to reconnect in 5 seconds.',
    );

    Future.delayed(const Duration(seconds: 5), _connect);
  }
}
