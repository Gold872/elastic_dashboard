import 'package:material_ui/material_ui.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/toggle_button.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> toggleButtonJson = {
    'topic': 'Test/Boolean Value',
    'data_type': 'boolean',
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
          name: 'Test/Boolean Value',
          type: NT4Type.boolean(),
          properties: {},
        ),
      ],
      virtualValues: {'Test/Boolean Value': false},
    );
  });

  test('Toggle button from json', () {
    NTWidgetModel toggleButtonModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Toggle Button',
      toggleButtonJson,
    );

    expect(toggleButtonModel.type, 'Toggle Button');
    expect(toggleButtonModel.runtimeType, SingleTopicNTWidgetModel);
    expect(
      toggleButtonModel.getAvailableDisplayTypes(),
      unorderedEquals([
        'Boolean Box',
        'Toggle Button',
        'Toggle Switch',
        'Text Display',
        'Large Text Display',
      ]),
    );
  });

  test('Toggle button to json', () {
    NTWidgetModel toggleButtonModel = SingleTopicNTWidgetModel.createDefault(
      ntConnection: ntConnection,
      preferences: preferences,
      type: 'Toggle Button',
      topic: 'Test/Boolean Value',
      dataType: NT4Type.boolean(),
      period: 0.100,
    );

    expect(toggleButtonModel.toJson(), toggleButtonJson);
  });

  testWidgets('Toggle button widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel toggleButtonModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Toggle Button',
      toggleButtonJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: toggleButtonModel,
            child: const ToggleButton(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Boolean Value'), findsOneWidget);

    await widgetTester.tap(find.text('Boolean Value'));
    toggleButtonModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(ntConnection.getLastAnnouncedValue('Test/Boolean Value'), isTrue);

    await widgetTester.tap(find.text('Boolean Value'));
    toggleButtonModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(ntConnection.getLastAnnouncedValue('Test/Boolean Value'), isFalse);
  });
}
