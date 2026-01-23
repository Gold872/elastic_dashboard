import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ComboBoxChooserModel extends MultiTopicNTWidgetModel {
  @override
  String type = ComboBoxChooser.widgetType;

  String get optionsTopicName => '$topic/options';
  String get selectedTopicName => '$topic/selected';
  String get activeTopicName => '$topic/active';
  String get defaultTopicName => '$topic/default';

  NT4Subscription? optionsSubscription;
  NT4Subscription? selectedSubscription;
  NT4Subscription? activeSubscription;
  NT4Subscription? defaultSubscription;

  @override
  List<NT4Subscription> get subscriptions => [
    ?optionsSubscription,
    ?selectedSubscription,
    ?activeSubscription,
    ?defaultSubscription,
  ];

  Listenable? chooserStateListenable;

  final TextEditingController _searchController = TextEditingController();

  String? previousDefault;
  String? previousSelected;
  String? previousActive;
  List<String>? previousOptions;

  NT4Topic? _selectedTopic;

  bool _sortOptions = false;

  bool get sortOptions => _sortOptions;

  set sortOptions(bool value) {
    _sortOptions = value;
    previousOptions?.sort();
    refresh();
  }

  ComboBoxChooserModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    bool sortOptions = false,
    super.period,
  }) : _sortOptions = sortOptions,
       super();

  ComboBoxChooserModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _sortOptions = tryCast(jsonData['sort_options']) ?? _sortOptions;
  }

  @override
  void initializeSubscriptions() {
    if (topic == null) {
      optionsSubscription = null;
      selectedSubscription = null;
      activeSubscription = null;
      defaultSubscription = null;
      chooserStateListenable = null;
      return;
    }

    optionsSubscription = ntConnection.subscribe(
      optionsTopicName,
      super.period,
    );
    selectedSubscription = ntConnection.subscribe(
      selectedTopicName,
      super.period,
    );
    activeSubscription = ntConnection.subscribe(activeTopicName, super.period);
    defaultSubscription = ntConnection.subscribe(
      defaultTopicName,
      super.period,
    );
    chooserStateListenable = Listenable.merge(subscriptions);
    chooserStateListenable!.addListener(onChooserStateUpdate);

    previousOptions = null;
    previousActive = null;
    previousDefault = null;
    previousSelected = null;

    // Initial caching of the chooser state, when switching
    // topics the listener won't be called, so we have to call it manually
    onChooserStateUpdate();
  }

  @override
  void resetSubscription() {
    _selectedTopic = null;
    chooserStateListenable?.removeListener(onChooserStateUpdate);

    super.resetSubscription();
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'sort_options': _sortOptions,
  };

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    DialogToggleSwitch(
      label: 'Sort Options Alphabetically',
      initialValue: _sortOptions,
      onToggle: (value) {
        sortOptions = value;
      },
    ),
  ];

  void onChooserStateUpdate() {
    List<Object?>? rawOptions = optionsSubscription?.value
        ?.tryCast<List<Object?>>();

    List<String>? currentOptions = rawOptions?.whereType<String>().toList();

    if (sortOptions) {
      currentOptions?.sort();
    }

    String? currentActive = tryCast(activeSubscription?.value);
    if (currentActive != null && currentActive.isEmpty) {
      currentActive = null;
    }

    String? currentSelected = tryCast(selectedSubscription?.value);
    if (currentSelected != null && currentSelected.isEmpty) {
      currentSelected = null;
    }

    String? currentDefault = tryCast(defaultSubscription?.value);
    if (currentDefault != null && currentDefault.isEmpty) {
      currentDefault = null;
    }

    bool hasValue =
        currentOptions != null ||
        currentActive != null ||
        currentDefault != null;

    bool publishCurrent =
        hasValue && previousSelected != null && currentSelected == null;

    // We only want to publish the selected topic if we're getting values
    // from the others, since it means the chooser is published on network tables
    if (hasValue) {
      publishSelectedTopic();
    }

    if (currentOptions != null) {
      previousOptions = currentOptions;
    }
    if (currentSelected != null) {
      previousSelected = currentSelected;
    }
    if (currentActive != null) {
      previousActive = currentActive;
    }
    if (currentDefault != null) {
      previousDefault = currentDefault;
    }

    if (publishCurrent) {
      publishSelectedValue(previousSelected, true);
    }

    notifyListeners();
  }

  void publishSelectedTopic() {
    if (_selectedTopic != null) {
      return;
    }

    NT4Topic? existing = ntConnection.getTopicFromName(selectedTopicName);

    if (existing != null) {
      existing.properties.addAll({'retained': true});
      ntConnection.publishTopic(existing);
      _selectedTopic = existing;
    } else {
      _selectedTopic = ntConnection.publishNewTopic(
        selectedTopicName,
        NT4Type.string(),
        properties: {'retained': true},
      );
    }
  }

  void publishSelectedValue(String? selected, [bool initial = false]) {
    if (selected == null || !ntConnection.isNT4Connected) {
      return;
    }

    if (_selectedTopic == null) {
      publishSelectedTopic();
    }

    ntConnection.updateDataFromTopic(
      _selectedTopic!,
      selected,
      initial ? 0 : null,
    );
  }
}

class ComboBoxChooser extends NTWidget {
  static const String widgetType = 'ComboBox Chooser';

  const ComboBoxChooser({super.key}) : super();

  @override
  Widget build(BuildContext context) {
    ComboBoxChooserModel model = cast(context.watch<NTWidgetModel>());

    String? preview = model.previousSelected ?? model.previousDefault;

    bool showWarning = model.previousActive != preview;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Container(
            constraints: const BoxConstraints(minHeight: 36.0),
            child: _StringChooserDropdown(
              selected: preview,
              options: model.previousOptions ?? [preview ?? ''],
              textController: model._searchController,
              onValueChanged: (String? value) {
                model.publishSelectedValue(value);
              },
            ),
          ),
        ),
        const SizedBox(width: 5),
        (showWarning)
            ? const Tooltip(
                message:
                    'Selected value has not been published to Network Tables.\nRobot code will not be receiving the correct value.',
                child: Icon(Icons.priority_high, color: Colors.red),
              )
            : const Icon(Icons.check, color: Colors.green),
      ],
    );
  }
}

class _StringChooserDropdown extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final Function(String? value) onValueChanged;
  final TextEditingController textController;

  const _StringChooserDropdown({
    required this.options,
    required this.onValueChanged,
    required this.textController,
    this.selected,
  });

  @override
  Widget build(BuildContext context) => ExcludeFocus(
    child: Tooltip(
      message: selected ?? '',
      waitDuration: const Duration(milliseconds: 250),
      child: LayoutBuilder(
        builder: (context, constraints) => DropdownButton2<String>(
          isExpanded: true,
          value: selected,
          selectedItemBuilder: (context) => [
            ...options.map(
              (String option) => Container(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  option,
                  style: Theme.of(context).textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15.0),
            ),
            maxHeight: 250,
            width: max(constraints.maxWidth, 250),
          ),
          dropdownSearchData: DropdownSearchData(
            searchController: textController,
            searchMatchFn: (item, searchValue) =>
                item.value.toString().toLowerCase().contains(
                  searchValue.toLowerCase(),
                ),
            searchInnerWidgetHeight: 50,
            searchInnerWidget: Container(
              color: Theme.of(context).colorScheme.surface,
              height: 50,
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 4,
                right: 8,
                left: 8,
              ),
              child: TextFormField(
                expands: true,
                maxLines: null,
                controller: textController,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  label: const Text('Search'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          items: options
              .map(
                (String option) => DropdownMenuItem(
                  value: option,
                  child: Text(
                    option,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
              .toList(),
          onMenuStateChange: (isOpen) {
            if (!isOpen) {
              textController.clear();
            }
          },
          onChanged: onValueChanged,
        ),
      ),
    ),
  );
}
