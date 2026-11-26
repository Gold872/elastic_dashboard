import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';

import '../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> containerJson = {
    'title': 'Scored',
    'x': 0.0,
    'y': 0.0,
    'width': 128.0,
    'height': 128.0,
    'type': 'Toggle Button',
    'properties': {
      'topic': 'Reef/A/L4',
      'period': 0.06,
      'data_type': 'boolean',
    },
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(name: 'Reef/A/L4', type: NT4Type.boolean(), properties: {}),
      ],
      virtualValues: {'Reef/A/L4': false},
    );
  });

  NTWidgetContainerModel createModel(Map<String, dynamic> jsonData) =>
      NTWidgetContainerModel.fromJson(
        ntConnection: ntConnection,
        preferences: preferences,
        jsonData: jsonData,
        enabled: true,
      );

  Future<void> pumpContainer(
    WidgetTester widgetTester,
    NTWidgetContainerModel model,
  ) async {
    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetContainerModel>.value(
            value: model,
            child: const DraggableNTWidgetContainer(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();
  }

  test('Container appearance defaults when not in json', () {
    NTWidgetContainerModel model = createModel(containerJson);

    expect(model.backgroundOpacity, 1.0);
    expect(model.showTitle, isTrue);
    expect(model.toJson(), containerJson);
  });

  test('Container appearance from json', () {
    Map<String, dynamic> jsonData = {
      ...containerJson,
      'background_opacity': 0.4,
      'show_title': false,
    };

    NTWidgetContainerModel model = createModel(jsonData);

    expect(model.backgroundOpacity, 0.4);
    expect(model.showTitle, isFalse);
    expect(model.toJson(), jsonData);
  });

  test('Container background opacity is clamped', () {
    expect(
      createModel({
        ...containerJson,
        'background_opacity': 2,
      }).backgroundOpacity,
      1.0,
    );
    expect(
      createModel({
        ...containerJson,
        'background_opacity': -1,
      }).backgroundOpacity,
      0.0,
    );
    expect(
      createModel({...containerJson, 'background_opacity': 2}).toJson(),
      containerJson,
    );
  });

  BoxDecoration cardDecoration(WidgetTester widgetTester) =>
      widgetTester
              .widget<Container>(
                find
                    .descendant(
                      of: find.byType(WidgetContainer),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .decoration!
          as BoxDecoration;

  testWidgets('Container shows title and background by default', (
    widgetTester,
  ) async {
    FlutterError.onError = ignoreOverflowErrors;

    await pumpContainer(widgetTester, createModel(containerJson));

    WidgetContainer container = widgetTester.widget(
      find.byType(WidgetContainer),
    );

    expect(container.showTitle, isTrue);
    expect(container.backgroundOpacity, 1.0);
    expect(find.text('Scored'), findsOneWidget);
    expect(find.text('L4'), findsOneWidget);

    BoxDecoration decoration = cardDecoration(widgetTester);
    expect(decoration.color, const Color.fromARGB(255, 40, 40, 40));
    expect(decoration.boxShadow, isNotEmpty);
  });

  testWidgets('Container with hidden title and background opacity', (
    widgetTester,
  ) async {
    FlutterError.onError = ignoreOverflowErrors;

    await pumpContainer(
      widgetTester,
      createModel({
        ...containerJson,
        'background_opacity': 0.4,
        'show_title': false,
      }),
    );

    WidgetContainer container = widgetTester.widget(
      find.byType(WidgetContainer),
    );

    expect(container.showTitle, isFalse);
    expect(container.backgroundOpacity, 0.4);
    expect(find.text('Scored'), findsNothing);

    BoxDecoration decoration = cardDecoration(widgetTester);
    expect(decoration.color!.a, closeTo(0.4, 0.01));
    expect(decoration.boxShadow, isNull);

    // Only colors change, no opacity layers are added
    expect(
      widgetTester
          .widgetList<Opacity>(
            find.descendant(
              of: find.byType(WidgetContainer),
              matching: find.byType(Opacity),
            ),
          )
          .every((opacity) => opacity.opacity == 1.0),
      isTrue,
    );

    // The widget inside still works normally
    await widgetTester.tap(find.text('L4'));
    await widgetTester.pumpAndSettle();

    expect(ntConnection.getLastAnnouncedValue('Reef/A/L4'), isTrue);
  });

  testWidgets('Editing container appearance', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetContainerModel model = createModel(containerJson);

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => model.showEditProperties(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await widgetTester.tap(find.text('Open'));
    await widgetTester.pumpAndSettle();

    final hideTitleButton = find.widgetWithIcon(
      IconButton,
      Icons.visibility_outlined,
    );
    final opacityField = find.widgetWithText(
      DialogTextInput,
      'Background Opacity',
    );

    expect(hideTitleButton, findsOneWidget);
    expect(opacityField, findsOneWidget);

    await widgetTester.tap(hideTitleButton);
    await widgetTester.pumpAndSettle();

    expect(model.showTitle, isFalse);
    expect(
      find.widgetWithIcon(IconButton, Icons.visibility_off_outlined),
      findsOneWidget,
    );

    await widgetTester.enterText(opacityField, '0.5');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);
    await widgetTester.pumpAndSettle();

    expect(model.backgroundOpacity, 0.5);
    expect(model.toJson()['background_opacity'], 0.5);
    expect(model.toJson()['show_title'], isFalse);
  });
}
