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

class Field {
  final Map<String, dynamic> jsonData;

  late String? game;
  late String? sourceURL;
  late String? program;

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
    sourceURL = jsonData['source-url'];
    program = jsonData['program'];

    fieldWidthMeters = jsonData['field-size'][0];
    fieldHeightMeters = jsonData['field-size'][1];

    topLeftCorner = Offset(
      (jsonData['field-corners']['top-left'][0] as int).toDouble(),
      (jsonData['field-corners']['top-left'][1] as int).toDouble(),
    );

    bottomRightCorner = Offset(
      (jsonData['field-corners']['bottom-right'][0] as int).toDouble(),
      (jsonData['field-corners']['bottom-right'][1] as int).toDouble(),
    );

    double fieldWidthPixels = bottomRightCorner.dx - topLeftCorner.dx;
    double fieldHeightPixels = bottomRightCorner.dy - topLeftCorner.dy;

    pixelsPerMeterHorizontal = (fieldWidthPixels / fieldWidthMeters).round();
    pixelsPerMeterVertical = (fieldHeightPixels / fieldHeightMeters).round();
  }

  void loadFieldImage() {
    logger.debug('Loading field image for $game');
    fieldImage = Image.asset(jsonData['field-image'], fit: BoxFit.contain);
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
