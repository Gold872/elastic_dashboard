import 'package:flutter/material.dart';

import 'package:elastic_dashboard/services/nt_connection.dart';

class NetworkTablesTopicDialog extends StatefulWidget {
  final NTConnection ntConnection;
  final Function(String?) onTopicSelected;

  const NetworkTablesTopicDialog({
    super.key,
    required this.ntConnection,
    required this.onTopicSelected,
  });

  @override
  State<NetworkTablesTopicDialog> createState() =>
      _NetworkTablesTopicDialogState();
}

class _NetworkTablesTopicDialogState extends State<NetworkTablesTopicDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  List<String> get _allTopics =>
      widget.ntConnection.announcedTopics().values.map((e) => e.name).toList();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String> filteredTopics = _allTopics
        .where((topic) =>
            topic.toLowerCase().contains(_searchText.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text('Select a Topic'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search Topics',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 300,
            height: 400,
            child: ListView.builder(
              itemCount: filteredTopics.length,
              itemBuilder: (context, index) {
                String topic = filteredTopics[index];
                return ListTile(
                  title: Text(topic),
                  onTap: () {
                    widget.onTopicSelected.call(topic);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onTopicSelected.call(null);
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
