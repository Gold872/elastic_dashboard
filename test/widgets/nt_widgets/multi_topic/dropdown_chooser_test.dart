import 'package:flutter/material.dart';

import 'package:dropdown_button2/dropdown_button2.dart';
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
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> dropdownChooserJson = {
    'topic': 'Test/Dropdown Chooser',
    'period': 0.100,
    'sort_options': true,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Dropdown Chooser/options',
          type: NT4Type.array(NT4Type.string()),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Dropdown Chooser/default',
          type: NT4Type.string(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Dropdown Chooser/selected/value',
          type: NT4Type.string(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Dropdown Chooser/selected/tune',
          type: NT4Type.string(),
          properties: {'retained': true},
        ),
      ],
      virtualValues: {
        'Test/Dropdown Chooser/options': ['One', 'Two', 'Three'],
        'Test/Dropdown Chooser/default': 'Two',
        'Test/Dropdown Chooser/selected/value': 'Two',
        'Test/Dropdown Chooser/selected/tune': null,
      },
    );
  });

  test('Dropdown chooser from json', () {
    NTWidgetModel dropdownChooserModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Dropdown Chooser',
      dropdownChooserJson,
    );

    expect(dropdownChooserModel.type, 'Dropdown Chooser');
    expect(dropdownChooserModel.runtimeType, DropdownChooserModel);

    if (dropdownChooserModel is! DropdownChooserModel) {
      return;
    }

    expect(dropdownChooserModel.sortOptions, isTrue);
  });

  test('Dropdown chooser alias name', () {
    NTWidgetModel dropdownChooserModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Selectable',
      dropdownChooserJson,
    );

    expect(dropdownChooserModel.type, 'Dropdown Chooser');
    expect(dropdownChooserModel.runtimeType, DropdownChooserModel);

    if (dropdownChooserModel is! DropdownChooserModel) {
      return;
    }

    expect(dropdownChooserModel.sortOptions, isTrue);
  });

  test('Dropdown chooser to json', () {
    DropdownChooserModel dropdownChooserModel = DropdownChooserModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Dropdown Chooser',
      period: 0.100,
      sortOptions: true,
    );

    expect(dropdownChooserModel.toJson(), dropdownChooserJson);
  });

  testWidgets('Dropdown chooser widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel dropdownChooserModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Dropdown Chooser',
      dropdownChooserJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: dropdownChooserModel,
            child: const DropdownChooser(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(DropdownButton2<String>), findsOneWidget);
    expect(find.text('One'), findsNothing);
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('Three'), findsNothing);
    expect(
      (dropdownChooserModel as DropdownChooserModel).previousSelected,
      isNull,
    );
    expect(find.byIcon(Icons.check), findsOneWidget);

    await widgetTester.tap(find.byType(DropdownButton2<String>));
    await widgetTester.pumpAndSettle();

    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsNWidgets(2));
    expect(find.text('Three'), findsOneWidget);

    await widgetTester.tap(find.text('One'));
    dropdownChooserModel.onChooserStateUpdate();
    await widgetTester.pumpAndSettle();

    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsNothing);
    expect(find.text('Three'), findsNothing);

    expect(dropdownChooserModel.previousSelected, 'One');
    expect(find.byIcon(Icons.priority_high), findsOneWidget);

    ntConnection.updateDataFromTopicName(
      dropdownChooserModel.activeTopicName,
      'One',
    );

    dropdownChooserModel.onChooserStateUpdate();
    await widgetTester.pumpAndSettle();

    expect(find.byIcon(Icons.priority_high), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('Dropdown chooser edit properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    DropdownChooserModel dropdownChooserModel = DropdownChooserModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Dropdown Chooser',
      period: 0.100,
      sortOptions: true,
    );

    NTWidgetContainerModel ntContainerModel = NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.zero,
      title: 'Dropdown Chooser',
      childModel: dropdownChooserModel,
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

    final sortOptions = find.widgetWithText(
      DialogToggleSwitch,
      'Sort Options Alphabetically',
    );

    expect(sortOptions, findsOneWidget);

    await widgetTester.tap(
      find.descendant(of: sortOptions, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();
    expect(dropdownChooserModel.sortOptions, false);

    await widgetTester.tap(
      find.descendant(of: sortOptions, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();
    expect(dropdownChooserModel.sortOptions, true);
  });
}
