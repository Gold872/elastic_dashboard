import 'dart:typed_data';

class SwerveModuleStateStruct {
  static const int length = 16;

  final double speed;
  final double angle;

  const SwerveModuleStateStruct({this.speed = 0, this.angle = 0});

  factory SwerveModuleStateStruct.valueFromBytes(
    Uint8List value, [
    int start = 0,
  ]) {
    ByteData view = ByteData.view(value.buffer, start);

    int length = view.lengthInBytes;

    double speed = 0.0;
    double angle = 0.0;

    if (length >= 8) {
      speed = view.getFloat64(0, Endian.little);
    }
    if (length >= 16) {
      angle = view.getFloat64(8, Endian.little);
    }

    return SwerveModuleStateStruct(speed: speed, angle: angle);
  }

  static List<SwerveModuleStateStruct> listFromBytes(Uint8List value) {
    ByteData view = ByteData.view(value.buffer);

    int viewLength = view.lengthInBytes;

    int arraySize = viewLength ~/ length;

    List<SwerveModuleStateStruct> poseList = [];

    for (int i = 0; i < arraySize; i++) {
      if (i * length + length > viewLength) {
        break;
      }

      poseList.add(SwerveModuleStateStruct.valueFromBytes(value, i * length));
    }

    return poseList;
  }
}
