import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/services/struct_schemas/nt_struct.dart';

String testSchema1 = 'float32 vx;float32 vy;float32 omega';

String testSchema2 = '''
float32 vx;
float32 vy;
float32 omega;
''';

String schemaWithBitLengths = 'int32 one : 2;';

void main() {
  group('[Schema Parsing]:', () {
    test('Schema with 3 floats', () {
      final schema = NTStructSchema.parse(
        name: 'ChassisSpeeds',
        schema: testSchema1,
      );

      expect(schema.fields.length, 3);
      expect(schema.fields[0].type.toString(), 'float32');
      expect(schema.fields[0].fieldName, 'vx');
      expect(schema.fields[0].subSchema, isNull);

      expect(schema.fields[1].type.toString(), 'float32');
      expect(schema.fields[1].fieldName, 'vy');
      expect(schema.fields[1].subSchema, isNull);

      expect(schema.fields[2].type.toString(), 'float32');
      expect(schema.fields[2].fieldName, 'omega');
      expect(schema.fields[2].subSchema, isNull);
    });

    test('Schema with new lines', () {
      final schema = NTStructSchema.parse(
        name: 'ChassisSpeeds',
        schema: testSchema2,
      );

      expect(schema.fields.length, 3);
      expect(schema.fields[0].type, 'float32');
      expect(schema.fields[0].fieldName, 'vx');
      expect(schema.fields[0].subSchema, isNull);

      expect(schema.fields[1].type, 'float32');
      expect(schema.fields[1].fieldName, 'vy');
      expect(schema.fields[1].subSchema, isNull);

      expect(schema.fields[2].type, 'float32');
      expect(schema.fields[2].fieldName, 'omega');
      expect(schema.fields[2].subSchema, isNull);
    });

    test('Schema with custom bit length', () {
      final schema = NTStructSchema.parse(
        name: 'TestStruct',
        schema: schemaWithBitLengths,
      );

      expect(schema.fields.length, 1);
      expect(schema.fields[0].type, 'int32');
      expect(schema.fields[0].valueType, StructValueType.int32);
      expect(schema.fields[0].fieldName, 'one');
      expect(schema.fields[0].subSchema, isNull);
      expect(schema.fields[0].bitLength, 2);
    });

    test('Schema with array', () {
      final schema = NTStructSchema.parse(
        name: 'TestStruct',
        schema: 'int32 one[3];',
      );

      expect(schema.fields.length, 1);
      expect(schema.fields[0].fieldName, 'one');
      expect(schema.fields[0].type, 'int32');
      expect(schema.fields[0].isArray, true);
      expect(schema.fields[0].arrayLength, 3);
    });

    test('Schema with sub-type', () {
      final subSchema = NTStructSchema.parse(
        name: 'SubSchema',
        schema: 'int32 field1',
      );

      final schema = NTStructSchema.parse(
        name: 'Schema',
        schema: 'SubSchema subSchema',
        knownSchemas: {'SubSchema': subSchema},
      );

      expect(schema.fields.length, 1);
      expect(schema.fields[0].type, 'SubSchema');
      expect(schema.fields[0].fieldName, 'subSchema');
      expect(schema.fields[0].subSchema, subSchema);
      expect(schema.fields[0].ntType, NT4Type.struct('SubSchema'));
    });

    test('Schema with enum', () {
      final schema = NTStructSchema.parse(
        name: 'TestEnum',
        schema: 'enum {a=1, b=2, c=3} int8 testEnum;',
      );

      expect(schema.fields.length, 1);
      expect(schema.fields[0].type, 'int8');
      expect(schema.fields[0].fieldName, 'testEnum');
      expect(schema.fields[0].enumData, isNotNull);
      expect(schema.fields[0].enumData, {1: 'a', 2: 'b', 3: 'c'});
    });

    group('Error Handling:', () {
      test('Unknown sub-schemas', () {
        expect(
          () => NTStructSchema.parse(
            name: 'TestSchema',
            schema: 'SubSchema subType;',
          ),
          throwsException,
        );

        expect(
          () => NTStructSchema.parse(
            name: 'TestSchema',
            schema: 'int32 one; SubSchema subType;',
          ),
          throwsException,
        );
      });

      test('Invalid data types', () {
        expect(
          () =>
              NTStructSchema.parse(name: 'TestSchema', schema: 'invalid one;'),
          throwsA(isA<SchemaParseException>()),
        );

        expect(
          () => NTStructSchema.parse(name: 'TestSchema', schema: 'long one;'),
          throwsA(isA<SchemaParseException>()),
        );
      });

      test('Syntax errors', () {
        expect(
          () => NTStructSchema.parse(
            name: 'TestSchema',
            schema: 'int32 one float32 two',
          ),
          throwsA(isA<SchemaParseException>()),
          reason: 'Missing semicolon',
        );

        expect(
          () =>
              NTStructSchema.parse(name: 'TestSchema', schema: 'int32 one[];'),
          throwsException,
          reason: 'Unspecified array length',
        );

        expect(
          () => NTStructSchema.parse(
            name: 'TestEnum',
            schema: 'enum {a=1, b=2, c=3}',
          ),
          throwsA(isA<SchemaParseException>()),
          reason: 'Enum declared with no field',
        );

        expect(
          () => NTStructSchema.parse(
            name: 'TestEnum',
            schema: 'enum int8 testEnum',
          ),
          throwsA(isA<SchemaParseException>()),
          reason: 'Invalid enum syntax',
        );
      });
    });
  });

  group('[Schema Manager]:', () {
    test('Registering new schema', () {
      SchemaManager schemaManager = SchemaManager();

      schemaManager.processNewSchema(
        'TestStruct',
        utf8.encode('int32 field1; int32 field2;'),
      );

      expect(schemaManager.getSchema('TestStruct'), isNotNull);

      expect(schemaManager.isStruct('TestStruct'), true);
    });

    test('Registering schemas with dependencies', () {
      SchemaManager schemaManager = SchemaManager();

      schemaManager.processNewSchema(
        'Pose2d',
        utf8.encode('Translation2d translation; Rotation2d rotation'),
      );

      expect(schemaManager.getSchema('Pose2d'), isNull);
      expect(schemaManager.isStruct('Pose2d'), false);

      schemaManager.processNewSchema('Rotation2d', utf8.encode('double value'));

      expect(schemaManager.getSchema('Rotation2d'), isNotNull);
      expect(schemaManager.isStruct('Rotation2d'), true);

      expect(schemaManager.getSchema('Pose2d'), isNull);
      expect(schemaManager.isStruct('Pose2d'), false);

      schemaManager.processNewSchema(
        'Translation2d',
        utf8.encode('double x; double y'),
      );

      expect(schemaManager.getSchema('Translation2d'), isNotNull);
      expect(schemaManager.isStruct('Translation2d'), true);

      expect(schemaManager.getSchema('Pose2d'), isNotNull);
      expect(schemaManager.isStruct('Pose2d'), true);
    });
  });

  group('[Struct Decoding]:', () {
    test('Decoding with basic data types', () {
      final schema = NTStructSchema.parse(
        name: 'TestSchema',
        schema: 'int64 one;uint64 two',
      );

      ByteData rawData = ByteData(16);
      rawData.setInt64(0, -15000, Endian.little);
      rawData.setUint64(8, 15000, Endian.little);

      final decodedStruct = NTStruct.parse(
        schema: schema,
        data: Uint8List.view(rawData.buffer),
      );

      final decodedValues = decodedStruct.values;

      expect(decodedValues.length, 2);
      expect(decodedValues['one'], isA<int>());
      expect(decodedValues['one'], -15000);
      expect(decodedValues['two'], isA<int>());
      expect(decodedValues['two'], 15000);
    });

    test('Decoding with nested types', () {
      final subSchema = NTStructSchema.parse(
        name: 'SubSchema',
        schema: 'int32 field1;float field2',
      );

      final schema = NTStructSchema.parse(
        name: 'Schema',
        schema: 'SubSchema subSchema;float field2',
        knownSchemas: {'SubSchema': subSchema},
      );

      ByteData rawData = ByteData(12);
      int offset = 0;
      rawData.setInt32(offset, -15000.toInt(), Endian.little);
      offset += 4;
      rawData.setFloat32(offset, -10.0, Endian.little);
      offset += 4;
      rawData.setFloat32(offset, 1500.0, Endian.little);

      final decodedStruct = NTStruct.parse(
        schema: schema,
        data: Uint8List.view(rawData.buffer),
      );

      expect(decodedStruct.values.length, 2);
      expect(decodedStruct['subSchema'], isA<NTStruct>());

      final decodedSubStruct = decodedStruct['subSchema'] as NTStruct;

      expect(decodedSubStruct['field1'], isA<int>());
      expect(decodedSubStruct['field1'], -15000);
      expect(decodedSubStruct['field2'], isA<double>());
      expect(decodedSubStruct['field2'], -10.0);

      expect(decodedStruct['field2'], isA<double>());
      expect(decodedStruct['field2'], 1500.0);
    });

    test('Decoding arrays', () {
      final schema = NTStructSchema.parse(
        name: 'TestStruct',
        schema: 'int8 intArray[16]; float floatArray[16]',
      );

      ByteData rawData = ByteData((8 * 16 + 32 * 16) ~/ 8);

      for (int i = 0; i < 16; i++) {
        rawData.setInt8(i, i);
      }
      for (int i = 0; i < 16; i++) {
        rawData.setFloat32(i * 4 + 16, i * 0.5, Endian.little);
      }

      final NTStruct decoded = NTStruct.parse(
        schema: schema,
        data: Uint8List.view(rawData.buffer),
      );

      expect(decoded.values.length, 2);
      expect(decoded['intArray'], isA<List>());

      for (int i = 0; i < 16; i++) {
        expect(decoded['intArray']?[i], i);
      }

      expect(decoded['floatArray'], isA<List>());

      for (int i = 0; i < 16; i++) {
        expect(decoded['floatArray']?[i], i * 0.5);
      }
    });

    test('Decoding enum', () {
      final schema = NTStructSchema.parse(
        name: 'TestEnum',
        schema: 'enum {a=1, b=2, c=3} int8 testEnum;',
      );

      ByteData rawData = ByteData(8);
      rawData.setInt8(0, 3);

      final NTStruct decodedStruct = NTStruct.parse(
        schema: schema,
        data: Uint8List.view(rawData.buffer),
      );

      final decodedValues = decodedStruct.values;

      expect(decodedValues.length, 1);
      expect(decodedValues['testEnum'], isA<String>());
      expect(decodedValues['testEnum'], 'c');
    });

    test('Decoding enum (unknown value)', () {
      final schema = NTStructSchema.parse(
        name: 'TestEnum',
        schema: 'enum {a=1, b=2, c=3} int8 testEnum;',
      );

      ByteData rawData = ByteData(8);
      rawData.setInt8(0, 5);

      final NTStruct decodedStruct = NTStruct.parse(
        schema: schema,
        data: Uint8List.view(rawData.buffer),
      );

      final decodedValues = decodedStruct.values;

      expect(decodedValues.length, 1);
      expect(decodedValues['testEnum'], isA<String>());
      expect(decodedValues['testEnum'], 'Unknown (5)');
    });

    test('Decoding with incorrectly sized raw data', () {
      final schema = NTStructSchema.parse(
        name: 'TestSchema',
        schema: 'int64 one;uint64 two',
      );

      ByteData rawData = ByteData(12);
      rawData.setInt64(0, -15000, Endian.little);
      rawData.setUint32(8, 15000, Endian.little);

      final decodedStruct = NTStruct.parse(
        schema: schema,
        data: Uint8List.view(rawData.buffer),
      );

      final decodedValues = decodedStruct.values;

      expect(decodedValues.length, 1);
      expect(decodedValues['one'], isA<int>());
      expect(decodedValues['one'], -15000);
      expect(decodedValues['two'], isNull);
    });

    test('Decoding all possible primitive types', () {
      final schema = NTStructSchema.parse(
        name: 'TestStruct',
        schema:
            'bool val1; char val2; int8 val3; int16 val4; int32 val5; int64 val6; uint8 val7; uint16 val8; uint32 val9; uint64 val10; float val11; double val12',
      );

      List<dynamic> expectedData = [
        true,
        'a',
        -125,
        -353,
        -25000,
        -pow(2, 63).toInt(),
        125,
        353,
        25000,
        pow(2, 63).toInt(),
        3.53,
        3.53,
      ];

      ByteData rawData = ByteData(
        (8 + 8 + 8 + 16 + 32 + 64 + 8 + 16 + 32 + 64 + 32 + 64) ~/ 8,
      );
      final Endian endian = Endian.little;
      int offset = 0;
      rawData.setUint8(offset, (expectedData[0] as bool) ? 1 : 0);
      offset += 1;
      rawData.setUint8(offset, utf8.encode(expectedData[1]).first);
      offset += 1;

      // Signed types
      rawData.setInt8(offset, expectedData[2]);
      offset += 1;
      rawData.setInt16(offset, expectedData[3], endian);
      offset += 2;
      rawData.setInt32(offset, expectedData[4], endian);
      offset += 4;
      rawData.setInt64(offset, expectedData[5], endian);
      offset += 8;

      // Unsigned types
      rawData.setUint8(offset, expectedData[6]);
      offset += 1;
      rawData.setUint16(offset, expectedData[7], endian);
      offset += 2;
      rawData.setUint32(offset, expectedData[8], endian);
      offset += 4;
      rawData.setUint64(offset, expectedData[9], endian);
      offset += 8;

      // Floating point types
      rawData.setFloat32(offset, expectedData[10], endian);
      offset += 4;
      rawData.setFloat64(offset, expectedData[11], endian);
      offset += 8;

      final NTStruct decodedStruct = NTStruct.parse(
        schema: schema,
        data: Uint8List.view(rawData.buffer),
      );

      expect(decodedStruct.values.length, 12);

      for (int i = 0; i < expectedData.length; i++) {
        final decodedValue = decodedStruct['val${i + 1}'];
        // Floating points are annoying
        if (decodedValue is double) {
          expect((expectedData[i] - decodedValue).abs(), lessThan(0.01));
        } else {
          expect(decodedStruct['val${i + 1}'], expectedData[i]);
        }
      }
    });
  });

  group('[NT Struct Meta]:', () {
    final NTStructSchema schema = NTStructSchema.parse(
      name: 'TestStruct',
      schema: 'SubStruct subStruct;',
      knownSchemas: {
        'SubStruct': NTStructSchema.parse(
          name: 'SubStruct',
          schema: 'int32 val1;',
        ),
      },
    );

    group('Struct Meta Type:', () {
      test('With valid path', () {
        final NT4StructMeta structMeta = NT4StructMeta(
          path: ['subStruct', 'val1'],
          schemaName: 'TestStruct',
          schema: schema,
        );

        expect(structMeta.type, NT4Type.int());
      });

      test('With no path', () {
        final NT4StructMeta structMeta = NT4StructMeta(
          path: [],
          schemaName: 'TestStruct',
          schema: schema,
        );

        expect(structMeta.type, NT4Type.struct('TestStruct'));
      });

      test('With invalid path', () {
        final NT4StructMeta structMeta = NT4StructMeta(
          path: ['subStruct', 'random thing'],
          schemaName: 'TestStruct',
          schema: schema,
        );

        expect(structMeta.type, NT4Type.struct('SubStruct'));
      });
    });

    final Map<String, dynamic> structMetaJson = {
      'path': ['subStruct', 'val1'],
      'schema_name': 'TestStruct',
      'type': 'int',
    };

    test('Struct meta to json', () {
      final NT4StructMeta structMeta = NT4StructMeta(
        path: ['subStruct', 'val1'],
        schemaName: 'TestStruct',
        schema: schema,
      );

      expect(structMeta.toJson(), structMetaJson);
    });

    test('Struct meta from json', () {
      final NT4StructMeta structMeta = NT4StructMeta(
        path: ['subStruct', 'val1'],
        schemaName: 'TestStruct',
        type: NT4Type.int(),
      );

      expect(NT4StructMeta.fromJson(structMetaJson), structMeta);
    });
  });

  group('[WPILib Bit-Packing Spec Examples]:', () {
    test('int8 a:4; int16 b:4;', () {
      final schema = NTStructSchema.parse(
        name: 'Ex1',
        schema: 'int8 a:4; int16 b:4;',
      );
      // int8(8 bits) + int16(16 bits) = 24 bits (3 bytes)
      expect(schema.bitLength, 24);

      // Encoding: 0000aaaa 0000bbbb 00000000
      final data = Uint8List.fromList([0x05, 0x03, 0x00]); // a=5, b=3
      final struct = NTStruct.parse(schema: schema, data: data);

      expect(struct['a'], 5);
      expect(struct['b'], 3);
    });

    test('int16 a:4; uint16 b:5; bool c:1; int16 d:7;', () {
      final schema = NTStructSchema.parse(
        name: 'Ex2',
        schema: 'int16 a:4; uint16 b:5; bool c:1; int16 d:7;',
      );
      // a, b, c pack into first 16-bit slot (4+5+1=10 bits used, 6 wasted).
      // d (7 bits) flushes to next 16-bit slot.
      // Total: 16 + 16 = 32 bits (4 bytes).
      expect(schema.bitLength, 32);

      // Encoding: bbbbaaaa 000000cb 0ddddddd 00000000
      // a=10 (1010), b=21 (10101), c=true (1), d=66 (1000010)
      final data = Uint8List.fromList([0x5A, 0x03, 0x42, 0x00]);
      final struct = NTStruct.parse(schema: schema, data: data);

      expect(struct['a'], 10);
      expect(struct['b'], 21);
      expect(struct['c'], true);
      expect(struct['d'], 66);
    });

    test('uint8 a:4; int8 b:2; bool c:1; int16 d:1;', () {
      final schema = NTStructSchema.parse(
        name: 'Ex3',
        schema: 'uint8 a:4; int8 b:2; bool c:1; int16 d:1;',
      );
      // a, b, c pack into first 8-bit slot (4+2+1=7 bits used, 1 wasted).
      // d flushes to next 16-bit slot.
      // Total: 8 + 16 = 24 bits (3 bytes).
      expect(schema.bitLength, 24);

      // Encoding: 0cbbaaaa 0000000d 00000000
      final data = Uint8List.fromList([
        0x65,
        0x01,
        0x00,
      ]); // a=5, b=2, c=true, d=1
      final struct = NTStruct.parse(schema: schema, data: data);

      expect(struct['a'], 5);
      expect(struct['b'], 2);
      expect(struct['c'], true);
      expect(struct['d'], 1);
    });

    test('bool a:1; bool b:1; int8 c:2;', () {
      final schema = NTStructSchema.parse(
        name: 'Ex4',
        schema: 'bool a:1; bool b:1; int8 c:2;',
      );
      // All pack into a single uint8 slot (default for bool if not specified).
      expect(schema.bitLength, 8);

      final data = Uint8List.fromList([0x0D]); // 00001101 -> c=3 (11), b=0, a=1
      final struct = NTStruct.parse(schema: schema, data: data);

      expect(struct['a'], true);
      expect(struct['b'], false);
      expect(struct['c'], 3);
    });

    test('bool a:1; bool b:1; int16 c:2;', () {
      final schema = NTStructSchema.parse(
        name: 'Ex5',
        schema: 'bool a:1; bool b:1; int16 c:2;',
      );
      // a, b start a uint8 slot. c is int16, flushes.
      // Total: 8 + 16 = 24 bits.
      expect(schema.bitLength, 24);

      final data = Uint8List.fromList([0x03, 0x02, 0x00]); // a=1, b=1, c=2
      final struct = NTStruct.parse(schema: schema, data: data);

      expect(struct['a'], true);
      expect(struct['b'], true);
      expect(struct['c'], 2);
    });

    test('Nested structs do not pack bits', () {
      final sub = NTStructSchema.parse(name: 'Inner', schema: 'int8 a:1;');
      final schema = NTStructSchema.parse(
        name: 'Outer',
        schema: 'int8 b:1; Inner s; int8 c:1;',
        knownSchemas: {'Inner': sub},
      );
      // b:1 (bits 0-1), flush (8), Inner (bits 8-16), flush (8), c:1 (bits 16-17), flush (8)
      expect(schema.bitLength, 24);
    });
  });

  group('[Data Util]:', () {
    test('Uint8List to Bit array', () {
      final bitArray = [
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ].map((e) => e == 1).toList();

      expect(Uint8List.fromList([1, 1]).toBitArray(), bitArray);

      expect(
        Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]).toBitArray().length,
        64,
      );
    });

    test('Bit array to Uint8List', () {
      final bitArray = [
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ].map((e) => e == 1).toList();

      expect(bitArray.toUint8List(), Uint8List.fromList([1, 1]));

      expect(List.generate(64, (_) => false).toUint8List().length, 8);
    });

    test('Web-safe 64 bit int reading (signed)', () {
      ByteData dataBE = ByteData(8);
      dataBE.setInt64(0, -pow(2, 63).toInt(), Endian.big);

      ByteData dataLE = ByteData(8);
      dataLE.setInt64(0, -pow(2, 63).toInt(), Endian.little);

      expect(
        dataBE.getInt64(0, Endian.big),
        dataBE.extractWebInt64(0, Endian.big),
      );

      expect(
        dataLE.getInt64(0, Endian.little),
        dataLE.extractWebInt64(0, Endian.little),
      );
    });

    test('Web-safe 64 bit int reading (unsigned)', () {
      ByteData dataBE = ByteData(8);
      dataBE.setUint64(0, (pow(2, 64) - 1).toInt(), Endian.big);

      ByteData dataLE = ByteData(8);
      dataLE.setUint64(0, (pow(2, 64) - 1).toInt(), Endian.little);

      expect(
        dataBE.getUint64(0, Endian.big),
        dataBE.extractWebUint64(0, Endian.big),
      );

      expect(
        dataLE.getUint64(0, Endian.little),
        dataLE.extractWebUint64(0, Endian.little),
      );
    });
  });
}
