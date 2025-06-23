import 'dart:io';
import 'dart:typed_data';

enum IPAddressMode {
  driverStation('Driver Station', 0),
  teamNumber('Team Number (10.TE.AM.2)', 1),
  systemCoremDNS('SystemCore mDNS', 2),
  systemCoreAP('SystemCore Wifi', 5),
  localhost('localhost (127.0.0.1)', 3),
  custom('Custom', 4);

  const IPAddressMode(this.displayName, this.id);

  final String displayName;
  final int id;

  @override
  String toString() => displayName;

  static IPAddressMode fromID(int? index) {
    if (index == null || index >= values.length) {
      return driverStation;
    }

    return values.firstWhere((e) => e.id == index);
  }
}

class IPAddressUtil {
  static bool isTeamNumber(String ipAddress) => int.tryParse(ipAddress) != null;

  static String teamNumberToIP(int teamNumber) {
    String te = (teamNumber ~/ 100).toString();
    String am = (teamNumber % 100).toString().padLeft(2, '0');

    return '10.$te.$am.2';
  }

  static String getIpFromInt32Value(int value) =>
      InternetAddress.fromRawAddress(
        (ByteData(4)..setInt32(0, value)).buffer.asUint8List(),
      ).address;
}
