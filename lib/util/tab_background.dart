import 'dart:convert';
import 'dart:typed_data';

import 'package:dot_cast/dot_cast.dart';

/// An image drawn behind the widgets of a tab.
///
/// The position and size are in grid pixels (the same units as widget
/// positions), so the image stays aligned with the widgets placed over it.
/// The image itself is embedded in the layout as base64, which keeps layouts
/// portable between computers, the web version, and remote layout downloads.
class TabBackground {
  static const int maxImageBytes = 1024 * 1024;

  final String imageData;
  final Uint8List imageBytes;

  final double x;
  final double y;

  /// If null, the image's own width is used
  final double? width;

  /// If null, the image's own height is used
  final double? height;

  final double opacity;

  TabBackground._({
    required this.imageData,
    required this.imageBytes,
    this.x = 0.0,
    this.y = 0.0,
    this.width,
    this.height,
    this.opacity = 1.0,
  });

  TabBackground.fromBytes(
    Uint8List bytes, {
    double x = 0.0,
    double y = 0.0,
    double? width,
    double? height,
    double opacity = 1.0,
  }) : this._(
         imageData: base64Encode(bytes),
         imageBytes: bytes,
         x: x,
         y: y,
         width: width,
         height: height,
         opacity: opacity.clamp(0.0, 1.0),
       );

  /// Returns null if [jsonData] does not contain a valid image.
  static TabBackground? fromJson(
    Map<String, dynamic> jsonData, {
    Function(String warningMessage)? onJsonLoadingWarning,
  }) {
    String? imageData = tryCast(jsonData['image']);

    if (imageData == null || imageData.isEmpty) {
      onJsonLoadingWarning?.call(
        'Tab background does not specify an image, ignoring background.',
      );
      return null;
    }

    Uint8List imageBytes;
    try {
      imageBytes = base64Decode(imageData);
    } on FormatException {
      onJsonLoadingWarning?.call(
        'Tab background image is not valid base64, ignoring background.',
      );
      return null;
    }

    double? width = tryCast<num>(jsonData['width'])?.toDouble();
    double? height = tryCast<num>(jsonData['height'])?.toDouble();

    return TabBackground._(
      imageData: imageData,
      imageBytes: imageBytes,
      x: tryCast<num>(jsonData['x'])?.toDouble() ?? 0.0,
      y: tryCast<num>(jsonData['y'])?.toDouble() ?? 0.0,
      width: (width != null && width > 0) ? width : null,
      height: (height != null && height > 0) ? height : null,
      opacity: (tryCast<num>(jsonData['opacity'])?.toDouble() ?? 1.0).clamp(
        0.0,
        1.0,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'image': imageData,
    'x': x,
    'y': y,
    'width': ?width,
    'height': ?height,
    'opacity': opacity,
  };

  TabBackground copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? opacity,
  }) => TabBackground._(
    imageData: imageData,
    imageBytes: imageBytes,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    opacity: (opacity ?? this.opacity).clamp(0.0, 1.0),
  );
}
