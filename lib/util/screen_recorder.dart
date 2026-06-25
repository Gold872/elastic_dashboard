import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';

class ScreenRecorder {
  static Future<void> start() async {
    print('Starting screen recording...');

    final String ffmpegCommand =
        '-y -f gdigrab -framerate 30 -i desktop -c:v mpeg4 -q:v 3 -pix_fmt yuv420p -movflags frag_keyframe+empty_moov C:\\Users\\Public\\Videos\\${_getFileName()}';

    await FFmpegKit.executeAsync(ffmpegCommand);
  }

  static void stopAndWait() {
    print('Stopping screen recording...');

    Future<void>.delayed(const Duration(seconds: 1), () {
      FFmpegKitExtended.cancelAllSessions();
    });
  }

  static String _getFileName() {
    final DateTime now = DateTime.now();
    return 'screen_record_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}.mp4';
  }
}
