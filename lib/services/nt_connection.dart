import 'package:flutter/foundation.dart';

import 'package:elastic_dashboard/services/ds_interop.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/services/struct_schemas/nt_struct.dart';

typedef SubscriptionIdentification = ({
  String topic,
  NT4SubscriptionOptions options,
});

enum NTServerTarget {
  robotCode('Robot Code', 5810),
  systemCore('SystemCore Internal', 6810);

  const NTServerTarget(this.name, this.port);

  final String name;
  final int port;

  static NTServerTarget? fromIndex(int? index) {
    if (index == null || index < 0 || index >= values.length) {
      return null;
    }
    return values.firstWhere((e) => e.index == index);
  }
}

class NTConnection {
  late NT4Client _ntClient;
  late DSInteropClient _dsClient;
  final SchemaManager schemaManager = SchemaManager();

  NTServerTarget serverMode;
  List<VoidCallback> onConnectedListeners = [];
  List<VoidCallback> onDisconnectedListeners = [];

  final ValueNotifier<bool> _ntConnected = ValueNotifier(false);
  ValueNotifier<bool> get ntConnected => _ntConnected;

  bool get isNT4Connected => _ntConnected.value;

  bool get isDSConnected => _dsClient.connectionStatus.value;

  ValueNotifier<bool> get dsConnected => _dsClient.connectionStatus;
  ValueNotifier<int?> get dsHeight => _dsClient.dsHeightNotifier;
  ValueNotifier<String?> get dsIpAddress => _dsClient.ipNotifier;

  int get serverTime => _ntClient.getServerTimeUS();

  @visibleForTesting
  List<NT4Subscription> get subscriptions => subscriptionUseCount.keys.toList();

  @visibleForTesting
  String get serverBaseAddress => _ntClient.serverBaseAddress;

  Map<int, NT4Subscription> subscriptionMap = {};
  Map<NT4Subscription, int> subscriptionUseCount = {};

  NTConnection(String ipAddress, [this.serverMode = Defaults.targetServer]) {
    nt4Connect(ipAddress);
  }

  void nt4Connect(String ipAddress) {
    _ntClient = NT4Client(
      serverBaseAddress: ipAddress,
      serverPort: serverMode.port,
      schemaManager: schemaManager,
      onConnect: () {
        _ntConnected.value = true;

        for (VoidCallback callback in onConnectedListeners) {
          callback.call();
        }
      },
      onDisconnect: () {
        _ntConnected.value = false;

        for (VoidCallback callback in onDisconnectedListeners) {
          callback.call();
        }
      },
    );

    // Allows all published topics to be announced
    _ntClient.subscribe(
      topic: '',
      options: const NT4SubscriptionOptions(topicsOnly: true),
    );

    // add all struct schemas to the schema manager
    _ntClient.subscribe(
      topic: '/.schema',
      options: const NT4SubscriptionOptions(all: true),
    );
  }

  void dsClientConnect() {
    _dsClient = DSInteropClient();
  }

  void addConnectedListener(VoidCallback callback) {
    onConnectedListeners.add(callback);
  }

  void removeConnectedListener(VoidCallback callback) {
    onConnectedListeners.remove(callback);
  }

  void addDisconnectedListener(VoidCallback callback) {
    onDisconnectedListeners.add(callback);
  }

  void removeDisconnectedListener(VoidCallback callback) {
    onDisconnectedListeners.remove(callback);
  }

  void addTopicAnnounceListener(Function(NT4Topic topic) onAnnounce) {
    _ntClient.addTopicAnnounceListener(onAnnounce);
  }

  void removeTopicAnnounceListener(Function(NT4Topic topic) onAnnounce) {
    _ntClient.removeTopicAnnounceListener(onAnnounce);
  }

  void addTopicUnannounceListener(Function(NT4Topic topic) onUnannounce) {
    _ntClient.addTopicUnannounceListener(onUnannounce);
  }

  void removeTopicUnannounceListener(Function(NT4Topic topic) onUnannounce) {
    _ntClient.removeTopicUnannounceListener(onUnannounce);
  }

  Future<T?>? subscribeAndRetrieveData<T>(
    String topic, {
    period = 0.1,
    timeout = const Duration(seconds: 2, milliseconds: 500),
  }) async {
    NT4Subscription subscription = subscribe(topic, period);

    T? value;
    try {
      value =
          await subscription
                  .periodicStream()
                  .firstWhere((element) => element != null && element is T)
                  .timeout(timeout)
              as T?;
    } catch (e) {
      value = null;
    }

    unSubscribe(subscription);

    return value;
  }

  Stream<bool> connectionStatus() async* {
    yield _ntConnected.value;
    bool lastYielded = _ntConnected.value;

    while (true) {
      if (_ntConnected.value != lastYielded) {
        yield _ntConnected.value;
        lastYielded = _ntConnected.value;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Map<int, NT4Topic> announcedTopics() => _ntClient.announcedTopics;

  Stream<double> latencyStream() => _ntClient.latencyStream();

  void changeIPAddress(String ipAddress) {
    if (_ntClient.serverBaseAddress == ipAddress) {
      return;
    }

    _ntClient.setServerBaseAddreess(ipAddress);
  }

  void changeServerMode(NTServerTarget mode) {
    if (serverMode == mode) {
      return;
    }
    serverMode = mode;
    _ntClient.setServerPort(mode.port);
  }

  NT4Subscription subscribe(String topic, [double period = 0.1]) =>
      subscribeWithOptions(
        topic,
        NT4SubscriptionOptions(periodicRateSeconds: period),
      );

  NT4Subscription subscribeWithOptions(
    String topic,
    NT4SubscriptionOptions options,
  ) {
    int hashCode = Object.hash(topic, options);

    if (subscriptionMap.containsKey(hashCode)) {
      NT4Subscription existingSubscription = subscriptionMap[hashCode]!;
      subscriptionUseCount.update(existingSubscription, (value) => value + 1);

      return existingSubscription;
    }

    NT4Subscription newSubscription = _ntClient.subscribe(
      topic: topic,
      options: options,
    );

    if (options.structMeta != null) {
      options.structMeta!.schema ??= schemaManager.getSchema(
        options.structMeta!.schemaName,
      );
    }

    subscriptionMap[hashCode] = newSubscription;
    subscriptionUseCount[newSubscription] = 1;

    return newSubscription;
  }

  NT4Subscription subscribeAll(String topic, [double period = 0.1]) =>
      subscribeWithOptions(
        topic,
        NT4SubscriptionOptions(periodicRateSeconds: period, all: true),
      );

  void unSubscribe(NT4Subscription subscription) {
    if (!subscriptionUseCount.containsKey(subscription)) {
      _ntClient.unSubscribe(subscription);
      return;
    }

    int hashCode = Object.hash(subscription.topic, subscription.options);

    subscriptionUseCount.update(subscription, (value) => value - 1);

    if (subscriptionUseCount[subscription]! <= 0) {
      subscriptionMap.remove(hashCode);
      subscriptionUseCount.remove(subscription);
      _ntClient.unSubscribe(subscription);
    }
  }

  NT4Topic? getTopicFromSubscription(NT4Subscription subscription) =>
      _ntClient.getTopicFromName(subscription.topic);

  NT4Topic? getTopicFromName(String topic) => _ntClient.getTopicFromName(topic);

  void publishTopic(NT4Topic topic) {
    _ntClient.publishTopic(topic);
  }

  NT4Topic publishNewTopic(
    String name,
    NT4Type type, {
    Map<String, dynamic> properties = const {},
  }) => _ntClient.publishNewTopic(name, type, properties);

  bool isTopicPublished(NT4Topic? topic) => _ntClient.isTopicPublished(topic);

  Object? getLastAnnouncedValue(String topic) =>
      _ntClient.lastAnnouncedValues[topic];

  void unpublishTopic(NT4Topic topic) {
    _ntClient.unpublishTopic(topic);
  }

  void updateDataFromSubscription(
    NT4Subscription subscription,
    dynamic data, [
    int? timestamp,
  ]) {
    _ntClient.addSampleFromName(subscription.topic, data, timestamp);
  }

  void updateDataFromTopic(NT4Topic topic, dynamic data, [int? timestamp]) {
    _ntClient.addSample(topic, data, timestamp);
  }

  @visibleForTesting
  void updateDataFromTopicName(String topic, dynamic data, [int? timestamp]) {
    _ntClient.addSampleFromName(topic, data, timestamp);
  }
}
