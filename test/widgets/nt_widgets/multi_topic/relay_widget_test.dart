import 'package:material_ui/material_ui.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/relay_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> relayJson = {
    'topic': 'Test/Relay',
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
          name: 'Test/Relay/Value',
          type: NT4Type.string(),
          properties: {},
        ),
      ],
      virtualValues: {'Test/Relay/Value': 'Off'},
    );
  });

  test('Relay from json', () {
    NTWidgetModel relayModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Relay',
      relayJson,
    );

    expect(relayModel.type, 'Relay');
    expect(relayModel.runtimeType, RelayModel);
  });

  test('Relay to json', () {
    RelayModel relayModel = RelayModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Relay',
      period: 0.100,
    );

    expect(relayModel.toJson(), relayJson);
  });

  testWidgets('Relay widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel relayModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Relay',
      relayJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: relayModel,
            child: const RelayWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(ToggleButtons), findsOneWidget);

    expect(find.text('On'), findsOneWidget);
    await widgetTester.tap(find.text('On'));
    await widgetTester.pumpAndSettle();

    expect(ntConnection.getLastAnnouncedValue('Test/Relay/Value'), 'On');

    expect(find.text('Forward'), findsOneWidget);
    await widgetTester.tap(find.text('Forward'));
    await widgetTester.pumpAndSettle();

    expect(ntConnection.getLastAnnouncedValue('Test/Relay/Value'), 'Forward');

    expect(find.text('Reverse'), findsOneWidget);
    await widgetTester.tap(find.text('Reverse'));
    await widgetTester.pumpAndSettle();

    expect(ntConnection.getLastAnnouncedValue('Test/Relay/Value'), 'Reverse');

    expect(find.text('Off'), findsOneWidget);
    await widgetTester.tap(find.text('Off'));
    await widgetTester.pumpAndSettle();

    expect(ntConnection.getLastAnnouncedValue('Test/Relay/Value'), 'Off');
  });
}
