// Lots of inspiration taken from 3015 PathPlanner's logging feature
// https://github.com/mjansen4857/pathplanner/blob/main/lib/services/log.dart

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart'
    if (dart.library.js_interop) 'package:elastic_dashboard/util/stub/path_stub.dart';

class Log {
  static final DateFormat _dateFormat = DateFormat('HH:mm:ss.S');

  static Log instance = Log._internal();

  Log._internal();

  Logger? _logger;

  Future<void> initialize() async {
    Directory logPath = await getApplicationSupportDirectory();
    File logFile = File(join(logPath.path, 'elastic-log.txt'));
    _logger = Logger(
      printer: HybridPrinter(
        SimplePrinter(colors: kDebugMode),
        error: PrettyPrinter(methodCount: 5, colors: kDebugMode),
        warning: PrettyPrinter(methodCount: 5, colors: kDebugMode),
      ),
      output: MultiOutput([
        ConsoleOutput(),
        if (kReleaseMode && !kIsWeb) FileOutput(file: logFile),
      ]),
      filter: ProductionFilter(),
    );
  }

  void log(Level level, dynamic message, [dynamic error, StackTrace? trace]) {
    if (Logger.level.value > level.value) {
      return;
    }

    _logger?.log(
      level,
      '[${_dateFormat.format(DateTime.now())}]:  $message',
      error: error,
      stackTrace: trace,
    );
  }

  void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    log(Level.info, message, error, stackTrace);
  }

  void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    log(Level.error, message, error, stackTrace);
  }

  void warning(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    log(Level.warning, message, error, stackTrace);
  }

  void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    log(Level.debug, message, error, stackTrace);
  }

  void trace(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    log(Level.trace, message, error, stackTrace);
  }
}

Log get logger => Log.instance;
