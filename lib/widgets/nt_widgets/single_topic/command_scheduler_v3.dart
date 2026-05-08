import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/generated/protobuf_commands.pb.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class CommandSchedulerV3 extends NTWidget {
  static const String widgetType = 'SchedulerV3';

  const CommandSchedulerV3({super.key});

  @override
  Widget build(BuildContext context) {
    SingleTopicNTWidgetModel model = cast(context.watch<NTWidgetModel>());

    return ValueListenableBuilder(
      valueListenable: model.subscription!,
      builder: (context, value, child) {
        List<int> rawData = tryCast(value) ?? [];

        ProtobufScheduler schedulerData = ProtobufScheduler();

        try {
          schedulerData.mergeFromBuffer(rawData);
        } catch (_) {}

        Widget buildCommandView(ProtobufCommand command) => ListTile(
          dense: true,
          isThreeLine: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
          minVerticalPadding: 2,
          title: Text(command.name),
          subtitle: Text(
            '  ${command.requirements.map((e) => e.name).join(', ')}\n  Last: ${command.lastTimeMs.toStringAsFixed(3)} ms | Total: ${command.totalTimeMs.toStringAsFixed(2)} ms',
          ),
        );

        final Map<int, ProtobufCommand> idToCommand = {};
        final Map<int, List<int>> parentToChildrenIds = {};
        final List<ProtobufCommand> roots = [];

        for (final command in schedulerData.runningCommands) {
          idToCommand[command.id] = command;
          if (!command.hasParentId()) {
            roots.add(command);
          } else {
            parentToChildrenIds
                .putIfAbsent(command.parentId, () => [])
                .add(command.id);
          }
        }

        List<ProtobufCommand> findLeaves(ProtobufCommand root) {
          List<ProtobufCommand> leaves = [];
          List<ProtobufCommand> stack = [root];
          while (stack.isNotEmpty) {
            final current = stack.removeLast();
            final childrenIds = parentToChildrenIds[current.id];
            if (childrenIds == null || childrenIds.isEmpty) {
              if (current.id != root.id) {
                leaves.add(current);
              }
            } else {
              for (final childId in childrenIds) {
                stack.add(idToCommand[childId]!);
              }
            }
          }
          return leaves;
        }

        Iterable<Widget> commandWidgets = roots.expand((root) sync* {
          yield buildCommandView(root);
          final leaves = findLeaves(root);
          for (final leaf in leaves) {
            yield Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: buildCommandView(leaf),
            );
          }
        });

        return ListView(
          children: [
            Center(
              child: Text(
                'Loop Time: ${schedulerData.lastTimeMs.toStringAsFixed(3)} ms',
              ),
            ),
            ...commandWidgets,
          ],
        );
      },
    );
  }
}
