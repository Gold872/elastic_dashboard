import 'package:flutter_test/flutter_test.dart';

import 'package:elastic_dashboard/services/nt4_type.dart';

void main() {
  group('[NT4 Type Parsing]:', () {
    test('Individual data types', () {
      expect(NT4Type.parse('boolean'), NT4Type.boolean());
      expect(NT4Type.parse('int'), NT4Type.int());
      expect(NT4Type.parse('float'), NT4Type.float());
      expect(NT4Type.parse('string'), NT4Type.string());
      expect(NT4Type.parse('json'), NT4Type.json());
      expect(NT4Type.parse('raw'), NT4Type.raw());
      expect(NT4Type.parse('rpc'), NT4Type.rpc());
      expect(NT4Type.parse('msgpack'), NT4Type.msgpack());
      expect(NT4Type.parse('structschema'), NT4Type.structschema());
    });

    test('Struct types', () {
      expect(NT4Type.parse('struct:TestStruct'), NT4Type.struct('TestStruct'));
      expect(
        NT4Type.parse('struct:TestStruct[]'),
        NT4Type.structArray('TestStruct'),
      );
      expect(
        NT4Type.parse('struct:TestStruct[]'),
        NT4Type.array(NT4Type.struct('TestStruct')),
      );
    });

    test('Array types', () {
      expect(NT4Type.parse('double[]'), NT4Type.array(NT4Type.double()));
      expect(
        NT4Type.parse('struct:Pose2d[]'),
        NT4Type.array(NT4Type.struct('Pose2d')),
      );
    });

    test('Unknown types', () {
      expect(NT4Type.parse('Unknown'), NT4Type.unknown('Unknown'));
      expect(NT4Type.parse('Something').dataType, NT4DataType.unknown);
    });
  });

  group('[NT4 Type Serializing]:', () {
    test('Basic type serializing', () {
      expect(NT4Type.boolean().serialize(), 'boolean');
      expect(NT4Type.int().serialize(), 'int');
      expect(NT4Type.float().serialize(), 'float');
      expect(NT4Type.double().serialize(), 'double');
      expect(NT4Type.string().serialize(), 'string');
      expect(NT4Type.json().serialize(), 'json');
      expect(NT4Type.raw().serialize(), 'raw');
      expect(NT4Type.rpc().serialize(), 'rpc');
      expect(NT4Type.msgpack().serialize(), 'msgpack');
      expect(NT4Type.structschema().serialize(), 'structschema');
    });

    test('Array serializing', () {
      expect(NT4Type.array(NT4Type.boolean()).serialize(), 'boolean[]');
      expect(NT4Type.array(NT4Type.int()).serialize(), 'int[]');
      expect(NT4Type.array(NT4Type.float()).serialize(), 'float[]');
      expect(NT4Type.array(NT4Type.double()).serialize(), 'double[]');
      expect(NT4Type.array(NT4Type.string()).serialize(), 'string[]');
      expect(NT4Type.array(NT4Type.json()).serialize(), 'json[]');
      expect(NT4Type.array(NT4Type.raw()).serialize(), 'raw');
      expect(NT4Type.array(NT4Type.rpc()).serialize(), 'rpc');
      expect(NT4Type.array(NT4Type.msgpack()).serialize(), 'msgpack');
      expect(NT4Type.array(NT4Type.structschema()).serialize(), 'structschema');
    });

    test('Struct serializing', () {
      expect(NT4Type.struct('Pose2d').serialize(), 'struct:Pose2d');
      expect(NT4Type.struct('struct:Pose2d').serialize(), 'struct:Pose2d');
    });

    test('Struct array serializing', () {
      expect(NT4Type.struct('struct:Pose2d[]').serialize(), 'struct:Pose2d[]');
      expect(
        NT4Type.array(NT4Type.struct('Pose2d')).serialize(),
        'struct:Pose2d[]',
      );
      expect(NT4Type.structArray('Pose2d').serialize(), 'struct:Pose2d[]');
      expect(NT4Type.struct('struct:Pose2d[]').serialize(), 'struct:Pose2d[]');
    });

    test('Struct serializing', () {
      expect(
        NT4Type.proto('wpi.proto.Pose2d').serialize(),
        'proto:wpi.proto.Pose2d',
      );
      expect(
        NT4Type.proto('proto:wpi.proto.Pose2d').serialize(),
        'proto:wpi.proto.Pose2d',
      );
    });
  });

  group('[String Conversion]:', () {
    test('Basic string conversion', () {
      expect(NT4Type.boolean().convertString('true'), true);
      expect(NT4Type.boolean().convertString('hello'), isNull);

      expect(NT4Type.int().convertString('5'), 5);
      expect(NT4Type.int().convertString('hello'), isNull);

      expect(NT4Type.double().convertString('5'), 5.0);
      expect(NT4Type.double().convertString('hello'), isNull);

      expect(
        NT4Type.string().convertString('this is a string'),
        'this is a string',
      );

      expect(NT4Type.unknown('Unknown').convertString('hi'), isNull);
    });

    test('Array string conversion', () {
      NT4Type boolArray = NT4Type.array(NT4Type.boolean());
      expect(boolArray.convertString('[true, false, true]'), [
        true,
        false,
        true,
      ]);

      NT4Type intArray = NT4Type.array(NT4Type.int());
      expect(intArray.convertString('[1, 2, 3.0, 4, 5]'), [1, 2, 3, 4, 5]);

      NT4Type doubleArray = NT4Type.array(NT4Type.double());
      expect(doubleArray.convertString('[1.0, 2, 3.0, 4, 5.0]'), [
        1.0,
        2.0,
        3.0,
        4.0,
        5.0,
      ]);

      NT4Type stringArray = NT4Type.array(NT4Type.string());
      expect(stringArray.convertString('["this", "is", "a", "string"]'), [
        'this',
        'is',
        'a',
        'string',
      ]);
    });
  });

  test('Type equality', () {
    expect(NT4Type.parse('double'), NT4Type.double());
    expect(NT4Type.struct('struct:Pose2d'), NT4Type.struct('Pose2d'));

    expect(
      NT4Type.structArray('struct:Pose2d'),
      NT4Type.struct('struct:Pose2d[]'),
    );

    expect(
      NT4Type.array(NT4Type.array(NT4Type.array(NT4Type.double()))),
      NT4Type.array(NT4Type.double()),
      reason: 'Does not allow more than 1d arrays',
    );
  });
}
