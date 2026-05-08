// This is a generated file - do not edit.
//
// Generated from protobuf_commands.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class ProtobufMechanism extends $pb.GeneratedMessage {
  factory ProtobufMechanism({
    $core.String? name,
  }) {
    final result = create();
    if (name != null) result.name = name;
    return result;
  }

  ProtobufMechanism._();

  factory ProtobufMechanism.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProtobufMechanism.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProtobufMechanism',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wpi.proto'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtobufMechanism clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtobufMechanism copyWith(void Function(ProtobufMechanism) updates) =>
      super.copyWith((message) => updates(message as ProtobufMechanism))
          as ProtobufMechanism;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProtobufMechanism create() => ProtobufMechanism._();
  @$core.override
  ProtobufMechanism createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProtobufMechanism getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProtobufMechanism>(create);
  static ProtobufMechanism? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);
}

class ProtobufCommand extends $pb.GeneratedMessage {
  factory ProtobufCommand({
    $core.int? id,
    $core.int? parentId,
    $core.String? name,
    $core.int? priority,
    $core.Iterable<ProtobufMechanism>? requirements,
    $core.double? lastTimeMs,
    $core.double? totalTimeMs,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (parentId != null) result.parentId = parentId;
    if (name != null) result.name = name;
    if (priority != null) result.priority = priority;
    if (requirements != null) result.requirements.addAll(requirements);
    if (lastTimeMs != null) result.lastTimeMs = lastTimeMs;
    if (totalTimeMs != null) result.totalTimeMs = totalTimeMs;
    return result;
  }

  ProtobufCommand._();

  factory ProtobufCommand.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProtobufCommand.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProtobufCommand',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wpi.proto'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'parentId', fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aI(4, _omitFieldNames ? '' : 'priority')
    ..pPM<ProtobufMechanism>(5, _omitFieldNames ? '' : 'requirements',
        subBuilder: ProtobufMechanism.create)
    ..aD(6, _omitFieldNames ? '' : 'lastTimeMs')
    ..aD(7, _omitFieldNames ? '' : 'totalTimeMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtobufCommand clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtobufCommand copyWith(void Function(ProtobufCommand) updates) =>
      super.copyWith((message) => updates(message as ProtobufCommand))
          as ProtobufCommand;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProtobufCommand create() => ProtobufCommand._();
  @$core.override
  ProtobufCommand createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProtobufCommand getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProtobufCommand>(create);
  static ProtobufCommand? _defaultInstance;

  /// A unique ID for the command.
  /// Different invocations of the same command object have different IDs.
  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// The ID of the parent command.
  /// Not included in the message for top-level commands.
  @$pb.TagNumber(2)
  $core.int get parentId => $_getIZ(1);
  @$pb.TagNumber(2)
  set parentId($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasParentId() => $_has(1);
  @$pb.TagNumber(2)
  void clearParentId() => $_clearField(2);

  /// The name of the command.
  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  /// The priority level of the command.
  @$pb.TagNumber(4)
  $core.int get priority => $_getIZ(3);
  @$pb.TagNumber(4)
  set priority($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPriority() => $_has(3);
  @$pb.TagNumber(4)
  void clearPriority() => $_clearField(4);

  /// The mechanisms required by the command.
  @$pb.TagNumber(5)
  $pb.PbList<ProtobufMechanism> get requirements => $_getList(4);

  /// How much time the command took to execute in its most recent run.
  /// Only included in a message for an actively running command.
  @$pb.TagNumber(6)
  $core.double get lastTimeMs => $_getN(5);
  @$pb.TagNumber(6)
  set lastTimeMs($core.double value) => $_setDouble(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLastTimeMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearLastTimeMs() => $_clearField(6);

  /// How long the command has taken to run, in aggregate.
  /// Only included in a message for an actively running command.
  @$pb.TagNumber(7)
  $core.double get totalTimeMs => $_getN(6);
  @$pb.TagNumber(7)
  set totalTimeMs($core.double value) => $_setDouble(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTotalTimeMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearTotalTimeMs() => $_clearField(7);
}

class ProtobufScheduler extends $pb.GeneratedMessage {
  factory ProtobufScheduler({
    $core.Iterable<ProtobufCommand>? queuedCommands,
    $core.Iterable<ProtobufCommand>? runningCommands,
    $core.double? lastTimeMs,
  }) {
    final result = create();
    if (queuedCommands != null) result.queuedCommands.addAll(queuedCommands);
    if (runningCommands != null) result.runningCommands.addAll(runningCommands);
    if (lastTimeMs != null) result.lastTimeMs = lastTimeMs;
    return result;
  }

  ProtobufScheduler._();

  factory ProtobufScheduler.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProtobufScheduler.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProtobufScheduler',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'wpi.proto'),
      createEmptyInstance: create)
    ..pPM<ProtobufCommand>(1, _omitFieldNames ? '' : 'queuedCommands',
        subBuilder: ProtobufCommand.create)
    ..pPM<ProtobufCommand>(2, _omitFieldNames ? '' : 'runningCommands',
        subBuilder: ProtobufCommand.create)
    ..aD(3, _omitFieldNames ? '' : 'lastTimeMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtobufScheduler clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtobufScheduler copyWith(void Function(ProtobufScheduler) updates) =>
      super.copyWith((message) => updates(message as ProtobufScheduler))
          as ProtobufScheduler;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProtobufScheduler create() => ProtobufScheduler._();
  @$core.override
  ProtobufScheduler createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProtobufScheduler getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProtobufScheduler>(create);
  static ProtobufScheduler? _defaultInstance;

  /// Note: commands are generally queued by triggers, which occurs immediately before they are
  /// promoted and start running. Entries will only appear here when serializing a scheduler
  /// _after_ manually scheduling a command but _before_ calling scheduler.run()
  @$pb.TagNumber(1)
  $pb.PbList<ProtobufCommand> get queuedCommands => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<ProtobufCommand> get runningCommands => $_getList(1);

  /// How much time the scheduler took in its last `run()` invocation.
  @$pb.TagNumber(3)
  $core.double get lastTimeMs => $_getN(2);
  @$pb.TagNumber(3)
  set lastTimeMs($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastTimeMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastTimeMs() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
