// Written by Michael Jansen from Team 3015, Ranger Robotics
// Additional inspiration taken from Jonah from Team 6328, Mechanical Advantage

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:collection/collection.dart';
import 'package:dot_cast/dot_cast.dart';
import 'package:msgpack_dart/msgpack_dart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/struct_schemas/nt_struct.dart';

class NT4Subscription extends ValueNotifier<Object?> {
  final String topic;
  final NT4SubscriptionOptions options;
  final int uid;

  Object? currentValue;
  int timestamp = 0;

  final List<Function(Object?, int)> _listeners = [];

  NT4Subscription({
    required this.topic,
    this.options = const NT4SubscriptionOptions(),
    this.uid = -1,
  }) : super(null);

  @override
  String toString() =>
      'NT4Subscription(Topic: $topic, Options: $options, Uid: $uid)';

  void listen(Function(Object?, int) onChanged) {
    _listeners.add(onChanged);
    onChanged(value, timestamp);
  }

  Stream<Object?> periodicStream({bool yieldAll = true}) async* {
    final Duration delayTime = Duration(
      microseconds: (options.periodicRateSeconds * 1e6).round(),
    );

    yield currentValue;
    Object? lastYielded = currentValue;

    while (true) {
      await Future.delayed(delayTime);

      if (lastYielded != currentValue || yieldAll) {
        yield currentValue;
        lastYielded = currentValue;
      }
    }
  }

  Stream<({Object? value, DateTime timestamp})> timestampedStream({
    bool yieldAll = false,
  }) async* {
    yield (
      value: currentValue,
      timestamp: DateTime.fromMicrosecondsSinceEpoch(timestamp),
    );

    int lastTimestamp = timestamp;
    int fakeTimestamp = timestamp;

    while (true) {
      await Future.delayed(
        Duration(microseconds: (options.periodicRateSeconds * 1e6).round()),
      );

      if (lastTimestamp != timestamp || yieldAll) {
        yield (
          value: currentValue,
          timestamp: DateTime.fromMicrosecondsSinceEpoch(timestamp),
        );
        lastTimestamp = timestamp;
        fakeTimestamp = timestamp;
      } else if (yieldAll) {
        fakeTimestamp += (options.periodicRateSeconds * 1e6).round();
        yield (
          value: currentValue,
          timestamp: DateTime.fromMicrosecondsSinceEpoch(fakeTimestamp),
        );
      }
    }
  }

  void updateValue(Object? value, int timestamp) {
    logger.trace(
      'Updating value for subscription: $this - Value: $value, Time: $timestamp',
    );

    if (options.structMeta != null &&
        value is List<int> &&
        options.structMeta!.schema != null) {
      NTStructSchema schema = options.structMeta!.schema!;
      List<String> path = options.structMeta!.path;
      NTStruct struct = NTStruct.parse(
        schema: schema,
        data: Uint8List.fromList(value),
      );
      Object? fieldValue = struct.get(path);
      // Should only be displaying/subscribing to data types in structs
      if (fieldValue is NTStruct) {
        fieldValue = null;
      }
      value = fieldValue;
    }

    for (var listener in _listeners) {
      listener(value, timestamp);
    }
    currentValue = value;
    this.timestamp = timestamp;
    super.value = value;
  }

  Map<String, dynamic> _toSubscribeJson() => {
    'topics': [topic],
    'options': options.toJson(),
    'subuid': uid,
  };

  Map<String, dynamic> _toUnsubscribeJson() => {'subuid': uid};

  @override
  bool operator ==(Object other) =>
      other is NT4Subscription &&
      other.runtimeType == runtimeType &&
      other.topic == topic &&
      other.options == options;

  @override
  int get hashCode => Object.hashAll([topic, options]);
}

class NT4StructMeta {
  final List<String> path;
  final String schemaName;

  NT4Type? _type;

  NT4Type? get type {
    if (schema == null) {
      return _type;
    }

    if (path.isEmpty) {
      return NT4Type.struct(schema!.name);
    }

    NTStructSchema currentSchema = schema!;
    List<String> pathStack = List.from(path.reversed);

    while (pathStack.isNotEmpty) {
      String fieldName = pathStack.removeLast();
      NTFieldSchema? field = currentSchema[fieldName];

      if (field == null) {
        return NT4Type.struct(currentSchema.name);
      }

      if (field.subSchema == null || pathStack.isEmpty) {
        return field.ntType;
      }

      currentSchema = field.subSchema!;
    }

    return NT4Type.struct(currentSchema.name);
  }

  NTStructSchema? schema;

  NT4StructMeta({
    required this.path,
    required this.schemaName,
    this.schema,
    NT4Type? type,
  }) {
    if (type != null) {
      _type = type;
    }
  }

  NT4StructMeta copyWith({List<String>? path, String? schemaName}) =>
      NT4StructMeta(
        path: path ?? this.path,
        schemaName: schemaName ?? this.schemaName,
      );

  factory NT4StructMeta.fromJson(Map<String, dynamic> json) {
    List<String> path =
        tryCast<List<dynamic>>(json['path'])?.whereType<String>().toList() ??
        [];

    NT4Type? type;
    if (json.containsKey('type')) {
      type = NT4Type.parse(tryCast<String>(json['type']) ?? '');
    }

    return NT4StructMeta(
      path: path,
      schemaName: tryCast(json['schema_name']) ?? '',
      type: type,
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'schema_name': schemaName,
    if (type != null) 'type': type!.serialize(),
  };

  @override
  String toString() =>
      'NT4StructMeta(Path: $path, Schema Name: $schemaName, Type: $type)';

  @override
  bool operator ==(Object other) =>
      other is NT4StructMeta &&
      path.equals(other.path) &&
      schemaName == other.schemaName;

  @override
  int get hashCode => Object.hashAll([schemaName, path]);
}

class NT4SubscriptionOptions {
  final double periodicRateSeconds;
  final bool all;
  final bool topicsOnly;
  final bool prefix;
  final NT4StructMeta? structMeta;

  const NT4SubscriptionOptions({
    this.periodicRateSeconds = 0.1,
    this.all = false,
    this.topicsOnly = false,
    this.prefix = true,
    this.structMeta,
  });

  Map<String, dynamic> toJson() => {
    'periodic': periodicRateSeconds,
    'all': all,
    'topicsonly': topicsOnly,
    'prefix': prefix,
  };

  @override
  bool operator ==(Object other) =>
      other is NT4SubscriptionOptions &&
      other.runtimeType == runtimeType &&
      other.periodicRateSeconds == periodicRateSeconds &&
      other.all == all &&
      other.topicsOnly == topicsOnly &&
      other.prefix == prefix &&
      other.structMeta == structMeta;

  @override
  int get hashCode => Object.hashAll([
    periodicRateSeconds,
    all,
    topicsOnly,
    prefix,
    structMeta,
  ]);

  @override
  String toString() =>
      'NT4SubscriptionOptions(Periodic: $periodicRateSeconds, All: $all, TopicsOnly: $topicsOnly, Prefix: $prefix, Struct Meta: $structMeta)';
}

class NT4Topic {
  final String name;
  final NT4Type type;
  int id;
  int pubUID;
  final Map<String, dynamic> properties;

  NT4Topic({
    required this.name,
    required this.type,
    this.id = 0,
    this.pubUID = 0,
    required this.properties,
  });

  @override
  String toString() =>
      'NT4Topic(Name: $name, Type: $type, ID: $id, PubUID: $pubUID, Properties: $properties)';

  Map<String, dynamic> toPublishJson() => {
    'name': name,
    'type': type.serialize(),
    'pubuid': pubUID,
  };

  Map<String, dynamic> toUnpublishJson() => {'name': name, 'pubuid': pubUID};

  Map<String, dynamic> toPropertiesJson() => {
    'name': name,
    'update': properties,
  };

  int getTypeId() => type.typeId;

  bool get isRetained =>
      properties.containsKey('retained') && properties['retained'];

  bool get isPersistent =>
      properties.containsKey('persistent') && properties['persistent'];
}

class NT4Client {
  static const int _pingIntervalMsV40 = 1000;
  static const int _pingIntervalMsV41 = 200;

  static const int _pingTimeoutMsV40 = 5000;
  static const int _pingTimeoutMsV41 = 1000;

  String serverBaseAddress;
  int serverPort;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;
  final List<Function(NT4Topic topic)> _topicAnnounceListeners = [];
  final List<Function(NT4Topic topic)> _topicUnannounceListeners = [];

  final SchemaManager schemaManager;

  final Map<int, NT4Subscription> _subscriptions = {};
  final Set<NT4Subscription> _subscribedTopics = {};
  int _subscriptionUIDCounter = 0;
  int _publishUIDCounter = 0;
  final Map<String, Object?> lastAnnouncedValues = {};
  final Map<String, int> lastAnnouncedTimestamps = {};
  final Map<String, NT4Topic> _clientPublishedTopics = {};
  final Map<int, NT4Topic> announcedTopics = {};
  int _clientId = 0;
  int _serverTimeOffsetUS = 0;
  double _latencyMs = 0;

  WebSocketChannel? _mainWebsocket;
  StreamSubscription? _mainWebsocketListener;
  WebSocketChannel? _rttWebsocket;
  StreamSubscription? _rttWebsocketListener;

  Timer? _connectionTimer;

  Timer? _pingTimer;
  Timer? _pongTimer;

  int _pingInterval = _pingIntervalMsV40;
  int _timeoutInterval = _pingTimeoutMsV40;

  bool _serverConnectionActive = false;
  bool _rttConnectionActive = false;

  bool get mainWebsocketActive =>
      _mainWebsocket != null && _mainWebsocket!.closeCode == null;
  bool get rttWebsocketActive =>
      _rttWebsocket != null && _rttWebsocket!.closeCode == null;

  bool _useRTT = false;
  bool _attemptConnection = true;
  bool _attemptingNTConnection = false;
  bool _attemptingRTTConnection = false;

  int _lastPongTime = 0;

  Map<int, NT4Subscription> get subscriptions => _subscriptions;
  Set<NT4Subscription> get subscribedTopics => _subscribedTopics;
  List<Function(NT4Topic topic)> get topicAnnounceListeners =>
      _topicAnnounceListeners;

  NT4Client({
    required this.serverBaseAddress,
    this.serverPort = 5810,
    required this.schemaManager,
    this.onConnect,
    this.onDisconnect,
  }) {
    Future.delayed(const Duration(seconds: 1, milliseconds: 500), () {
      _connect();

      _connectionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _connect();
        _rttConnect();
      });
    });
  }

  @visibleForTesting
  void cancelConnectionTimer() {
    _connectionTimer?.cancel();
  }

  Future<void> setServerBaseAddreess(String serverBaseAddress) async {
    this.serverBaseAddress = serverBaseAddress;
    await _wsOnClose();
    // IP address is changed, so we're "resetting" the attempt state
    // In the connect method, we don't change the attempting state if
    // the address changes during connection, so this will have no effect
    // on existing connections
    _attemptingNTConnection = false;
    _attemptingRTTConnection = false;
    Future.delayed(const Duration(milliseconds: 100), _connect);
  }

  Future<void> setServerPort(int serverPort) async {
    this.serverPort = serverPort;
    await _wsOnClose();
    // Port is changed, so we're "resetting" the attempt state
    // In the connect method, we don't change the attempting state if
    // the address changes during connection, so this will have no effect
    // on existing connections
    _attemptingNTConnection = false;
    _attemptingRTTConnection = false;
    Future.delayed(const Duration(milliseconds: 100), _connect);
  }

  Stream<double> latencyStream() async* {
    yield _latencyMs;

    double lastYielded = _latencyMs;

    while (true) {
      await Future.delayed(const Duration(seconds: 1));

      if (_latencyMs != lastYielded) {
        yield _latencyMs;
        lastYielded = _latencyMs;
      }
    }
  }

  void addTopicAnnounceListener(Function(NT4Topic topic) onAnnounce) {
    _topicAnnounceListeners.add(onAnnounce);

    for (NT4Topic topic in announcedTopics.values) {
      onAnnounce(topic);
    }
  }

  void removeTopicAnnounceListener(Function(NT4Topic topic) onAnnounce) {
    _topicAnnounceListeners.remove(onAnnounce);
  }

  void addTopicUnannounceListener(Function(NT4Topic topic) onUnannounce) {
    _topicUnannounceListeners.add(onUnannounce);
  }

  void removeTopicUnannounceListener(Function(NT4Topic topic) onUnannounce) {
    _topicUnannounceListeners.add(onUnannounce);
  }

  NT4Subscription subscribe({
    required String topic,
    NT4SubscriptionOptions options = const NT4SubscriptionOptions(),
  }) {
    NT4Subscription newSub = NT4Subscription(
      topic: topic,
      uid: getNewSubUID(),
      options: options,
    );

    logger.trace('Creating new subscription: $newSub');

    _subscriptions[newSub.uid] = newSub;
    _subscribedTopics.add(newSub);
    _wsSubscribe(newSub);

    if (lastAnnouncedValues.containsKey(topic) &&
        lastAnnouncedTimestamps.containsKey(topic)) {
      newSub.updateValue(
        lastAnnouncedValues[topic],
        lastAnnouncedTimestamps[topic]!,
      );
    }

    return newSub;
  }

  void unSubscribe(NT4Subscription sub) {
    logger.trace('Unsubscribing: $sub');
    _subscriptions.remove(sub.uid);
    _subscribedTopics.remove(sub);
    _wsUnsubscribe(sub);

    // If there are no other subscriptions that are in the same table/tree
    if (!_subscribedTopics.any(
      (element) =>
          element.topic.isNotEmpty &&
          (element.topic.startsWith('${sub.topic}/') ||
              sub.topic.startsWith('${element.topic}/') ||
              sub.topic == element.topic),
    )) {
      // If there are any topics associated with the table/tree, unpublish them
      for (NT4Topic topic in _clientPublishedTopics.values.where(
        (element) =>
            element.name.startsWith('${sub.topic}/') ||
            sub.topic.startsWith('${element.name}/') ||
            sub.topic == element.name,
      )) {
        Future(() => unpublishTopic(topic));
      }
    }
  }

  void clearAllSubscriptions() {
    for (NT4Subscription sub in _subscriptions.values) {
      unSubscribe(sub);
    }
    _subscriptions.clear();
  }

  void setProperties(NT4Topic topic, bool isPersistent, bool isRetained) {
    logger.trace(
      'Updating properties - Topic: $topic, Persistent: $isPersistent, Retained: $isRetained',
    );
    topic.properties['persistent'] = isPersistent;
    topic.properties['retained'] = isRetained;
    _wsSetProperties(topic);
  }

  NT4Topic? getTopicFromName(String topic) =>
      announcedTopics.values.firstWhereOrNull((e) => e.name == topic);

  bool isTopicPublished(NT4Topic? topic) =>
      _clientPublishedTopics.containsValue(topic);

  NT4Topic publishNewTopic(
    String name,
    NT4Type type, [
    Map<String, dynamic> properties = const {},
  ]) {
    NT4Topic newTopic = NT4Topic(
      name: name,
      type: type,
      properties: properties,
    );
    publishTopic(newTopic);
    return newTopic;
  }

  void publishTopic(NT4Topic topic) {
    if (_clientPublishedTopics.containsKey(topic.name)) {
      NT4Topic existing = _clientPublishedTopics[topic.name]!;
      topic.pubUID = existing.pubUID;
      existing.properties.addAll(topic.properties);
      _wsSetProperties(existing);
      return;
    }
    logger.trace('Publishing topic: $topic');

    topic.pubUID = getNewPubUID();
    _clientPublishedTopics[topic.name] = topic;
    _wsPublish(topic);
    _wsSetProperties(topic);
  }

  void unpublishTopic(NT4Topic topic) {
    logger.trace('Unpublishing topic: $topic');
    _clientPublishedTopics.remove(topic.name);
    _wsUnpublish(topic);
  }

  void addSample(NT4Topic topic, dynamic data, [int? timestamp]) {
    // Publishing to struct topics is not supported
    if (topic.type.isStruct) return;

    timestamp ??= getServerTimeUS();

    logger.trace(
      'Adding sample - Topic: $topic, Data: $data, Timestamp: $timestamp',
    );

    _wsSendBinary(
      serialize([topic.pubUID, timestamp, topic.getTypeId(), data]),
    );

    lastAnnouncedValues[topic.name] = data;
    lastAnnouncedTimestamps[topic.name] = timestamp;
    for (NT4Subscription sub in _subscriptions.values) {
      if (sub.topic == topic.name) {
        sub.updateValue(data, timestamp);
      }
    }
  }

  void addSampleFromName(String topic, dynamic data, [int? timestamp]) {
    for (NT4Topic t in announcedTopics.values) {
      if (t.name == topic) {
        addSample(t, data, timestamp);
        return;
      }
    }
    logger.debug('[NT4] Topic not found: $topic');
  }

  int _getClientTimeUS() => DateTime.now().microsecondsSinceEpoch;

  int getServerTimeUS() => _getClientTimeUS() + _serverTimeOffsetUS;

  void _rttSendTimestamp([dynamic _]) {
    var timeTopic = announcedTopics[-1];
    if (timeTopic != null) {
      int timeToSend = _getClientTimeUS();

      var rttValue = [timeTopic.pubUID, 0, timeTopic.getTypeId(), timeToSend];
      var rawData = serialize(rttValue);

      logger.trace('Sending RTT timestamp: $rttValue');

      if (_useRTT) {
        if (rttWebsocketActive && mainWebsocketActive) {
          _rttWebsocket?.sink.add(rawData);
        }
      } else if (mainWebsocketActive) {
        _mainWebsocket?.sink.add(rawData);
      }
    }
  }

  void _rttHandleRecieveTimestamp(int serverTimestamp, int clientTimestamp) {
    logger.trace(
      'RTT Received - Server Time: $serverTimestamp, Client Time: $clientTimestamp',
    );
    int rxTime = _getClientTimeUS();

    int rtt = rxTime - clientTimestamp;
    int serverTimeAtRx = serverTimestamp + rtt ~/ 2;
    _serverTimeOffsetUS = serverTimeAtRx - rxTime;

    _lastPongTime = rxTime;

    _latencyMs = (rtt / 2) / 1000;
  }

  void _wsSubscribe(NT4Subscription sub) {
    _wsSendJSON('subscribe', sub._toSubscribeJson());
  }

  void _wsUnsubscribe(NT4Subscription sub) {
    _wsSendJSON('unsubscribe', sub._toUnsubscribeJson());
  }

  void _wsPublish(NT4Topic topic) {
    _wsSendJSON('publish', topic.toPublishJson());
  }

  void _wsUnpublish(NT4Topic topic) {
    _wsSendJSON('unpublish', topic.toUnpublishJson());
  }

  void _wsSetProperties(NT4Topic topic) {
    _wsSendJSON('setproperties', topic.toPropertiesJson());
  }

  void _wsSendJSON(String method, Map<String, dynamic> params) {
    if (!mainWebsocketActive) {
      return;
    }

    _mainWebsocket?.sink.add(
      jsonEncode([
        {'method': method, 'params': params},
      ]),
    );
  }

  void _wsSendBinary(dynamic data) {
    if (!mainWebsocketActive) {
      return;
    }

    _mainWebsocket?.sink.add(data);
  }

  Future<void> _connect() async {
    if (_mainWebsocket != null ||
        !_attemptConnection ||
        _attemptingNTConnection) {
      logger.trace(
        'Ignoring connection attempt; Connection Active: ${_mainWebsocket != null}, Should Attempt Connection: $_attemptConnection, Currently Attempting: $_attemptingNTConnection',
      );
      return;
    }

    logger.trace('Beginning connection attempt');

    _attemptingNTConnection = true;

    _clientId = Random().nextInt(99999999);

    String mainServerAddr = 'ws://$serverBaseAddress:$serverPort/nt/Elastic';

    WebSocketChannel connectionAttempt;
    try {
      connectionAttempt = WebSocketChannel.connect(
        Uri.parse(mainServerAddr),
        protocols: [
          'networktables.first.wpi.edu',
          'v4.1.networktables.first.wpi.edu',
        ],
      );
      logger.trace('Awaiting connection ready');
      await connectionAttempt.ready;
    } catch (e) {
      // Failed to connect... try again

      // When changing IP addresses we ignore any current connection attempts
      // since the handshake can take a long time, this will avoid logging information
      // that is from an old connection attempt
      if (mainServerAddr.contains(serverBaseAddress) &&
          mainServerAddr.contains(serverPort.toString())) {
        logger.info(
          'Failed to connect to network tables, attempting to reconnect in 500 ms',
        );

        _attemptingNTConnection = false;
      }
      // The attempt state does not get set to false if the ip address changed while
      // connecting, since changing the ip address resets the connection attempt state

      logger.trace('Connection failed with error', e);
      return;
    }
    if (!mainServerAddr.contains(serverBaseAddress) ||
        !mainServerAddr.contains(serverPort.toString())) {
      logger.info(
        'IP Address/Port changed while connecting, aborting connection',
      );

      // We don't set attempting connection to false here since we're assuming
      // that when the address changes, it will "reset" the attempt state to
      // only work for the new address

      connectionAttempt.sink.close().ignore();
      return;
    }

    _mainWebsocket = connectionAttempt;
    _attemptingNTConnection = false;

    _pingTimer?.cancel();
    _pongTimer?.cancel();

    if (_mainWebsocket!.protocol == 'v4.1.networktables.first.wpi.edu') {
      _useRTT = true;
      _pingInterval = _pingIntervalMsV41;
      _timeoutInterval = _pingTimeoutMsV41;
    } else {
      _useRTT = false;
      _pingInterval = _pingIntervalMsV40;
      _timeoutInterval = _pingTimeoutMsV40;
    }

    _mainWebsocketListener = _mainWebsocket!.stream.listen(
      (data) {
        // Prevents repeated calls to onConnect and reconnecting after changing ip addresses
        if (!_serverConnectionActive &&
            mainServerAddr.contains(serverBaseAddress)) {
          _onFirstMessageReceived();
        }
        _wsOnMessage(data);
      },
      onDone: _wsOnClose,
      onError: (err) {
        logger.error('NT4 Error', err);
      },
      cancelOnError: true,
    );

    NT4Topic timeTopic = NT4Topic(
      name: 'Time',
      type: NT4Type.int(),
      id: -1,
      pubUID: -1,
      properties: {},
    );
    announcedTopics[timeTopic.id] = timeTopic;

    _lastPongTime = 0;
    _rttSendTimestamp();

    _pingTimer = Timer.periodic(
      Duration(milliseconds: _pingInterval),
      _rttSendTimestamp,
    );
    _pongTimer = Timer.periodic(
      Duration(milliseconds: _pingInterval),
      _checkPingStatus,
    );

    for (NT4Topic topic in _clientPublishedTopics.values) {
      _wsPublish(topic);
      _wsSetProperties(topic);
    }

    for (NT4Subscription sub in _subscriptions.values) {
      _wsSubscribe(sub);
    }
  }

  Future<void> _rttConnect() async {
    if (!_useRTT ||
        _rttWebsocket != null ||
        _rttConnectionActive ||
        _attemptingRTTConnection) {
      return;
    }
    _attemptingRTTConnection = true;

    String rttServerAddr = 'ws://$serverBaseAddress:$serverPort/nt/Elastic';

    Uri? rttUri = Uri.tryParse(rttServerAddr);

    if (rttUri == null) {
      logger.info('Aborting RTT connection attempt, URI is not valid');
      _attemptingRTTConnection = false;
      return;
    }

    WebSocketChannel connectionAttempt;
    try {
      connectionAttempt = WebSocketChannel.connect(
        Uri.parse(rttServerAddr),
        protocols: ['rtt.networktables.first.wpi.edu'],
      );
      await connectionAttempt.ready;
    } catch (e) {
      logger.info(
        'Failed to connect to RTT Network Tables protocol, attempting to reconnect in 500 ms',
      );
      // Only reset connection attempt if the address hasn't changed, see explanation above
      if (rttServerAddr.contains(serverBaseAddress) &&
          rttServerAddr.contains(serverPort.toString())) {
        _attemptingRTTConnection = false;
      }
      return;
    }
    if (!rttServerAddr.contains(serverBaseAddress) ||
        !rttServerAddr.contains(serverPort.toString())) {
      logger.info(
        'IP Addressed/Port changed while connecting to RTT, aborting RTT connection',
      );
      connectionAttempt.sink.close().ignore();
      return;
    }

    _rttWebsocket = connectionAttempt;
    _attemptingRTTConnection = false;
    _rttConnectionActive = true;

    bool receivedMessage = false;

    _rttWebsocketListener = _rttWebsocket!.stream.listen(
      (data) {
        if (!receivedMessage) {
          logger.info('RTT protocol connected on $serverBaseAddress');
          receivedMessage = true;
        }

        if (!_serverConnectionActive && mainWebsocketActive) {
          _onFirstMessageReceived();
        }

        if (data is! Uint8List) {
          return;
        }

        var msg = deserialize(data);

        int topicID = msg[0] as int;
        int timestampUS = msg[1] as int;
        var value = msg[3];

        if (value is! int) {
          return;
        }

        if (topicID & 0xFF == 0xFF) {
          _rttHandleRecieveTimestamp(timestampUS, value);
        }
      },
      onDone: _rttOnClose,
      onError: (err) {
        logger.error('RTT Error', err);
      },
      cancelOnError: true,
    );
  }

  void _onFirstMessageReceived() {
    logger.info(
      'Network Tables connected on IP address $serverBaseAddress with protocol ${_mainWebsocket!.protocol}',
    );
    lastAnnouncedValues.clear();
    lastAnnouncedTimestamps.clear();

    for (NT4Subscription sub in _subscriptions.values) {
      sub.updateValue(null, _getClientTimeUS());
    }

    _serverConnectionActive = true;

    onConnect?.call();
  }

  Future<void> _rttOnClose() async {
    // Block out any connection attempts so we can ensure everything is closed
    _attemptingRTTConnection = true;

    await _rttWebsocketListener?.cancel();
    _rttWebsocketListener = null;
    await _rttWebsocket?.sink.close();
    _rttWebsocket = null;

    _lastPongTime = 0;
    _rttConnectionActive = false;

    logger.info('RTT Connection closed');
    _attemptingRTTConnection = false;
  }

  Future<void> _wsOnClose([bool autoReconnect = true]) async {
    logger.debug('WS connection on close, auto reconnect: $autoReconnect');
    _serverConnectionActive = false;
    onDisconnect?.call();

    // Block out any connection attempts while disposing of the sockets
    _attemptingNTConnection = true;
    _attemptingRTTConnection = true;
    _attemptConnection = false;

    _pingTimer?.cancel();
    _pongTimer?.cancel();

    await _mainWebsocketListener?.cancel();
    await _mainWebsocket?.sink.close();

    await _rttWebsocketListener?.cancel();
    await _rttWebsocket?.sink.close();

    _mainWebsocket = null;
    _rttWebsocket = null;

    _mainWebsocketListener = null;
    _rttWebsocketListener = null;

    _serverConnectionActive = false;
    _rttConnectionActive = false;
    _useRTT = false;

    _lastPongTime = 0;
    _latencyMs = 0;

    logger.info('Network Tables disconnected');

    announcedTopics.clear();

    _attemptingNTConnection = false;
    _attemptingRTTConnection = false;

    logger.debug('[NT4] Connection closed. Attempting to reconnect in 500 ms');
    if (autoReconnect) {
      logger.trace(
        'Auto reconnect set to true, setting attempt connection to true',
      );
      _attemptConnection = true;
    }
  }

  void _wsOnMessage(dynamic data) {
    if (data is String) {
      var rxArr = jsonDecode(data.toString());

      if (rxArr is! List) {
        logger.warning('[NT4] Ignoring text message, not an array');
      }

      for (var msg in rxArr) {
        if (msg is! Map) {
          logger.warning('[NT4] Ignoring text message, not a json object');
          continue;
        }

        var method = msg['method'];
        var params = msg['params'];

        if (method == null || method is! String) {
          logger.warning('[NT4] Ignoring text message, method not string');
          continue;
        }

        if (params == null || params is! Map) {
          logger.warning('[NT4] Ignoring text message, params not json object');
          continue;
        }

        if (method == 'announce') {
          NT4Topic? currentTopic;
          for (NT4Topic topic in _clientPublishedTopics.values) {
            if (params['name'] == topic.name) {
              currentTopic = topic;
            }
          }

          NT4Topic newTopic = NT4Topic(
            name: params['name'],
            type: NT4Type.parse(params['type']),
            id: params['id'],
            pubUID: params['pubid'] ?? (currentTopic?.pubUID ?? 0),
            properties: params['properties'],
          );
          announcedTopics[newTopic.id] = newTopic;

          for (final listener in _topicAnnounceListeners) {
            listener.call(newTopic);
          }
        } else if (method == 'unannounce') {
          NT4Topic? removedTopic = announcedTopics[params['id']];
          if (removedTopic == null) {
            logger.warning(
              '[NT4] Ignorining unannounce, topic was not previously announced',
            );
            continue;
          }
          announcedTopics.remove(removedTopic.id);

          for (final listener in _topicUnannounceListeners) {
            listener.call(removedTopic);
          }
        } else if (method == 'properties') {
          String topicName = params['name'];
          NT4Topic? topic = getTopicFromName(topicName);
          if (topic == null) {
            logger.warning(
              '[NT4] Ignoring properties, topic was not announced',
            );
            continue;
          }

          Map<String, dynamic> update = tryCast(params['update']) ?? {};
          for (MapEntry<String, dynamic> entry in update.entries) {
            if (entry.value == null) {
              topic.properties.remove(entry.key);
            } else {
              topic.properties[entry.key] = entry.value;
            }
          }
        } else {
          logger.warning(
            '[NT4] Ignoring text message - unknown method $method',
          );
          continue;
        }
      }
    } else if (data is Uint8List) {
      final decoder = Deserializer(data);

      bool done = false;
      while (!done) {
        try {
          var msg = decoder.decode();

          int topicID = msg[0] as int;
          int timestampUS = msg[1] as int;
          var value = msg[3];

          if (topicID >= 0) {
            NT4Topic topic = announcedTopics[topicID]!;
            lastAnnouncedValues[topic.name] = value;
            lastAnnouncedTimestamps[topic.name] = timestampUS;
            for (NT4Subscription sub in _subscriptions.values) {
              if (sub.topic == topic.name) {
                sub.updateValue(value, timestampUS);
              }
            }

            // If it's a schema topic, try to process the new schema
            // if any new schema has been successfully processed, update
            // all subscriptions which don't currently have a processed schema
            if (topic.name.startsWith('/.schema') &&
                topic.type == NT4Type.structschema()) {
              String structName = topic.name
                  .split('/')
                  .last
                  .replaceFirst('struct:', '');
              if (schemaManager.processNewSchema(
                structName,
                value as List<int>,
              )) {
                for (final subscription in _subscribedTopics.where(
                  (e) =>
                      e.options.structMeta != null &&
                      e.options.structMeta!.schema == null,
                )) {
                  final NT4StructMeta structMeta =
                      subscription.options.structMeta!;
                  structMeta.schema = schemaManager.getSchema(
                    structMeta.schemaName,
                  );
                  // Update the subscription if there was a previously announced value
                  // for the topic
                  if (lastAnnouncedValues.containsKey(subscription.topic) &&
                      lastAnnouncedTimestamps.containsKey(subscription.topic)) {
                    subscription.updateValue(
                      lastAnnouncedValues[subscription.topic]!,
                      lastAnnouncedTimestamps[subscription.topic]!,
                    );
                  }
                }
              }
            }
          } else if (topicID & 0xFF == 0xFF && !_useRTT) {
            _rttHandleRecieveTimestamp(timestampUS, value as int);
          } else {
            logger.warning(
              '[NT4] ignoring binary data, invalid topic ID: $topicID',
            );
          }
        } catch (err) {
          done = true;
        }
      }
    } else {
      logger.warning(
        '[NT4] Ignoring websocket message, invalid type: ${data.runtimeType}',
      );
    }
  }

  void _checkPingStatus(Timer timer) {
    if (!_serverConnectionActive || _lastPongTime == 0) {
      return;
    }

    int currentTime = _getClientTimeUS();

    if (currentTime - _lastPongTime > _timeoutInterval * 1000) {
      logger.info('Network Tables connection timed out');
      _wsOnClose();
    }
  }

  int getNewSubUID() {
    _subscriptionUIDCounter++;
    return _subscriptionUIDCounter + _clientId;
  }

  int getNewPubUID() {
    _publishUIDCounter++;
    return _publishUIDCounter + _clientId;
  }
}
