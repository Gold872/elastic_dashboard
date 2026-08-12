import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/text_display.dart';
import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> textDisplayJson = {
    'topic': 'Test/Display Value',
    'data_type': NT4Type.double().serialize(),
    'period': 0.100,
    'show_submit_button': true,
  };

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Display Value',
          type: NT4Type.double(),
          properties: {},
        ),
      ],
      virtualValues: {'Test/Display Value': 0.000001},
    );
  });

  test('Text display from json', () {
    NTWidgetModel textDisplayModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Text Display',
      textDisplayJson,
    );

    expect(textDisplayModel.type, 'Text Display');
    expect(textDisplayModel.runtimeType, TextDisplayModel);

    if (textDisplayModel is! TextDisplayModel) {
      return;
    }

    expect(textDisplayModel.showSubmitButton, isTrue);
  });

  test('Text display from alias name', () {
    NTWidgetModel textDisplayModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Text View',
      textDisplayJson,
    );

    expect(textDisplayModel.type, 'Text Display');
    expect(textDisplayModel.runtimeType, TextDisplayModel);

    if (textDisplayModel is! TextDisplayModel) {
      return;
    }

    expect(textDisplayModel.showSubmitButton, isTrue);
  });

  group('Show submit button defaults to', () {
    test('true if topic is persistent', () async {
      NTConnection ntConnection = createMockOnlineNT4(
        virtualTopics: [
          NT4Topic(
            name: 'Test/Display Value',
            type: NT4Type.double(),
            properties: {'persistent': true},
          ),
        ],
        virtualValues: {'Test/Display Value': 0.000001},
      );

      TextDisplayModel textDisplayModel = TextDisplayModel(
        ntConnection: ntConnection,
        preferences: preferences,
        topic: 'Test/Display Value',
        dataType: NT4Type.double(),
        period: 0.100,
      );

      expect(textDisplayModel.showSubmitButton, isTrue);
    });
    test('true if text auto submit button is true', () async {
      SharedPreferences.setMockInitialValues({
        PrefKeys.autoTextSubmitButton: true,
      });
      preferences = await SharedPreferences.getInstance();

      TextDisplayModel textDisplayModel = TextDisplayModel(
        ntConnection: ntConnection,
        preferences: preferences,
        topic: 'Test/Display Value',
        dataType: NT4Type.double(),
        period: 0.100,
      );

      expect(textDisplayModel.showSubmitButton, isTrue);
    });
    test('false if auto submit button is false', () async {
      SharedPreferences.setMockInitialValues({
        PrefKeys.autoTextSubmitButton: false,
      });
      preferences = await SharedPreferences.getInstance();

      TextDisplayModel textDisplayModel = TextDisplayModel(
        ntConnection: ntConnection,
        preferences: preferences,
        topic: 'Test/Display Value',
        dataType: NT4Type.double(),
        period: 0.100,
      );

      expect(textDisplayModel.showSubmitButton, isFalse);
    });
  });

  test('Text display to json', () {
    TextDisplayModel textDisplayModel = TextDisplayModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Display Value',
      dataType: NT4Type.double(),
      period: 0.100,
      showSubmitButton: true,
    );

    expect(textDisplayModel.toJson(), textDisplayJson);
  });

  group('Text display widget test with', () {
    bool textDisplayHasError() =>
        (find.byType(TextField).evaluate().first.widget as TextField)
            .decoration!
            .error !=
        null;
    testWidgets('double', (widgetTester) async {
      FlutterError.onError = ignoreOverflowErrors;

      TextDisplayModel textDisplayModel = TextDisplayModel(
        ntConnection: ntConnection,
        preferences: preferences,
        topic: 'Test/Display Value',
        dataType: NT4Type.double(),
        period: 0.100,
        showSubmitButton: true,
      );

      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<NTWidgetModel>.value(
              value: textDisplayModel,
              child: const TextDisplay(),
            ),
          ),
        ),
      );

      await widgetTester.pumpAndSettle();

      expect(find.text('0.000001'), findsOneWidget);
      expect(find.byTooltip('Publish Data'), findsOneWidget);
      expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await widgetTester.enterText(find.byType(TextField), '3.53');
      await widgetTester.pump(Duration.zero);
      expect(
        ntConnection.getLastAnnouncedValue('Test/Display Value'),
        0.000001,
      );
      expect(textDisplayHasError(), true);

      await widgetTester.tap(find.byIcon(Icons.exit_to_app));
      await widgetTester.pumpAndSettle();

      expect(ntConnection.getLastAnnouncedValue('Test/Display Value'), 3.53);
      expect(textDisplayHasError(), false);
    });

    testWidgets('int', (widgetTester) async {
      FlutterError.onError = ignoreOverflowErrors;

      NTConnection intNTConnection;

      TextDisplayModel textDisplayModel = TextDisplayModel(
        ntConnection: intNTConnection = createMockOnlineNT4(
          virtualTopics: [
            NT4Topic(
              name: 'Test/Display Value',
              type: NT4Type.int(),
              properties: {},
            ),
          ],
          virtualValues: {'Test/Display Value': 0},
        ),
        preferences: preferences,
        topic: 'Test/Display Value',
        dataType: NT4Type.int(),
        period: 0.100,
        showSubmitButton: true,
      );

      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<NTWidgetModel>.value(
              value: textDisplayModel,
              child: const TextDisplay(),
            ),
          ),
        ),
      );

      await widgetTester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
      expect(find.byTooltip('Publish Data'), findsOneWidget);
      expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await widgetTester.enterText(find.byType(TextField), '3000');
      await widgetTester.pump(Duration.zero);
      expect(intNTConnection.getLastAnnouncedValue('Test/Display Value'), 0);
      expect(textDisplayHasError(), true);

      await widgetTester.tap(find.byIcon(Icons.exit_to_app));
      await widgetTester.pumpAndSettle();

      expect(intNTConnection.getLastAnnouncedValue('Test/Display Value'), 3000);
      expect(textDisplayHasError(), false);
    });

    testWidgets('boolean', (widgetTester) async {
      FlutterError.onError = ignoreOverflowErrors;

      NTConnection boolNTConnection;

      TextDisplayModel textDisplayModel = TextDisplayModel(
        ntConnection: boolNTConnection = createMockOnlineNT4(
          virtualTopics: [
            NT4Topic(
              name: 'Test/Display Value',
              type: NT4Type.boolean(),
              properties: {},
            ),
          ],
          virtualValues: {'Test/Display Value': false},
        ),
        preferences: preferences,
        topic: 'Test/Display Value',
        dataType: NT4Type.boolean(),
        period: 0.100,
        showSubmitButton: true,
      );

      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<NTWidgetModel>.value(
              value: textDisplayModel,
              child: const TextDisplay(),
            ),
          ),
        ),
      );

      await widgetTester.pumpAndSettle();

      expect(find.text('false'), findsOneWidget);
      expect(find.byTooltip('Publish Data'), findsOneWidget);
      expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await widgetTester.enterText(find.byType(TextField), 'true');
      await widgetTester.pump(Duration.zero);
      expect(
        boolNTConnection.getLastAnnouncedValue('Test/Display Value'),
        isFalse,
      );
      expect(textDisplayHasError(), true);
      expect(textDisplayModel.typing, true);

      await widgetTester.tap(find.byIcon(Icons.exit_to_app));
      await widgetTester.pumpAndSettle();

      expect(
        boolNTConnection.getLastAnnouncedValue('Test/Display Value'),
        isTrue,
      );
      expect(textDisplayHasError(), false);
      expect(textDisplayModel.typing, false);
    });

    testWidgets('string', (widgetTester) async {
      FlutterError.onError = ignoreOverflowErrors;

      NTConnection stringNTConnection;

      TextDisplayModel textDisplayModel = TextDisplayModel(
        ntConnection: stringNTConnection = createMockOnlineNT4(
          virtualTopics: [
            NT4Topic(
              name: 'Test/Display Value',
              type: NT4Type.string(),
              properties: {},
            ),
          ],
          virtualValues: {'Test/Display Value': 'Hello'},
        ),
        preferences: preferences,
        topic: 'Test/Display Value',
        dataType: NT4Type.string(),
        period: 0.100,
        showSubmitButton: true,
      );

      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<NTWidgetModel>.value(
              value: textDisplayModel,
              child: const TextDisplay(),
            ),
          ),
        ),
      );

      await widgetTester.pumpAndSettle();

      expect(find.text('Hello'), findsOneWidget);
      expect(find.byTooltip('Publish Data'), findsOneWidget);
      expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await widgetTester.enterText(
        find.byType(TextField),
        'I Edited This Text',
      );
      await widgetTester.pump(Duration.zero);
      expect(
        stringNTConnection.getLastAnnouncedValue('Test/Display Value'),
        'Hello',
      );
      expect(textDisplayHasError(), true);
      expect(textDisplayModel.typing, true);

      await widgetTester.tap(find.byIcon(Icons.exit_to_app));
      await widgetTester.pumpAndSettle();

      expect(
        stringNTConnection.getLastAnnouncedValue('Test/Display Value'),
        'I Edited This Text',
      );
      expect(textDisplayHasError(), false);
      expect(textDisplayModel.typing, false);
    });

    testWidgets('int array', (widgetTester) async {
      FlutterError.onError = ignoreOverflowErrors;

      NTConnection intArrNTConnection;

      TextDisplayModel textDisplayModel = TextDisplayModel(
        ntConnection: intArrNTConnection = createMockOnlineNT4(
          virtualTopics: [
            NT4Topic(
              name: 'Test/Display Value',
              type: NT4Type.array(NT4Type.int()),
              properties: {},
            ),
          ],
          virtualValues: {
            'Test/Display Value': [0, 0],
          },
        ),
        preferences: preferences,
        topic: 'Test/Display Value',
        dataType: NT4Type.array(NT4Type.string()),
        period: 0.100,
        showSubmitButton: true,
      );

      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<NTWidgetModel>.value(
              value: textDisplayModel,
              child: const TextDisplay(),
            ),
          ),
        ),
      );

      await widgetTester.pumpAndSettle();

      expect(find.text('[0, 0]'), findsOneWidget);
      expect(find.byTooltip('Publish Data'), findsOneWidget);
      expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await widgetTester.enterText(find.byType(TextField), '[1, 2, 3]');
      await widgetTester.pump(Duration.zero);
      expect(intArrNTConnection.getLastAnnouncedValue('Test/Display Value'), [
        0,
        0,
      ]);
      expect(textDisplayHasError(), true);
      expect(textDisplayModel.typing, true);

      await widgetTester.tap(find.byIcon(Icons.exit_to_app));
      await widgetTester.pumpAndSettle();

      expect(intArrNTConnection.getLastAnnouncedValue('Test/Display Value'), [
        1,
        2,
        3,
      ]);
      expect(textDisplayHasError(), false);
      expect(textDisplayModel.typing, false);
    });

    testWidgets('boolean[]', (widgetTester) async {
      FlutterError.onError = ignoreOverflowErrors;

      NTConnection boolArrNTConnection;

      TextDisplayModel textDisplayModel = TextDisplayModel(
        ntConnection: boolArrNTConnection = createMockOnlineNT4(
          virtualTopics: [
            NT4Topic(
              name: 'Test/Display Value',
              type: NT4Type.array(NT4Type.boolean()),
              properties: {},
            ),
          ],
          virtualValues: {
            'Test/Display Value': [false, true],
          },
        ),
        preferences: preferences,
        topic: 'Test/Display Value',
        dataType: NT4Type.array(NT4Type.boolean()),
        period: 0.100,
        showSubmitButton: true,
      );

      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<NTWidgetModel>.value(
              value: textDisplayModel,
              child: const TextDisplay(),
            ),
          ),
        ),
      );

      await widgetTester.pumpAndSettle();

      expect(find.text('[false, true]'), findsOneWidget);
      expect(find.byTooltip('Publish Data'), findsOneWidget);
      expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await widgetTester.enterText(
        find.byType(TextField),
        '[true, false, true]',
      );
      await widgetTester.pump(Duration.zero);
      expect(boolArrNTConnection.getLastAnnouncedValue('Test/Display Value'), [
        false,
        true,
      ]);
      expect(textDisplayHasError(), true);
      expect(textDisplayModel.typing, true);

      await widgetTester.tap(find.byIcon(Icons.exit_to_app));
      await widgetTester.pumpAndSettle();

      expect(boolArrNTConnection.getLastAnnouncedValue('Test/Display Value'), [
        true,
        false,
        true,
      ]);
      expect(textDisplayHasError(), false);
      expect(textDisplayModel.typing, false);
    });

    testWidgets('double array', (widgetTester) async {
      FlutterError.onError = ignoreOverflowErrors;

      NTConnection doubleArrNTConnection;

      TextDisplayModel textDisplayModel = TextDisplayModel(
        ntConnection: doubleArrNTConnection = createMockOnlineNT4(
          virtualTopics: [
            NT4Topic(
              name: 'Test/Display Value',
              type: NT4Type.array(NT4Type.double()),
              properties: {},
            ),
          ],
          virtualValues: {
            'Test/Display Value': [0.0, 0.0],
          },
        ),
        preferences: preferences,
        topic: 'Test/Display Value',
        dataType: NT4Type.array(NT4Type.double()),
        period: 0.100,
        showSubmitButton: true,
      );

      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<NTWidgetModel>.value(
              value: textDisplayModel,
              child: const TextDisplay(),
            ),
          ),
        ),
      );

      await widgetTester.pumpAndSettle();

      expect(find.text('[0.0, 0.0]'), findsOneWidget);
      expect(find.byTooltip('Publish Data'), findsOneWidget);
      expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await widgetTester.enterText(find.byType(TextField), '[1.0, 2.0, 3.0]');
      await widgetTester.pump(Duration.zero);
      expect(
        doubleArrNTConnection.getLastAnnouncedValue('Test/Display Value'),
        [0.0, 0.0],
      );
      expect(textDisplayHasError(), true);
      expect(textDisplayModel.typing, true);

      await widgetTester.tap(find.byIcon(Icons.exit_to_app));
      await widgetTester.pumpAndSettle();

      expect(
        doubleArrNTConnection.getLastAnnouncedValue('Test/Display Value'),
        [1.0, 2.0, 3.0],
      );
      expect(textDisplayHasError(), false);
      expect(textDisplayModel.typing, false);
    });

    testWidgets('string array', (widgetTester) async {
      FlutterError.onError = ignoreOverflowErrors;

      NTConnection stringArrNTConnection;

      TextDisplayModel textDisplayModel = TextDisplayModel(
        ntConnection: stringArrNTConnection = createMockOnlineNT4(
          virtualTopics: [
            NT4Topic(
              name: 'Test/Display Value',
              type: NT4Type.array(NT4Type.string()),
              properties: {},
            ),
          ],
          virtualValues: {
            'Test/Display Value': ['Hello', 'There'],
          },
        ),
        preferences: preferences,
        topic: 'Test/Display Value',
        dataType: NT4Type.array(NT4Type.string()),
        period: 0.100,
        showSubmitButton: true,
      );

      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<NTWidgetModel>.value(
              value: textDisplayModel,
              child: const TextDisplay(),
            ),
          ),
        ),
      );

      await widgetTester.pumpAndSettle();

      expect(find.text('[Hello, There]'), findsOneWidget);
      expect(find.byTooltip('Publish Data'), findsOneWidget);
      expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await widgetTester.enterText(
        find.byType(TextField),
        '["I", "am", "very", "tired"]',
      );
      await widgetTester.pump(Duration.zero);
      expect(
        stringArrNTConnection.getLastAnnouncedValue('Test/Display Value'),
        ['Hello', 'There'],
      );
      expect(textDisplayHasError(), true);
      expect(textDisplayModel.typing, true);

      await widgetTester.tap(find.byIcon(Icons.exit_to_app));
      await widgetTester.pumpAndSettle();

      expect(
        stringArrNTConnection.getLastAnnouncedValue('Test/Display Value'),
        ['I', 'am', 'very', 'tired'],
      );
      expect(textDisplayHasError(), false);
      expect(textDisplayModel.typing, false);
    });

    testWidgets('no submit button', (widgetTester) async {
      FlutterError.onError = ignoreOverflowErrors;

      NTConnection stringNTConnection;

      TextDisplayModel textDisplayModel = TextDisplayModel(
        ntConnection: stringNTConnection = createMockOnlineNT4(
          virtualTopics: [
            NT4Topic(
              name: 'Test/Display Value',
              type: NT4Type.string(),
              properties: {},
            ),
          ],
          virtualValues: {'Test/Display Value': 'There isn\'t a submit button'},
        ),
        preferences: preferences,
        topic: 'Test/Display Value',
        dataType: NT4Type.string(),
        period: 0.100,
        showSubmitButton: false,
      );

      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<NTWidgetModel>.value(
              value: textDisplayModel,
              child: const TextDisplay(),
            ),
          ),
        ),
      );

      await widgetTester.pumpAndSettle();

      expect(find.text('There isn\'t a submit button'), findsOneWidget);
      expect(find.byTooltip('Publish Data'), findsNothing);
      expect(find.byIcon(Icons.exit_to_app), findsNothing);
      expect(find.byType(TextField), findsOneWidget);

      await widgetTester.enterText(
        find.byType(TextField),
        'I\'m submitting this without a button!',
      );
      await widgetTester.pump(Duration.zero);
      expect(
        stringNTConnection.getLastAnnouncedValue('Test/Display Value'),
        'There isn\'t a submit button',
      );
      expect(textDisplayHasError(), true);
      expect(textDisplayModel.typing, true);

      await widgetTester.testTextInput.receiveAction(TextInputAction.done);
      await widgetTester.pumpAndSettle();

      expect(
        stringNTConnection.getLastAnnouncedValue('Test/Display Value'),
        'I\'m submitting this without a button!',
      );
      expect(textDisplayHasError(), false);
      expect(textDisplayModel.typing, false);
    });
  });

  testWidgets('Text display edit properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    TextDisplayModel textDisplayModel = TextDisplayModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Display Value',
      dataType: NT4Type.string(),
      period: 0.100,
      showSubmitButton: true,
    );

    NTWidgetContainerModel ntContainerModel = NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.zero,
      title: 'Text Display',
      childModel: textDisplayModel,
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

    final showSubmit = find.widgetWithText(
      DialogToggleSwitch,
      'Show Submit Button',
    );

    expect(showSubmit, findsOneWidget);

    await widgetTester.tap(
      find.descendant(of: showSubmit, matching: find.byType(Switch)),
    );
    await widgetTester.pumpAndSettle();

    expect(textDisplayModel.showSubmitButton, false);
  });
}
