import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/struct_schemas/nt_struct.dart';

void main() {
  test('NT4 Client', () {
    NTConnection ntConnection = NTConnection('10.3.5.32');

    expect(ntConnection.isNT4Connected, false);

    // Subscribing
    NT4Subscription subscription1 = ntConnection.subscribe(
      '/Telemetry/Test Number',
    );

    expect(ntConnection.subscriptions.length, greaterThanOrEqualTo(1));

    expect(
      ntConnection.getLastAnnouncedValue('/Telemetry/Test Number'),
      isNull,
    );

    // Publishing and adding to the last announced values
    ntConnection.updateDataFromSubscription(subscription1, 3.53);

    expect(
      ntConnection.getLastAnnouncedValue('/Telemetry/Test Number'),
      isNull,
    );

    ntConnection.updateDataFromTopic(
      NT4Topic(
        name: '/Telemetry/Test Number',
        type: NT4Type.float(),
        properties: {},
      ),
      3.53,
    );

    expect(
      ntConnection.getLastAnnouncedValue('/Telemetry/Test Number'),
      3.53,
    );

    expect(subscription1.currentValue != null, true);

    NT4Subscription subscription2 = ntConnection.subscribe(
      '/Telemetry/Test Number',
    );

    // If the subscriptions are shared
    expect(ntConnection.subscriptions.length, 1);

    ntConnection.unSubscribe(subscription1);

    expect(ntConnection.subscriptions.length, 1);

    ntConnection.unSubscribe(subscription2);

    expect(ntConnection.subscriptions.length, 0);

    // Changing ip address
    expect(
      ntConnection.getLastAnnouncedValue('/Telemetry/Test Number'),
      3.53,
    );

    ntConnection.changeIPAddress('10.30.15.2');

    expect(ntConnection.serverBaseAddress, '10.30.15.2');

    expect(ntConnection.announcedTopics().length, 0);
    expect(
      ntConnection.getLastAnnouncedValue('/Telemetry/Test Number'),
      3.53,
    );
  });

  test('NT4 Struct Subscription', () {
    final schema = NTStructSchema.parse(
      name: 'Pose2d',
      schema: 'Translation2d translation;Rotation2d rotation',
      knownSchemas: {
        'Translation2d': NTStructSchema.parse(
          name: 'Translation2d',
          schema: 'double x;double y',
        ),
        'Rotation2d': NTStructSchema.parse(
          name: 'Rotation2d',
          schema: 'double value',
        ),
      },
    );

    final NT4StructMeta structMeta = NT4StructMeta(
      path: ['translation', 'x'],
      schemaName: 'Pose2d',
      schema: schema,
    );

    final NT4Subscription subscription = NT4Subscription(
      topic: '/Test/Pose',
      options: NT4SubscriptionOptions(structMeta: structMeta),
    );

    ByteData byteData = ByteData((schema.bitLength / 8).ceil());
    byteData.setFloat64(0, 5.50, Endian.little);

    subscription.updateValue(Uint8List.view(byteData.buffer), 0);

    expect(subscription.value, 5.50);
  });
}
