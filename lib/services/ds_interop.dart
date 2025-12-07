import 'dart:convert';
import 'dart:io';

import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/services/log.dart';

class DSInteropClient {
  final String serverBaseAddress = '127.0.0.1';
  bool _serverConnectionActive = false;

  Function()? onConnect;
  Function()? onDisconnect;

  Function(String ip)? onNewIPAnnounced;
  Function(bool isDocked)? onDriverStationDockChanged;

  Socket? _socket;

  String? _lastAnnouncedIP;
  bool _driverStationDocked = false;

  String? get lastAnnouncedIP => _lastAnnouncedIP;
  bool get driverStationDocked => _driverStationDocked;

  DSInteropClient({
    this.onNewIPAnnounced,
    this.onDriverStationDockChanged,
    this.onConnect,
    this.onDisconnect,
  }) {
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
          onConnect?.call();
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

    var dockedHeight = jsonData['dockedHeight'];
    if (dockedHeight != null) {
      logger.debug('[DS INTEROP] Received docked height: $dockedHeight');
      bool docked = dockedHeight > 0;
      if (docked != _driverStationDocked) {
        _driverStationDocked = docked;
        onDriverStationDockChanged?.call(docked);
      }
    }

    var rawIP = jsonData['robotIP'];

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

    if (_lastAnnouncedIP != ipAddress) {
      onNewIPAnnounced?.call(ipAddress);
    }
    _lastAnnouncedIP = ipAddress;
  }

  void _socketClose() {
    if (!_serverConnectionActive) {
      return;
    }

    _socket?.close();
    _socket = null;

    _serverConnectionActive = false;

    _driverStationDocked = false;
    onDriverStationDockChanged?.call(false);
    onDisconnect?.call();

    logger.info(
      'Driver Station connection on TCP port 1742 closed, attempting to reconnect in 5 seconds.',
    );

    Future.delayed(const Duration(seconds: 5), _connect);
  }
}
