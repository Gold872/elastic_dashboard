import 'package:flutter_test/flutter_test.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt_widget_registry.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/differential_drive.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

import '../../../test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> differentialDriveJson = {
    'topic': 'Test/Differential Drive',
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
          name: 'Test/Differential Drive/Left Motor Speed',
          type: NT4Type.float(),
          properties: {},
        ),
        NT4Topic(
          name: 'Test/Differential Drive/Right Motor Speed',
          type: NT4Type.float(),
          properties: {},
        ),
      ],
      virtualValues: {
        'Test/Differential Drive/Left Motor Speed': 0.50,
        'Test/Differential Drive/Right Motor Speed': 0.50,
      },
    );
  });

  test('Differential drive from json', () {
    NTWidgetModel differentialDriveModel =
        NTWidgetRegistry.buildNTModelFromJson(
          ntConnection,
          preferences,
          'DifferentialDrive',
          differentialDriveJson,
        );

    expect(differentialDriveModel.type, 'DifferentialDrive');
    expect(differentialDriveModel.runtimeType, DifferentialDriveModel);
  });

  test('Differential drive to json', () {
    DifferentialDriveModel differentialDriveModel = DifferentialDriveModel(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: 'Test/Differential Drive',
      period: 0.100,
    );

    expect(differentialDriveModel.toJson(), differentialDriveJson);
  });

  testWidgets('Differential drive widget test', (widgetTester) async {
    FlutterError.onError = ignoreOverflowErrors;

    NTWidgetModel differentialDriveModel =
        NTWidgetRegistry.buildNTModelFromJson(
          ntConnection,
          preferences,
          'DifferentialDrive',
          differentialDriveJson,
        );

    await widgetTester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<NTWidgetModel>.value(
            value: differentialDriveModel,
            child: const DifferentialDrive(),
          ),
        ),
      ),
    );

    await widgetTester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(LinearGauge), findsNWidgets(2));
    expect(find.byType(Pointer), findsNWidgets(2));

    await widgetTester.drag(
      find.byType(Pointer).first,
      const Offset(0.0, 200.0),
    );
    await widgetTester.pumpAndSettle();

    expect(
      ntConnection.getLastAnnouncedValue(
        'Test/Differential Drive/Left Motor Speed',
      ),
      isNot(0.50),
    );
    expect(
      ntConnection.getLastAnnouncedValue(
        'Test/Differential Drive/Right Motor Speed',
      ),
      0.50,
    );

    await widgetTester.drag(
      find.byType(Pointer).last,
      const Offset(0.0, 300.0),
    );
    await widgetTester.pumpAndSettle();

    expect(
      ntConnection.getLastAnnouncedValue(
        'Test/Differential Drive/Right Motor Speed',
      ),
      isNot(0.50),
    );
  });
}
