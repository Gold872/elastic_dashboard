// Source: https://gist.github.com/ardera/25a8c81a54fb37b0dc750d383caac5d9

import 'package:material_ui/material_ui.dart';

class PixelRatioOverride extends StatelessWidget {
  final double? dpiOverride;
  final Widget child;

  const PixelRatioOverride({
    super.key,
    required this.dpiOverride,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (dpiOverride == null) {
      return child;
    }

    final MediaQueryData mediaQueryData = MediaQuery.of(context);

    final ratio = dpiOverride! / mediaQueryData.devicePixelRatio;

    if (ratio == 1) {
      return child;
    }

    final Size newScreenSize = mediaQueryData.size / ratio;

    if (ratio < 1) {
      return FractionallySizedBox(
        alignment: Alignment.topLeft,
        widthFactor: 1 / ratio,
        heightFactor: 1 / ratio,
        child: Transform.scale(
          alignment: Alignment.topLeft,
          scale: ratio,
          child: MediaQuery(
            data: mediaQueryData.copyWith(size: newScreenSize),
            child: child,
          ),
        ),
      );
    } else {
      return Transform.scale(
        alignment: Alignment.topCenter,
        scale: ratio,
        child: FractionallySizedBox(
          alignment: Alignment.topCenter,
          widthFactor: 1 / ratio,
          heightFactor: 1 / ratio,
          child: MediaQuery(
            data: mediaQueryData.copyWith(size: newScreenSize),
            child: child,
          ),
        ),
      );
    }
  }
}
