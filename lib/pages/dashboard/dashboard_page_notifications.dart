import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:elegant_notification/elegant_notification.dart';
import 'package:elegant_notification/resources/stacked_options.dart';

import 'package:elastic_dashboard/pages/dashboard_page.dart';
import 'package:elastic_dashboard/services/log.dart';

mixin DashboardPageNotifications on DashboardPageViewModel {
  @override
  void showJsonLoadingError(String errorMessage) {
    logger.error(errorMessage);
    Future(() {
      int lines = '\n'.allMatches(errorMessage).length + 1;

      showErrorNotification(
        title: 'Error while loading JSON data',
        message: errorMessage,
        width: 350,
        height: 100 + (lines - 1) * 10,
      );
    });
  }

  @override
  void showJsonLoadingWarning(String warningMessage) {
    logger.warning(warningMessage);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      int lines = '\n'.allMatches(warningMessage).length + 1;

      showWarningNotification(
        title: 'Warning while loading JSON data',
        message: warningMessage,
        width: 350,
        height: 100 + (lines - 1) * 10,
      );
    });
  }

  @override
  void showInfoNotification({
    required String title,
    required String message,
    Duration toastDuration = const Duration(seconds: 3, milliseconds: 500),
    double? width,
    double? height,
  }) => showNotification(
    title: title,
    message: message,
    color: const Color(0xff01CB67),
    icon: const Icon(Icons.error, color: Color(0xff01CB67)),
    toastDuration: toastDuration,
    width: width,
    height: height,
  );

  @override
  void showWarningNotification({
    required String title,
    required String message,
    Duration toastDuration = const Duration(seconds: 3, milliseconds: 500),
    double? width,
    double? height,
  }) => showNotification(
    title: title,
    message: message,
    color: Colors.yellow,
    icon: const Icon(Icons.warning, color: Colors.yellow),
    toastDuration: toastDuration,
    width: width,
    height: height,
  );

  @override
  void showErrorNotification({
    required String title,
    required String message,
    Duration toastDuration = const Duration(seconds: 3, milliseconds: 500),
    double? width,
    double? height,
  }) => showNotification(
    title: title,
    message: message,
    color: const Color(0xffFE355C),
    icon: const Icon(Icons.error, color: Color(0xffFE355C)),
    toastDuration: toastDuration,
    width: width,
    height: height,
  );

  @override
  void showNotification({
    required String title,
    required String message,
    required Color color,
    required Widget icon,
    Duration toastDuration = const Duration(seconds: 3, milliseconds: 500),
    double? width,
    double? height,
  }) {
    ColorScheme colorScheme = state!.theme.colorScheme;
    TextTheme textTheme = state!.theme.textTheme;

    ElegantNotification notification = ElegantNotification(
      background: colorScheme.surface,
      progressIndicatorBackground: colorScheme.surface,
      progressIndicatorColor: color,
      width: width,
      height: height,
      position: Alignment.bottomRight,
      toastDuration: toastDuration,
      icon: icon,
      title: Text(
        title,
        style: textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
      ),
      description: Flexible(child: Text(message)),
      stackedOptions: StackedOptions(
        key: 'notification',
        type: StackedType.above,
      ),
    );

    state!.showNotification(notification);
  }
}
