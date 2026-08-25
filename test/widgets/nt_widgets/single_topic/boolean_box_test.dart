import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/boolean_box.dart';

import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> booleanBoxJson = {
    'topic': 'Test/Boolean Value',
    'period': 0.100,
    'data_type': 'boolean',
    'true_color': Colors.green.toARGB32(),
    'false_color': Colors.red.toARGB32(),
    'true_icon': 'None',
    'false_icon': 'None',
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  Finder findColor(Color color) => find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).color != null &&
        (widget.decoration as BoxDecoration).color!.toARGB32() ==
            color.toARGB32(),
  );

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

  test('Boolean box from json', () {
    NTWidgetModel booleanBoxModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Boolean Box',
      booleanBoxJson,
    );

    expect(booleanBoxModel.type, 'Boolean Box');
    expect(booleanBoxModel.runtimeType, BooleanBoxModel);
    expect(
      booleanBoxModel.getAvailableDisplayTypes(),
      unorderedEquals([
        'Boolean Box',
        'Toggle Switch',
        'Toggle Button',
        'Text Display',
        'Large Text Display',
      ]),
    );

    if (booleanBoxModel is! BooleanBoxModel) {
      return;
    }

    expect(booleanBoxModel.trueColor, Color(Colors.green.toARGB32()));
    expect(booleanBoxModel.falseColor, Color(Colors.red.toARGB32()));
    expect(booleanBoxModel.trueIcon, 'None');
    expect(booleanBoxModel.falseIcon, 'None');
  });

  test('Boolean box to json', () {
    BooleanBoxModel booleanBoxModel = BooleanBoxModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Boolean Value',
      dataType: NT4Type.boolean(),
      period: 0.100,
      trueColor: Colors.green,
      falseColor: Colors.red,
      trueIcon: 'None',
      falseIcon: 'None',
    );

    expect(booleanBoxModel.toJson(), booleanBoxJson);
  });

  testWidgets('Boolean box widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel booleanBoxModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Boolean Box',
      booleanBoxJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: booleanBoxModel as BooleanBoxModel,
            child: const BooleanBox(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(findColor(Colors.green), findsNothing);
    expect(findColor(Colors.red), findsOneWidget);

    ntConnection.updateDataFromTopicName('Test/Boolean Value', true);
    booleanBoxModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(findColor(Colors.green), findsOneWidget);
    expect(findColor(Colors.red), findsNothing);

    booleanBoxModel.trueIcon = 'Checkmark';
    await widgetTester.pumpAndSettle();

    expect(findColor(Colors.green), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);

    ntConnection.updateDataFromTopicName('Test/Boolean Value', false);
    booleanBoxModel.falseIcon = 'X';
    await widgetTester.pumpAndSettle();

    expect(find.byIcon(Icons.clear), findsOneWidget);

    booleanBoxModel.falseIcon = 'Exclamation Point';
    await widgetTester.pumpAndSettle();
    expect(find.byIcon(Icons.priority_high), findsOneWidget);
  });

  testWidgets('Boolean box edit properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    BooleanBoxModel booleanBoxModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Boolean Box',
      booleanBoxJson,
    ) as BooleanBoxModel;

    NTWidgetContainerModel ntContainerModel = NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.zero,
      title: 'Boolean Box',
      childModel: booleanBoxModel,
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

    final trueColorPicker = find.widgetWithText(
      DialogColorPicker,
      'True Color',
    );
    final falseColorPicker = find.widgetWithText(
      DialogColorPicker,
      'False Color',
    );

    final trueIcon = find.text('True Icon');
    final falseIcon = find.text('False Icon');

    final iconDropdown = find.byType(DialogDropdownChooser<String>);

    expect(trueColorPicker, findsOneWidget);
    expect(falseColorPicker, findsOneWidget);

    expect(trueIcon, findsOneWidget);
    expect(falseIcon, findsOneWidget);

    expect(iconDropdown, findsNWidgets(3));

    final trueColorButton = find.descendant(
      of: trueColorPicker,
      matching: find.byType(ElevatedButton),
    );
    final falseColorButton = find.descendant(
      of: falseColorPicker,
      matching: find.byType(ElevatedButton),
    );

    expect(trueColorButton, findsOneWidget);
    expect(falseColorButton, findsOneWidget);

    await widgetTester.tap(trueColorButton);
    await widgetTester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Hex Code'), findsOneWidget);
    await widgetTester.enterText(
      find.widgetWithText(TextField, 'Hex Code'),
      '000000',
    );
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pump();

    expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);
    await widgetTester.tap(find.widgetWithText(TextButton, 'Save'));

    await widgetTester.pumpAndSettle();

    expect(booleanBoxModel.trueColor.toARGB32(), Colors.black.toARGB32());

    await widgetTester.tap(
      find.byWidget(iconDropdown.evaluate().elementAt(1).widget),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('None'), findsNWidgets(3));
    expect(find.text('Checkmark'), findsOneWidget);

    await widgetTester.tap(find.text('Checkmark'));
    await widgetTester.pumpAndSettle();

    expect(booleanBoxModel.trueIcon, 'Checkmark');

    await widgetTester.tap(
      find.byWidget(iconDropdown.evaluate().elementAt(2).widget),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('None'), findsNWidgets(2));
    expect(find.text('Exclamation Point'), findsOneWidget);

    await widgetTester.tap(find.text('Exclamation Point'));
    await widgetTester.pumpAndSettle();

    expect(booleanBoxModel.falseIcon, 'Exclamation Point');
  });
}
