import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/draggable_nt_widget_container.dart';
import 'package:elastic_dashboard/widgets/draggable_containers/models/nt_widget_container_model.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/single_topic/match_time.dart';

import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> matchTimeJson = {
    'topic': 'Test/Double Value',
    'data_type': 'double',
    'period': 0.100,
    'time_display_mode': 'Minutes and Seconds',
    'red_start_time': 15,
    'yellow_start_time': 25.0,
  };

  Finder coloredText(String text, Color color) => find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        widget.data == text &&
        widget.style != null &&
        widget.style!.color != null &&
        widget.style!.color!.toARGB32() == color.toARGB32(),
  );

  late SharedPreferences preferences;
  late NTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4(
      virtualTopics: [
        NT4Topic(
          name: 'Test/Double Value',
          type: NT4Type.double(),
          properties: {},
        ),
      ],
      virtualValues: {'Test/Double Value': 96.0},
    );
  });

  test('Match time from json', () {
    NTWidgetModel matchTimeModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Match Time',
      matchTimeJson,
    );

    expect(matchTimeModel.type, 'Match Time');
    expect(matchTimeModel.runtimeType, MatchTimeModel);
    expect(
      matchTimeModel.getAvailableDisplayTypes(),
      unorderedEquals([
        'Text Display',
        'Number Bar',
        'Number Slider',
        'Graph',
        'Voltage View',
        'Radial Gauge',
        'Match Time',
        'Large Text Display',
      ]),
    );

    if (matchTimeModel is! MatchTimeModel) {
      return;
    }

    expect(matchTimeModel.timeDisplayMode, 'Minutes and Seconds');
    expect(matchTimeModel.redStartTime, 15);
    expect(matchTimeModel.yellowStartTime, 25);
  });

  test('Match time to json', () {
    MatchTimeModel matchTimeModel = MatchTimeModel(
      ntConnection: ntConnection,
      preferences: preferences,
      ntStructMeta: null,
      topic: 'Test/Double Value',
      dataType: NT4Type.double(),
      period: 0.100,
      timeDisplayMode: 'Minutes and Seconds',
      redStartTime: 15,
      yellowStartTime: 25,
    );

    expect(matchTimeModel.toJson(), matchTimeJson);
  });

  testWidgets('Match time widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel matchTimeModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Match Time',
      matchTimeJson,
    );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: matchTimeModel as MatchTimeModel,
            child: const MatchTimeWidget(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.text('1:36'), findsOneWidget);
    expect(coloredText('1:36', Colors.blue), findsOneWidget);

    ntConnection.updateDataFromTopicName('Test/Double Value', 55.0);
    matchTimeModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(find.text('0:55'), findsOneWidget);
    expect(coloredText('0:55', Colors.green), findsOneWidget);

    ntConnection.updateDataFromTopicName('Test/Double Value', 22.0);
    matchTimeModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(find.text('0:22'), findsOneWidget);
    expect(coloredText('0:22', Colors.yellow), findsOneWidget);

    ntConnection.updateDataFromTopicName('Test/Double Value', 13.0);
    matchTimeModel.refresh();
    await widgetTester.pumpAndSettle();

    expect(find.text('0:13'), findsOneWidget);
    expect(coloredText('0:13', Colors.red), findsOneWidget);

    ntConnection.updateDataFromTopicName('Test/Double Value', 96.0);
    matchTimeModel.timeDisplayMode = 'Seconds Only';
    await widgetTester.pumpAndSettle();

    expect(find.text('96'), findsOneWidget);
    expect(coloredText('96', Colors.blue), findsOneWidget);
  });

  testWidgets('Match time edit properties', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    MatchTimeModel matchTimeModel = NTWidgetRegistry.buildNTModelFromJson(
      ntConnection,
      preferences,
      'Match Time',
      matchTimeJson,
    ) as MatchTimeModel;

    NTWidgetContainerModel ntContainerModel = NTWidgetContainerModel(
      ntConnection: ntConnection,
      preferences: preferences,
      initialPosition: Rect.zero,
      title: 'Match Time',
      childModel: matchTimeModel,
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

    final timeDisplayMode = find.text('Time Display Mode');
    final redStartTime = find.widgetWithText(DialogTextInput, 'Red Start Time');
    final yellowStartTime = find.widgetWithText(
      DialogTextInput,
      'Yellow Start Time',
    );

    expect(timeDisplayMode, findsOneWidget);
    expect(redStartTime, findsOneWidget);
    expect(yellowStartTime, findsOneWidget);

    expect(find.byType(DialogDropdownChooser<String>), findsNWidgets(2));
    await widgetTester.tap(
      find.byWidget(
        find
            .byType(DialogDropdownChooser<String>)
            .evaluate()
            .elementAt(1)
            .widget,
      ),
    );
    await widgetTester.pumpAndSettle();

    expect(find.text('Seconds Only'), findsOneWidget);
    await widgetTester.tap(find.text('Seconds Only'));
    await widgetTester.pumpAndSettle();

    expect(matchTimeModel.timeDisplayMode, 'Seconds Only');

    await widgetTester.enterText(redStartTime, '1');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(matchTimeModel.redStartTime, 1);

    await widgetTester.enterText(yellowStartTime, '15');
    await widgetTester.testTextInput.receiveAction(TextInputAction.done);

    await widgetTester.pumpAndSettle();

    expect(matchTimeModel.yellowStartTime, 15);
  });
}
