import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:titlebar_buttons/titlebar_buttons.dart';

import 'package:elastic_dashboard/services/settings.dart';

import 'package:window_manager/window_manager.dart'
    if (dart.library.js_interop) 'package:elastic_dashboard/util/stub/window_stub.dart';

/// Essentially a copy of Flutter's [AppBar] but with a non-fixed leading
/// width and all non-necessary features removed for copying simplicity
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String titleText;
  final Color? appBarColor;
  final VoidCallback? onWindowClose;
  final Widget leading;

  static const ThemeType buttonType = ThemeType.materia;

  static const double windowButtonSize = 24;

  static double? titleSize;

  late final Widget trailing = Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (!kIsWeb) ...[
        InkWell(
          canRequestFocus: false,
          onTap: () async => await windowManager.minimize(),
          child: const AbsorbPointer(
            child: DecoratedMinimizeButton(
              width: windowButtonSize,
              height: windowButtonSize,
              type: buttonType,
              onPressed: null,
            ),
          ),
        ),
        InkWell(
          canRequestFocus: false,
          onTap: () async {
            if (!Settings.isWindowMaximizable) {
              return;
            }

            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
          child: const AbsorbPointer(
            child: DecoratedMaximizeButton(
              width: windowButtonSize,
              height: windowButtonSize,
              type: buttonType,
              onPressed: null,
            ),
          ),
        ),
        InkWell(
          canRequestFocus: false,
          hoverColor: Colors.red,
          onTap: () async {
            if (onWindowClose == null) {
              await windowManager.close();
            } else {
              onWindowClose!.call();
            }
          },
          child: const AbsorbPointer(
            child: DecoratedCloseButton(
              width: windowButtonSize,
              height: windowButtonSize,
              type: buttonType,
              onPressed: null,
            ),
          ),
        ),
      ],
    ],
  );

  late final Widget title = LayoutBuilder(
    builder: (context, constraints) => (constraints.maxWidth >= titleSize!)
        ? Text(
            titleText,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
            overflow: TextOverflow.clip,
          )
        : const SizedBox(),
  );

  CustomAppBar({
    super.key,
    this.titleText = 'Elastic',
    this.appBarColor,
    this.onWindowClose,
    required this.leading,
  });

  @override
  Widget build(BuildContext context) {
    titleSize ??= (TextPainter(
      text: TextSpan(
        text: titleText,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout()).size.width;

    return Material(
      color: appBarColor ?? const Color.fromARGB(255, 25, 25, 25),
      type: MaterialType.canvas,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          const _WindowDragArea(),
          Material(
            type: MaterialType.transparency,
            child: Align(
              alignment: Alignment.topCenter,
              child: ClipRect(
                child: NavigationToolbar(
                  centerMiddle: true,
                  leading: leading,
                  middle: _WindowDragArea(child: title),
                  trailing: trailing,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(36);
}

class _WindowDragArea extends StatelessWidget {
  final Widget? child;

  const _WindowDragArea({this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onPanStart: (details) {
      if (!Settings.isWindowDraggable) {
        return;
      }

      windowManager.startDragging();
    },
    onDoubleTap: () async {
      if (!Settings.isWindowMaximizable) {
        return;
      }

      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    },
    child: child ?? Container(),
  );
}
