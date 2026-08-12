import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/network_alerts.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> networkAlertsJson = {
    'topic': 'Test/Alerts',
    'period': 0.100,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Alerts/errors',
          type: NT4Type.array(NT4Type.string()),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Alerts/warnings',
          type: NT4Type.array(NT4Type.string()),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Alerts/infos',
          type: NT4Type.array(NT4Type.string()),
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Alerts/errors': ['Test Error 1', 'Test Error 2'],
        'Test/Alerts/warnings': ['Test Warning 1', 'Test Warning 2'],
        'Test/Alerts/infos': ['Test Info 1', 'Test Info 2'],
      },
    );
  });

  test('Network alerts from json', () {
    NTWidgetModel networkAlertsModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Alerts',
      networkAlertsJson,
    );

    expect(networkAlertsModel.type, 'Alerts');
    expect(networkAlertsModel.runtimeType, NetworkAlertsModel);
  });

  test('Network alerts to json', () {
    NetworkAlertsModel networkAlertsModel = NetworkAlertsModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Alerts',
      period: 0.100,
    );

    expect(networkAlertsModel.toJson(), networkAlertsJson);
  });

  testWidgets('Network alerts widget', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel networkAlertsModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Alerts',
      networkAlertsJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: networkAlertsModel,
            child: const NetworkAlerts(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byIcon(Icons.cancel), findsNWidgets(2));
    expect(find.byIcon(Icons.warning), findsNWidgets(2));
    expect(find.byIcon(Icons.info), findsNWidgets(2));

    expect(find.text('Test Error 1'), findsOneWidget);
    expect(find.text('Test Error 2'), findsOneWidget);

    expect(find.text('Test Warning 1'), findsOneWidget);
    expect(find.text('Test Warning 2'), findsOneWidget);

    expect(find.text('Test Info 1'), findsOneWidget);
    expect(find.text('Test Info 2'), findsOneWidget);
  });
}
