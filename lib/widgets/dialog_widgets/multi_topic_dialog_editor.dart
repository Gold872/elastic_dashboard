import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:flutter/material.dart';

import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/networktables_topic_dialog.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/multi_topic/multi_topic_graph.dart';

class MultiTopicDialogEditor extends StatefulWidget {
  final NTConnection ntConnection;
  final MultiTopicNTWidgetModel model;
  final List<TopicProperties> topicProperties;
  final Function(List<TopicProperties>) onTopicPropertyChanged;
  final Widget Function(
      BuildContext context,
      TopicProperties currentProperties,
      VoidCallback onDataChanged,
      ) customPropertyBuilder;

  const MultiTopicDialogEditor({
    super.key,
    required this.ntConnection,
    required this.model,
    required this.topicProperties,
    required this.onTopicPropertyChanged,
    required this.customPropertyBuilder,
  });

  @override
  State<MultiTopicDialogEditor> createState() => _MultiTopicDialogEditorState();
}

class _MultiTopicDialogEditorState extends State<MultiTopicDialogEditor> {
  void _showTopicDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return NetworkTablesTopicDialog(
          ntConnection: widget.ntConnection,
          onTopicSelected: (topic) {
            if (topic == null) {
              return;
            }

            setState(() {
              widget.topicProperties.add(
                TopicProperties(
                  topic: topic,
                  color: Colors.primaries[
                  widget.topicProperties.length % Colors.primaries.length],
                ),
              );

              widget.onTopicPropertyChanged.call(widget.topicProperties);
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...widget.topicProperties.map(
              (properties) {
            return Column(
              children: [
                const Divider(),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: DialogTextInput(
                        onSubmit: (value) {
                          setState(() {
                            properties.topic = value;
                            widget.onTopicPropertyChanged
                                .call(widget.topicProperties);
                          });
                        },
                        label: 'Topic',
                        initialText: properties.topic,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          widget.topicProperties.remove(properties);
                          widget.onTopicPropertyChanged
                              .call(widget.topicProperties);
                        });
                      },
                      icon: const Icon(Icons.delete),
                      tooltip: 'Remove Topic',
                    ),
                  ],
                ),
                widget.customPropertyBuilder.call(
                  context,
                  properties,
                      () {
                    setState(() {
                      widget.onTopicPropertyChanged.call(widget.topicProperties);
                    });
                  },
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 5),
        ElevatedButton.icon(
          onPressed: () => _showTopicDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Add Topic'),
        ),
      ],
    );
  }
}
