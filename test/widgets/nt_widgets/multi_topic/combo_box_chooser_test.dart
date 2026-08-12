import 'package:material_ui/material_ui.dart';

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
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/combo_box_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> comboBoxChooserJson = {
    'topic': 'Test/Combo Box Chooser',
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
          name: 'Test/Combo Box Chooser/options',
          type: NT4Type.array(NT4Type.string()),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Combo Box Chooser/active',
          type: NT4Type.string(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Combo Box Chooser/selected',
          type: NT4Type.string(),
          properties: {'retained': true},
        ),
        NT4Topic(
          name: 'Test/Combo Box Chooser/default',
          type: NT4Type.string(),
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Combo Box Chooser/options': ['One', 'Two', 'Three'],
        'Test/Combo Box Chooser/active': 'Two',
        'Test/Combo Box Chooser/default': 'Two',
        'Test/Combo Box Chooser/selected': null,
      },
    );
  });

  test('Combo box chooser from json', () {
    NTWidgetModel comboBoxChooserModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'ComboBox Chooser',
      comboBoxChooserJson,
    );

    expect(comboBoxChooserModel.type, 'ComboBox Chooser');
    expect(comboBoxChooserModel.runtimeType, ComboBoxChooserModel);

    if (comboBoxChooserModel is! ComboBoxChooserModel) {
      return;
    }

    expect(comboBoxChooserModel.sortOptions, isTrue);
  });

  test('Combo box chooser alias name', () {
    NTWidgetModel comboBoxChooserModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'String Chooser',
      comboBoxChooserJson,
    );

    expect(comboBoxChooserModel.type, 'ComboBox Chooser');
    expect(comboBoxChooserModel.runtimeType, ComboBoxChooserModel);

    if (comboBoxChooserModel is! ComboBoxChooserModel) {
      return;
    }

    expect(comboBoxChooserModel.sortOptions, isTrue);
  });

  test('Combo box chooser to json', () {
    ComboBoxChooserModel comboBoxChooserModel = ComboBoxChooserModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Combo Box Chooser',
      period: 0.100,
      sortOptions: true,
    );

    expect(comboBoxChooserModel.toJson(), comboBoxChooserJson);
  });

  testWidgets('Combo box chooser widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel comboBoxChooserModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'ComboBox Chooser',
      comboBoxChooserJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: comboBoxChooserModel,
            child: const ComboBoxChooser(),
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
      (comboBoxChooserModel as ComboBoxChooserModel).previousSelected,
      isNull,
    );
    expect(find.byIcon(Icons.check), findsOneWidget);

    await widgetTester.tap(find.byType(DropdownButton2<String>));
    await widgetTester.pumpAndSettle();

    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsNWidgets(2));
    expect(find.text('Three'), findsOneWidget);

    await widgetTester.tap(find.text('One'));
    comboBoxChooserModel.onChooserStateUpdate();
    await widgetTester.pumpAndSettle();

    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsNothing);
    expect(find.text('Three'), findsNothing);

    expect(comboBoxChooserModel.previousSelected, 'One');
    expect(find.byIcon(Icons.priority_high), findsOneWidget);

    ntConnection.updateDataFromTopicName(
      comboBoxChooserModel.activeTopicName,
      'One',
    );

    comboBoxChooserModel.onChooserStateUpdate();
    await widgetTester.pumpAndSettle();

    expect(find.byIcon(Icons.priority_high), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('Combo box chooser edit properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    ComboBoxChooserModel comboBoxChooserModel = ComboBoxChooserModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Combo Box Chooser',
      period: 0.100,
      sortOptions: true,
    );

    NTWidgetContainerModel ntContainerModel = NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.zero,
      title: 'ComboBox Chooser',
      childModel: comboBoxChooserModel,
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
    expect(comboBoxChooserModel.sortOptions, false);

    await widgetTester.tap(
      find.descendant(of: sortOptions, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();
    expect(comboBoxChooserModel.sortOptions, true);
  });
}
