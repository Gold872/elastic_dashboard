import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:elastic_dashboard/services/ip_address_util.dart';
import 'package:elastic_dashboard/services/log.dart';

class DSInteropClient {
  final String serverBaseAddress = '127.0.0.1';
  bool _serverConnectionActive = false;
  bool _dbModeServerRunning = false;

  Function()? onConnect;
  Function()? onDisconnect;

  Function(String ip)? onNewIPAnnounced;
  Function(bool isDocked)? onDriverStationDockChanged;

  Socket? _socket;
  ServerSocket? _dbModeServer;

  final List<Socket> _connectedSockets = [];

  List<int> _tcpBuffer = [];

  String? _lastAnnouncedIP;
  bool _driverStationDocked = false;

  String? get lastAnnouncedIP => _lastAnnouncedIP;
  bool get driverStationDocked => _driverStationDocked;

  bool _attemptServerStart = true;

  DateTime serverStopTime = DateTime.now();

  DSInteropClient({
    this.onNewIPAnnounced,
    this.onDriverStationDockChanged,
    this.onConnect,
    this.onDisconnect,
  }) {
    _tcpSocketConnect();
  }

  void startDBModeServer() {
    // For some reason if the server is quickly stopped then started there's a 5 second delay
    // The workaround is to use the cached value of the docked state
    if (DateTime.now().microsecondsSinceEpoch -
            serverStopTime.microsecondsSinceEpoch <=
        5 * 1e6) {
      onDriverStationDockChanged?.call(_driverStationDocked);
    }
    _tcpSocketConnect();

    if (!kIsWeb) {
      _attemptServerStart = true;
      _startDBModeServer();
    }
  }

  void stopDBModeServer() {
    serverStopTime = DateTime.now();
    _dbModeServerClose(false);
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

  Future<void> _startDBModeServer() async {
    if (_dbModeServerRunning || !_attemptServerStart) {
      return;
    }
    try {
      _dbModeServer = await ServerSocket.bind(serverBaseAddress, 1741);
    } catch (e) {
      if (_attemptServerStart) {
        logger.info(
          'Failed to start TCP server on port 1741, attempting to restart in 5 seconds',
        );
        Future.delayed(const Duration(seconds: 5), _startDBModeServer);
      } else {
        logger.info('Failed to start TCP server on port 1741');
      }
      return;
    }

    _attemptServerStart = false;
    _dbModeServerRunning = true;

    _dbModeServer!.listen(
      (socket) {
        logger.info('Received connection from Driver Station on TCP port 1741');
        _connectedSockets.add(socket);
        socket.listen(
          (data) {
            _dbModeServerOnMessage(data);
          },
          onDone: () {
            _connectedSockets.remove(socket);
            logger.info('Lost connection from Driver Station on TCP port 1741');
          },
        );
      },
      onDone: _dbModeServerClose,
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

  void _dbModeServerOnMessage(Uint8List data) {
    logger.trace('Received message from socket on TCP 1741: $data');
    _tcpBuffer.addAll(data);
    Map<int, Uint8List> mappedData = {};

    int sublistIndex = 0;

    for (int i = 0; i < _tcpBuffer.length - 1;) {
      int size = (_tcpBuffer[i] << 8) | _tcpBuffer[i + 1];

      if (i >= _tcpBuffer.length - 1 - size || size == 0) {
        break;
      }

      Uint8List sublist = Uint8List.fromList(
        _tcpBuffer.sublist(i + 2, i + 2 + size),
      );
      int tagID = sublist[0];
      mappedData[tagID] = sublist.sublist(1);

      sublistIndex = i + size + 2;

      i += size + 2;
    }

    _tcpBuffer = _tcpBuffer.sublist(sublistIndex);

    if (mappedData.containsKey(0x09)) {
      bool docked = (mappedData[0x09]![0] & 0x04 != 0);
      _driverStationDocked = docked;

      onDriverStationDockChanged?.call(docked);
    }
  }

  void _socketClose() async {
    if (!_serverConnectionActive) {
      return;
    }

    await _socket?.close();
    _socket = null;

    _serverConnectionActive = false;

    onDisconnect?.call();

    logger.info(
      'Driver Station connection on TCP port 1742 closed, attempting to reconnect in 5 seconds.',
    );

    Future.delayed(const Duration(seconds: 5), _tcpSocketConnect);
  }

  void _dbModeServerClose([bool reconnect = true]) async {
    if (!_dbModeServerRunning) {
      return;
    }

    _dbModeServerRunning = false;

    // Cloning the list because closing each socket changes the size of the list
    for (Socket socket in _connectedSockets.toList()) {
      await socket.close();
      socket.destroy();
    }

    await _dbModeServer?.close();
    _dbModeServer = null;

    onDriverStationDockChanged?.call(false);

    _tcpBuffer.clear();

    _attemptServerStart = reconnect;

    if (reconnect) {
      logger.info(
        'Driver Station TCP Server on Port 1741 closed, attempting to reconnect in 5 seconds.',
      );

      Future.delayed(const Duration(seconds: 5), _startDBModeServer);
    } else {
      logger.info('Driver Station TCP Server on Port 1741 closed');
    }
  }
}
