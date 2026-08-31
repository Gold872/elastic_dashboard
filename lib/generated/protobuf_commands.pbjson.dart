// This is a generated file - do not edit.
//
// Generated from protobuf_commands.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use protobufMechanismDescriptor instead')
const ProtobufMechanism$json = {
  '1': 'ProtobufMechanism',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `ProtobufMechanism`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List protobufMechanismDescriptor = $convert
    .base64Decode('ChFQcm90b2J1Zk1lY2hhbmlzbRISCgRuYW1lGAEgASgJUgRuYW1l');

@$core.Deprecated('Use protobufCommandDescriptor instead')
const ProtobufCommand$json = {
  '1': 'ProtobufCommand',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 13, '10': 'id'},
    {
      '1': 'parent_id',
      '3': 2,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'parentId',
      '17': true
    },
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'priority', '3': 4, '4': 1, '5': 5, '10': 'priority'},
    {
      '1': 'requirements',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.wpi.proto.ProtobufMechanism',
      '10': 'requirements'
    },
    {
      '1': 'last_time_ms',
      '3': 6,
      '4': 1,
      '5': 1,
      '9': 1,
      '10': 'lastTimeMs',
      '17': true
    },
    {
      '1': 'total_time_ms',
      '3': 7,
      '4': 1,
      '5': 1,
      '9': 2,
      '10': 'totalTimeMs',
      '17': true
    },
  ],
  '8': [
    {'1': '_parent_id'},
    {'1': '_last_time_ms'},
    {'1': '_total_time_ms'},
  ],
};

/// Descriptor for `ProtobufCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List protobufCommandDescriptor = $convert.base64Decode(
    'Cg9Qcm90b2J1ZkNvbW1hbmQSDgoCaWQYASABKA1SAmlkEiAKCXBhcmVudF9pZBgCIAEoDUgAUg'
    'hwYXJlbnRJZIgBARISCgRuYW1lGAMgASgJUgRuYW1lEhoKCHByaW9yaXR5GAQgASgFUghwcmlv'
    'cml0eRJACgxyZXF1aXJlbWVudHMYBSADKAsyHC53cGkucHJvdG8uUHJvdG9idWZNZWNoYW5pc2'
    '1SDHJlcXVpcmVtZW50cxIlCgxsYXN0X3RpbWVfbXMYBiABKAFIAVIKbGFzdFRpbWVNc4gBARIn'
    'Cg10b3RhbF90aW1lX21zGAcgASgBSAJSC3RvdGFsVGltZU1ziAEBQgwKCl9wYXJlbnRfaWRCDw'
    'oNX2xhc3RfdGltZV9tc0IQCg5fdG90YWxfdGltZV9tcw==');

@$core.Deprecated('Use protobufSchedulerDescriptor instead')
const ProtobufScheduler$json = {
  '1': 'ProtobufScheduler',
  '2': [
    {
      '1': 'queued_commands',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.wpi.proto.ProtobufCommand',
      '10': 'queuedCommands'
    },
    {
      '1': 'running_commands',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.wpi.proto.ProtobufCommand',
      '10': 'runningCommands'
    },
    {'1': 'last_time_ms', '3': 3, '4': 1, '5': 1, '10': 'lastTimeMs'},
  ],
};

/// Descriptor for `ProtobufScheduler`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List protobufSchedulerDescriptor = $convert.base64Decode(
    'ChFQcm90b2J1ZlNjaGVkdWxlchJDCg9xdWV1ZWRfY29tbWFuZHMYASADKAsyGi53cGkucHJvdG'
    '8uUHJvdG9idWZDb21tYW5kUg5xdWV1ZWRDb21tYW5kcxJFChBydW5uaW5nX2NvbW1hbmRzGAIg'
    'AygLMhoud3BpLnByb3RvLlByb3RvYnVmQ29tbWFuZFIPcnVubmluZ0NvbW1hbmRzEiAKDGxhc3'
    'RfdGltZV9tcxgDIAEoAVIKbGFzdFRpbWVNcw==');
