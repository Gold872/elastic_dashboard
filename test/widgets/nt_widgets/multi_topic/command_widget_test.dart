import 'package:material_ui/material_ui.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/command_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> commandWidgetJson = {
    'topic': 'Test/Command',
    'period': 0.100,
    'show_type': true,
    'maximize_button_space': true,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Command/running',
          type: NT4Type.boolean(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Command/name',
          type: NT4Type.string(),
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Commnad/running': false,
        'Test/Command/name': 'Test Command',
      },
    );
  });

  test('Command widget from json', () {
    NTWidgetModel commandModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Command',
      commandWidgetJson,
    );

    expect(commandModel.type, 'Command');
    expect(commandModel.runtimeType, CommandModel);

    if (commandModel is! CommandModel) {
      return;
    }

    expect(commandModel.showType, isTrue);
    expect(commandModel.maximizeButtonSpace, isTrue);
  });

  test('Command widget to json', () {
    CommandModel commandModel = CommandModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Command',
      period: 0.100,
      showType: true,
      maximizeButtonSpace: true,
    );

    expect(commandModel.toJson(), commandWidgetJson);
  });

  testWidgets('Command widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel commandModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Command',
      commandWidgetJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: commandModel,
            child: const CommandWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('Command'), findsOneWidget);
    expect(find.text('Type: Test Command'), findsOneWidget);

    await widgetTester.tap(find.text('Command'));
    await widgetTester.pumpAndSettle();

    expect(ntConnection.getLastAnnouncedValue('Test/Command/running'), isTrue);

    commandModel.refresh();
    await widgetTester.pumpAndSettle();

    await widgetTester.tap(find.text('Command'));
    await widgetTester.pumpAndSettle();

    expect(ntConnection.getLastAnnouncedValue('Test/Command/running'), isFalse);

    (commandModel as CommandModel).showType = false;
    await widgetTester.pumpAndSettle();

    expect(find.text('Type: Test Command'), findsNothing);
  });

  testWidgets('Command widget edit properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    CommandModel commandModel = CommandModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Command',
      period: 0.100,
      showType: true,
      maximizeButtonSpace: true,
    );

    NTWidgetContainerModel ntContainerModel = NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.zero,
      title: 'Command',
      childModel: commandModel,
    );

    final key = GlobalKey();

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetContainerModel>.value(
            key: key,
            value: ntContainerModel,
            child: const DraggableNTWidgetContainer(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    ntContainerModel.showEditProperties(key.currentContext!);

    await widgetTester.pumpAndSettle();

    final showType = find.widgetWithText(DialogToggleSwitch, 'Show Type');

    expect(showType, findsOneWidget);

    await widgetTester.tap(
      find.descendant(of: showType, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();
    expect(commandModel.showType, false);

    await widgetTester.tap(
      find.descendant(of: showType, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();
    expect(commandModel.showType, true);

    final maximizeSpace = find.widgetWithText(
      DialogToggleSwitch,
      'Maximize Button Space',
    );

    expect(maximizeSpace, findsOneWidget);

    await widgetTester.tap(
      find.descendant(of: maximizeSpace, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();
    expect(commandModel.maximizeButtonSpace, false);

    await widgetTester.tap(
      find.descendant(of: maximizeSpace, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();
    expect(commandModel.maximizeButtonSpace, true);
  });
}
