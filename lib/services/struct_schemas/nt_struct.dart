import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:collection/collection.dart';

import 'package:elastic_dashboard/services/log.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';

extension Uint8ListToBitArray on Uint8List {
  List<bool> toBitArray() {
    List<bool> output = [];

    for (int value in this) {
      for (int shift = 0; shift < 8; shift++) {
        output.add(((1 << shift) & value) > 0);
      }
    }

    return output;
  }
}

extension BitArrayToUint8List on List<bool> {
  Uint8List toUint8List() {
    Uint8List output = Uint8List((length / 8).ceil());

    for (int i = 0; i < length; i++) {
      if (this[i]) {
        int byte = (i / 8).floor();
        int bit = i % 8;
        output[byte] |= 1 << bit;
      }
    }

    return output;
  }
}

extension ByteDataWebUtil on ByteData {
  @visibleForTesting
  int extractWebInt64(int byteOffset, [Endian endian = Endian.big]) {
    late int hi;
    late int lo;

    if (endian == Endian.big) {
      hi = getInt32(byteOffset, endian);
      lo = getUint32(byteOffset + 4, endian);
    } else {
      hi = getInt32(byteOffset + 4, endian);
      lo = getUint32(byteOffset, endian);
    }

    return (hi * 0x100000000) + lo;
  }

  @visibleForTesting
  int extractWebUint64(int byteOffset, [Endian endian = Endian.big]) {
    late int hi;
    late int lo;

    if (endian == Endian.big) {
      hi = getUint32(byteOffset, endian);
      lo = getUint32(byteOffset + 4, endian);
    } else {
      hi = getUint32(byteOffset + 4, endian);
      lo = getUint32(byteOffset, endian);
    }

    return (hi * 0x100000000) + lo;
  }

  int getInt64Web(int byteOffset, [Endian endian = Endian.big]) {
    const bool isWeb = bool.fromEnvironment('dart.library.html');

    if (isWeb) {
      return extractWebInt64(byteOffset, endian);
    }
    return getInt64(byteOffset, endian);
  }

  int getUint64Web(int byteOffset, [Endian endian = Endian.big]) {
    const bool isWeb = bool.fromEnvironment('dart.library.html');

    if (isWeb) {
      return extractWebUint64(byteOffset, endian);
    }

    return getUint64(byteOffset, endian);
  }
}

class SchemaParseException implements Exception {
  SchemaParseException([Object? message]);
}

/// This class is a singleton that manages the schemas of NTStructs.
/// It allows adding new schemas and retrieving existing ones by name.
/// It also provides a method to parse a schema string into a list of field schemas.
class SchemaManager {
  final Map<String, String> _uncompiledSchemas = {};
  final Map<String, NTStructSchema> _schemas = {};

  NTStructSchema? getSchema(String name) {
    if (name.contains(':')) {
      name = name.split(':')[1];
    }

    return _schemas[name];
  }

  /// Processes a new schema from raw bytes and adds it into the list of known structs
  ///
  /// If processing this schema results in a new schema being updated, it will return
  /// true. Calling this method can result in 1 or more schemas being compiled, due to
  /// some schemas depending on others
  bool processNewSchema(String name, List<int> rawData) {
    String schema = utf8.decode(rawData);
    if (name.contains(':')) {
      name = name.split(':').last;
    }

    _uncompiledSchemas[name] = schema;

    bool compiledAny = false;

    while (_uncompiledSchemas.isNotEmpty) {
      bool compiled = false;

      List<String> newlyCompiled = [];

      for (final uncompiled in _uncompiledSchemas.entries) {
        if (!_schemas.containsKey(uncompiled.key)) {
          bool success = _addStringSchema(uncompiled.key, uncompiled.value);
          if (success) {
            newlyCompiled.add(uncompiled.key);
            compiledAny = true;
          }
          compiled = compiled || success;
        }
      }

      _uncompiledSchemas.removeWhere((k, v) => newlyCompiled.contains(k));

      if (!compiled) {
        break;
      }
    }

    return compiledAny;
  }

  void _addSchema(String name, NTStructSchema schema) {
    if (name.contains(':')) {
      name = name.split(':')[1];
    }

    if (_schemas.containsKey(name)) {
      return;
    }

    logger.debug('Adding schema: $name, $schema');

    _schemas[name] = schema;
  }

  /// Parses and adds a schema from a String, returns whether or not
  /// the schema was successfully parsed
  bool _addStringSchema(String name, String schema) {
    if (name.contains(':')) {
      name = name.split(':')[1];
    }
    name = name.trim();

    if (_schemas.containsKey(name)) {
      return true;
    }

    try {
      NTStructSchema parsedSchema = NTStructSchema.parse(
        name: name,
        schema: schema,
        knownSchemas: _schemas,
      );
      _addSchema(name, parsedSchema);
      return true;
    } catch (err) {
      logger.info('Failed to parse schema: $name - $schema');
      return false;
    }
  }

  bool isStruct(String name) {
    name = name.trim();
    if (name.contains(':')) {
      name = name.split(':')[1];
    }

    return _schemas.containsKey(name);
  }
}

enum StructValueType {
  bool('bool', 8),
  char('char', 8),
  int8('int8', 8),
  int16('int16', 16),
  int32('int32', 32),
  int64('int64', 64),
  uint8('uint8', 8),
  uint16('uint16', 16),
  uint32('uint32', 32),
  uint64('uint64', 64),
  float('float', 32),
  float32('float32', 32),
  double('double', 64),
  float64('float64', 64),
  struct('struct', 0);

  const StructValueType(this.name, this.maxBits);

  final String name;
  final int maxBits;

  static StructValueType parse(String type) =>
      StructValueType.values.firstWhereOrNull((e) => e.name == type) ??
      StructValueType.struct;

  /// The [NT4Type] equivalent of the struct type
  NT4Type get ntType => switch (this) {
    StructValueType.bool => NT4Type.boolean(),
    StructValueType.char ||
    StructValueType.int8 ||
    StructValueType.int16 ||
    StructValueType.int32 ||
    StructValueType.int64 ||
    StructValueType.uint8 ||
    StructValueType.uint16 ||
    StructValueType.uint32 ||
    StructValueType.uint64 => NT4Type.int(),
    StructValueType.float ||
    StructValueType.float32 ||
    StructValueType.double ||
    StructValueType.float64 => NT4Type.double(),
    StructValueType.struct => NT4Type.struct(name),
  };

  @override
  String toString() => name;
}

/// Data representing a field schema in an NTStruct
///
/// Contains the information needed to decode the data for a specific
/// field from the full bytes of a struct.
class NTFieldSchema {
  final String fieldName;
  final String type;
  final NTStructSchema? subSchema;
  final int bitLength;
  final int? arrayLength;
  final Map<int, String>? enumData;
  final (int start, int end) bitRange;
  final bool isBitField;

  StructValueType get valueType => StructValueType.parse(type);

  NT4Type get ntType {
    NT4Type innerType = valueType != StructValueType.struct
        ? valueType.ntType
        : NT4Type.struct(type);

    // If there's an enum map, use the string alias for an enum type
    if (enumData != null) {
      innerType = NT4Type(dataType: NT4DataType.string, name: 'enum');
    }

    if (isArray) {
      return NT4Type.array(innerType);
    }
    return innerType;
  }

  bool get isArray => arrayLength != null;

  NTFieldSchema({
    required this.fieldName,
    required this.type,
    required this.bitLength,
    this.arrayLength,
    this.subSchema,
    this.enumData,
    required this.bitRange,
    required this.isBitField,
  });

  NTFieldSchema copyWith({
    String? fieldName,
    String? type,
    NTStructSchema? subSchema,
    int? bitLength,
    int? arrayLength,
    Map<int, String>? enumData,
    (int start, int end)? bitRange,
    bool? isBitField,
  }) => NTFieldSchema(
    fieldName: fieldName ?? this.fieldName,
    type: type ?? this.type,
    subSchema: subSchema ?? this.subSchema,
    bitLength: bitLength ?? this.bitLength,
    arrayLength: arrayLength ?? this.arrayLength,
    enumData: enumData ?? this.enumData,
    bitRange: bitRange ?? this.bitRange,
    isBitField: isBitField ?? this.isBitField,
  );

  factory NTFieldSchema.parse({
    required int start,
    required String schemaString,
    required Map<String, NTStructSchema> knownSchemas,
  }) {
    Map<int, String>? enumData;
    schemaString = schemaString.trim();
    if (schemaString.startsWith('enum') || schemaString.startsWith('{')) {
      int enumStart = schemaString.indexOf('{');
      int enumEnd = schemaString.indexOf('}');

      if (enumStart == -1 || enumEnd == -1 || enumEnd < enumStart) {
        throw SchemaParseException('Invalid enum syntax: $schemaString');
      }

      enumData = {};
      String enumString = schemaString
          .substring(enumStart + 1, enumEnd)
          .split('')
          .whereNot((e) => e == ' ')
          .join();

      enumString.split(',').where((e) => e.isNotEmpty).forEach((pairString) {
        List<String> pair = pairString.split('=');

        if (pair.length == 2) {
          int? value = int.tryParse(pair[1].trim());
          if (value != null) {
            enumData![value] = pair[0].trim();
          }
        }
      });

      schemaString = schemaString.substring(enumEnd + 1).trim();
    }

    List<String> parts = schemaString
        .split(' ')
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length < 2) {
      throw SchemaParseException('Invalid declaration: $schemaString');
    }

    String type = parts.removeAt(0);
    String definition = parts.join(' ').trim();

    StructValueType fieldType = StructValueType.parse(type);
    late String fieldName;
    int? bitLength;
    int? arrayLength;
    NTStructSchema? subSchema;
    bool isBitField = false;

    if (fieldType == StructValueType.struct) {
      NTStructSchema? schema = knownSchemas[type];
      if (schema == null) {
        throw SchemaParseException('Unknown struct type: $type');
      }
      bitLength = schema.bitLength;
      subSchema = schema;
    }

    if (definition.contains(':')) {
      var split = definition.split(':');
      fieldName = split[0].trim();
      bitLength = int.tryParse(split[1].trim());
      isBitField = true;
    } else if (definition.contains('[')) {
      List<String> split = definition.split('[');
      String rawLength = split[1].split(']')[0].trim();
      arrayLength = int.parse(rawLength);

      bitLength = (bitLength ?? fieldType.maxBits) * arrayLength;

      fieldName = split[0].trim();
    } else {
      fieldName = definition.trim();
    }

    if (fieldName.contains(' ')) {
      throw SchemaParseException('Field name cannot contain spaces');
    }

    bitLength ??= fieldType.maxBits;

    return NTFieldSchema(
      fieldName: fieldName,
      type: type,
      subSchema: subSchema,
      bitRange: (start, start + bitLength),
      arrayLength: arrayLength,
      enumData: enumData,
      bitLength: bitLength,
      isBitField: isBitField,
    );
  }

  Object? toValue(Uint8List data) {
    int requiredBytes = valueType.maxBits ~/ 8;
    if (data.length < requiredBytes) {
      Uint8List padded = Uint8List(requiredBytes);
      padded.setRange(0, data.length, data);
      data = padded;
    }
    final view = data.buffer.asByteData();
    final Object? value = switch (valueType) {
      StructValueType.bool => view.getUint8(0) > 0,
      StructValueType.char => () {
        String decoded = utf8.decode(data);
        int nullIndex = decoded.indexOf('\x00');
        if (nullIndex != -1) {
          return decoded.substring(0, nullIndex);
        }
        return decoded;
      }(),
      StructValueType.int8 => view.getInt8(0),
      StructValueType.int16 => view.getInt16(0, Endian.little),
      StructValueType.int32 => view.getInt32(0, Endian.little),
      StructValueType.int64 => view.getInt64Web(0, Endian.little),
      StructValueType.uint8 => view.getUint8(0),
      StructValueType.uint16 => view.getUint16(0, Endian.little),
      StructValueType.uint32 => view.getUint32(0, Endian.little),
      StructValueType.uint64 => view.getUint64Web(0, Endian.little),
      StructValueType.float ||
      StructValueType.float32 => view.getFloat32(0, Endian.little),
      StructValueType.double ||
      StructValueType.float64 => view.getFloat64(0, Endian.little),
      StructValueType.struct => () {
        if (subSchema == null) {
          return null;
        }
        return NTStruct.parse(schema: subSchema!, data: data);
      }(),
    };

    // We assume all enum values being published are mapped, if they are not
    // then we'll display it as an "unknown" string
    if (value != null && enumData != null) {
      return enumData![value] ?? 'Unknown ($value)';
    }
    return value;
  }
}

/// This class represents a schema for an NTStruct.
/// It contains the name of the struct and a list of field schemas.
class NTStructSchema {
  final String name;
  final List<NTFieldSchema> fields;
  final int bitLength;

  NTStructSchema({
    required this.name,
    required this.fields,
    required this.bitLength,
  });

  factory NTStructSchema.parse({
    required String name,
    required String schema,
    Map<String, NTStructSchema> knownSchemas = const {},
  }) {
    List<NTFieldSchema> fields = [];
    List<String> schemaParts = schema.replaceAll('\n', '').split(';');

    for (final String part in schemaParts.map((e) => e.trim())) {
      if (part.isEmpty) {
        continue;
      }

      fields.add(
        NTFieldSchema.parse(
          start: 0,
          schemaString: part,
          knownSchemas: knownSchemas,
        ),
      );
    }

    int bitPosition = 0;
    int? bitfieldPosition;
    int? bitfieldLength;

    for (int i = 0; i < fields.length; i++) {
      NTFieldSchema field = fields[i];

      if (field.valueType == StructValueType.struct) {
        // Child struct
        if (bitfieldPosition != null || bitfieldLength != null) {
          bitPosition += bitfieldLength! - bitfieldPosition!;
        }
        bitfieldPosition = null;
        bitfieldLength = null;

        int length = field.bitLength;
        fields[i] = field.copyWith(
          bitRange: (bitPosition, bitPosition + length),
        );
        bitPosition += length;
      } else if (!field.isBitField) {
        // Normal or array value
        if (bitfieldPosition != null || bitfieldLength != null) {
          bitPosition += bitfieldLength! - bitfieldPosition!;
        }
        bitfieldPosition = null;
        bitfieldLength = null;

        int length = field.bitLength;
        fields[i] = field.copyWith(
          bitRange: (bitPosition, bitPosition + length),
        );
        bitPosition += length;
      } else {
        // Bitfield value
        int typeLength = field.valueType.maxBits;
        int valueBitLength = min(field.bitLength, typeLength);

        if (bitfieldPosition == null ||
            bitfieldLength == null ||
            (field.valueType != StructValueType.bool &&
                bitfieldLength != typeLength) ||
            bitfieldPosition + valueBitLength > bitfieldLength) {
          // Start new bitfield
          if (bitfieldPosition != null || bitfieldLength != null) {
            bitPosition += bitfieldLength! - bitfieldPosition!;
          }
          bitfieldPosition = 0;
          bitfieldLength = typeLength;
        }
        fields[i] = field.copyWith(
          bitRange: (bitPosition, bitPosition + valueBitLength),
        );
        bitfieldPosition += valueBitLength;
        bitPosition += valueBitLength;
      }
    }

    if (bitfieldPosition != null || bitfieldLength != null) {
      bitPosition += bitfieldLength! - bitfieldPosition!;
    }

    return NTStructSchema(name: name, fields: fields, bitLength: bitPosition);
  }

  NTFieldSchema? operator [](String key) {
    for (final field in fields) {
      if (field.fieldName == key) {
        return field;
      }
    }

    return null;
  }

  @override
  String toString() =>
      '$name { ${fields.map((field) => '${field.fieldName}: ${field.type}').join(', ')} }';
}

/// This class represents an NTStruct.
/// It contains a schema and a map of values.
/// It provides methods to parse data into NTStructValue instances
/// and to retrieve values by key.
class NTStruct {
  final NTStructSchema schema;
  final Map<String, Object?> values;

  NTStruct({required this.schema, required this.values});

  factory NTStruct.parse({
    required NTStructSchema schema,
    required Uint8List data,
  }) {
    Map<String, Object?> values = {};

    Uint8List sliceBits(Uint8List input, int start, int end) {
      if (start % 8 == 0 && end % 8 == 0) {
        return input.sublist(start ~/ 8, end ~/ 8);
      } else {
        return input.toBitArray().slice(start, end).toUint8List();
      }
    }

    for (final field in schema.fields) {
      if (field.bitRange.$2 > data.length * 8) break;

      if (field.isArray) {
        if (field.valueType == StructValueType.char) {
          Uint8List bytes = sliceBits(
            data,
            field.bitRange.$1,
            field.bitRange.$2,
          );
          String decoded = utf8.decode(bytes, allowMalformed: true);
          int nullIndex = decoded.indexOf('\x00');
          values[field.fieldName] = (nullIndex != -1)
              ? decoded.substring(0, nullIndex)
              : decoded;
          continue;
        }

        List<Object?> value = [];

        int itemLength =
            (field.bitRange.$2 - field.bitRange.$1) ~/ field.arrayLength!;

        for (
          int position = field.bitRange.$1;
          position < field.bitRange.$2;
          position += itemLength
        ) {
          value.add(
            field.toValue(sliceBits(data, position, position + itemLength)),
          );
        }

        values[field.fieldName] = value;
      } else {
        final value = field.toValue(
          sliceBits(data, field.bitRange.$1, field.bitRange.$2),
        );

        values[field.fieldName] = value;
      }
    }

    return NTStruct(schema: schema, values: values);
  }

  dynamic operator [](String key) => values[key];

  Object? get(List<String> key) {
    Object? value = this;

    for (final k in key) {
      // Path should only be advancing through sub-structs
      // If the path is trying to point beyond a non-struct, return null
      // since it would be invalid
      if (value is NTStruct) {
        value = value[k];
      } else {
        return null;
      }
    }

    return value;
  }
}
