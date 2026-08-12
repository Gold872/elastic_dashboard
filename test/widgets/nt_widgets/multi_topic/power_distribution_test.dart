import 'package:material_ui/material_ui.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/power_distribution.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> powerDistributionJson = {
    'topic': 'Test/Power Distribution',
    'period': 0.100,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    List<NT4Topic> channelTopics = [];
    Map<String, double> virtualChannelValues = {};

    for (int i = 0; i <= PowerDistributionModel.numberOfChannels; i++) {
      channelTopics.add(
        NT4Topic(
          name: 'Test/Power Distribution/Chan$i',
          type: NT4Type.float(),
          properties: {},
        ),
      );

      virtualChannelValues.addAll({'Test/Power Distribution/Chan$i': 0.00});
    }

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Power Distribution/Voltage',
          type: NT4Type.float(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Power Distribution/TotalCurrent',
          type: NT4Type.float(),
          properties: {},
        ),
        ...channelTopics,
      ],
      virtualValues: {
        'Test/Power Distribution/Voltage': 12.00,
        'Test/Power Distribution/TotalCurrent': 100.0,
        ...virtualChannelValues,
      },
    );
  });

  test('Power distribution from json', () {
    NTWidgetModel powerDistributionModel =
        NTWidgetRegistry.buildNTModelFromJson(
          ntConnection,
          preferences,
          'PowerDistribution',
          powerDistributionJson,
        );

    expect(powerDistributionModel.type, 'PowerDistribution');
    expect(powerDistributionModel.runtimeType, PowerDistributionModel);
  });

  test('Power distribution from alias name', () {
    NTWidgetModel powerDistributionModel =
        NTWidgetRegistry.buildNTModelFromJson(
          ntConnection,
          preferences,
          'PDP',
          powerDistributionJson,
        );

    expect(powerDistributionModel.type, 'PowerDistribution');
    expect(powerDistributionModel.runtimeType, PowerDistributionModel);
  });

  test('Power distribution to json', () {
    PowerDistributionModel powerDistributionModel = PowerDistributionModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Power Distribution',
      period: 0.100,
    );

    expect(powerDistributionModel.toJson(), powerDistributionJson);
  });

  testWidgets('Power distribution widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel powerDistributionModel =
        NTWidgetRegistry.buildNTModelFromJson(
          ntConnection,
          preferences,
          'PowerDistribution',
          powerDistributionJson,
        );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: powerDistributionModel,
            child: const PowerDistribution(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Voltage'), findsOneWidget);
    expect(find.text('12.00 V'), findsOneWidget);

    expect(find.text('Total Current'), findsOneWidget);
    expect(find.text('100.00 A'), findsOneWidget);

    expect(find.text('00.00 A'), findsNWidgets(24));

    for (int i = 0; i <= 9; i++) {
      expect(find.text('Ch. $i '), findsOneWidget);
    }

    for (int i = 10; i <= 23; i++) {
      expect(find.text('Ch. $i'), findsOneWidget);
    }
  });
}
