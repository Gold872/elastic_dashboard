import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elastic_dashboard/widgets/network_tree/networktables_tree_row.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/swerve_drive.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

import '../../test_util.dart';
import '../../test_util.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late MockNTConnection ntConnection;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();

    ntConnection = createMockOnlineNT4();
    // Both tables below have a .type of SwerveDrive.
    when(
      ntConnection.subscribeAndRetrieveData<String>(
        any,
        period: anyNamed('period'),
        timeout: anyNamed('timeout'),
      ),
    ).thenAnswer((_) async => 'SwerveDrive');
  });

  NetworkTableTreeRow table(String topic, List<String> rows) {
    NetworkTableTreeRow row = NetworkTableTreeRow(
      ntConnection: ntConnection,
      preferences: preferences,
      topic: topic,
      rowName: topic.split('/').last,
    );
    for (String name in rows) {
      row.createNewRow(topic: '$topic/$name', name: name);
    }
    return row;
  }

  test(
    'A YAMS swerve drive with a .type of SwerveDrive is a YAGSL Swerve Drive',
    () async {
      NetworkTableTreeRow swerve = table('/Mechanisms/swerve', [
        '.type',
        'states',
        'gyro',
        'pose',
        'maxModuleVelocity',
      ]);
      swerve
          .getRow('states')
          .createNewRow(
            topic: '/Mechanisms/swerve/states/current',
            name: 'current',
          );

      NTWidgetModel? model = await swerve.getPrimaryWidget();

      expect(model, isA<SwerveDriveModel>());
      expect(model!.topic, '/Mechanisms/swerve');
    },
  );
}
