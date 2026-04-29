import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';

import 'package:elastic_dashboard/services/log.dart';

class FieldImages {
  static List<Field> fields = [];

  static Field? getFieldFromGame(String game) {
    if (fields.isEmpty) {
      return null;
    }

    Field? field = fields.firstWhereOrNull((element) => element.game == game);
    if (field == null) {
      return null;
    }

    if (field.instanceCount == 0) {
      field.loadFieldImage();
    }
    field.instanceCount++;

    return field;
  }

  static bool hasField(String game) => fields.map((e) => e.game).contains(game);

  static Future<void> loadFields(String directory) async {
    logger.info('Loading fields');
    AssetManifest assetManifest = await AssetManifest.loadFromAssetBundle(
      rootBundle,
    );

    List<String> filePaths = assetManifest
        .listAssets()
        .where((String key) => key.contains(directory) && key.contains('.json'))
        .toList();

    filePaths.sort();

    for (String file in filePaths.reversed) {
      await loadField(file);
    }
  }

  static Future loadField(String filePath) async {
    logger.trace('Loading field at $filePath');
    String jsonString = await rootBundle.loadString(filePath);

    Map<String, dynamic> jsonData = jsonDecode(jsonString);

    fields.add(Field(jsonData: jsonData));
  }
}

enum CoordinateSystem {
  unknown(jsonKey: 'default', displayName: 'Default'),

  /// Standard WPILib coordinate system pre-2027
  ///
  /// Origin at blue alliance corner, positive X going towards the left of the image,
  /// positive Y going towards the bottom of image
  wallBlue(jsonKey: 'wall_blue', displayName: 'Blue Wall (WPILib Pre-2027)'),

  /// Standard FTC coordinate system pre-2028
  ///
  /// Origin at center of field, positive X going along the red wall towards the bottom
  /// of the image, positive Y going towards the right of the image, away from red wall
  centerRotated(
    jsonKey: 'center_rotated',
    displayName: 'Center Rotated (FTC Pre-2028)',
  ),

  /// Standard WPILib coordinate system 2027+
  ///
  /// Origin at center of field, positive X going towards the blue alliance wall (right of image),
  /// positive Y going towards the scoring table (top of image)
  center(jsonKey: 'center', displayName: 'Center (WPILib 2027+)');

  final String jsonKey;
  final String displayName;

  const CoordinateSystem({required this.jsonKey, required this.displayName});

  static CoordinateSystem fromJson(String key) =>
      CoordinateSystem.values.firstWhere(
        (e) => e.jsonKey == key,
        orElse: () => CoordinateSystem.center,
      );
}

class Field {
  final Map<String, dynamic> jsonData;

  late String? game;
  late String? sourceURL;
  late String? program;

  late CoordinateSystem coordinateSystem;

  bool get isFrc => program != null && program == 'FRC';

  bool get isFtc => program != null && program == 'FTC';

  int? fieldImageWidth;
  int? fieldImageHeight;

  Size? get fieldImageSize =>
      (fieldImageWidth != null && fieldImageHeight != null)
      ? Size(fieldImageWidth!.toDouble(), fieldImageHeight!.toDouble())
      : null;

  late double fieldWidthMeters;
  late double fieldHeightMeters;

  late Offset topLeftCorner;
  late Offset bottomRightCorner;

  Offset get center => (fieldImageLoaded)
      ? Offset(
              bottomRightCorner.dx - topLeftCorner.dx,
              bottomRightCorner.dy - topLeftCorner.dy,
            ) /
            2
      : const Offset(0, 0);

  late Image fieldImage;

  int instanceCount = 0;
  bool fieldImageLoaded = false;

  late int pixelsPerMeterHorizontal;
  late int pixelsPerMeterVertical;

  Field({required this.jsonData}) {
    init();
  }

  void init() {
    fieldImageWidth = 3600;
    fieldImageHeight = 1400;

    game = jsonData['game'];
    sourceURL = jsonData['source_url'];
    program = jsonData['program'];

    coordinateSystem = CoordinateSystem.fromJson(jsonData['coordinate_system']);

    fieldWidthMeters = jsonData['field_size'][0];
    fieldHeightMeters = jsonData['field_size'][1];

    topLeftCorner = Offset(
      (jsonData['field_corners']['top_left'][0] as int).toDouble(),
      (jsonData['field_corners']['top_left'][1] as int).toDouble(),
    );

    bottomRightCorner = Offset(
      (jsonData['field_corners']['bottom_right'][0] as int).toDouble(),
      (jsonData['field_corners']['bottom_right'][1] as int).toDouble(),
    );

    double fieldWidthPixels = bottomRightCorner.dx - topLeftCorner.dx;
    double fieldHeightPixels = bottomRightCorner.dy - topLeftCorner.dy;

    pixelsPerMeterHorizontal = (fieldWidthPixels / fieldWidthMeters).round();
    pixelsPerMeterVertical = (fieldHeightPixels / fieldHeightMeters).round();
  }

  void loadFieldImage() {
    logger.debug('Loading field image for $game');
    fieldImage = Image.asset(jsonData['field_image'], fit: BoxFit.contain);
    fieldImage.image
        .resolve(ImageConfiguration.empty)
        .addListener(
          ImageStreamListener((image, synchronousCall) {
            logger.trace('Initializing image width and height for $game');
            fieldImageWidth = image.image.width;
            fieldImageHeight = image.image.height;

            fieldImageLoaded = true;
          }),
        );
  }

  Future<void> dispose() async {
    logger.debug('Soft disposing field: $game');
    instanceCount--;
    logger.trace('New instance count for $game: $instanceCount');
    if (instanceCount <= 0) {
      logger.debug('Instance count for $game is 0, deleting field from memory');
      await fieldImage.image.evict();
      imageCache.clear();
      fieldImageLoaded = false;
    }
  }
}
