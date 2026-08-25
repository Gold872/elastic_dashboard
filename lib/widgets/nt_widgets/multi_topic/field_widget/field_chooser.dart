import 'package:flutter/material.dart';

import 'package:dropdown_button2/dropdown_button2.dart';

import 'package:elastic_dashboard/services/field_images.dart';

class FieldChooser extends StatefulWidget {
  final List<Field>? choices;
  final String? initialValue;
  final void Function(String?) onSelectionChanged;

  const FieldChooser({
    super.key,
    this.choices,
    this.initialValue,
    required this.onSelectionChanged,
  });

  @override
  State<FieldChooser> createState() => _FieldChooserState();
}

class _FieldChooserState extends State<FieldChooser> {
  late String? selectedValue;

  @override
  void initState() {
    super.initState();

    selectedValue = widget.initialValue;
  }

  DropdownMenuItem<String> _buildDropdownItem(String value) =>
      DropdownMenuItem<String>(
        value: value,
        child: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Text(value),
        ),
      );

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: ExcludeFocus(
            child: DropdownButton2<String>(
              isExpanded: true,
              style: theme.textTheme.bodyMedium,
              dropdownStyleData: DropdownStyleData(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15.0),
                ),
              ),
              buttonStyleData: ButtonStyleData(height: 40),
              menuItemStyleData: MenuItemStyleData(height: 30),
              items: [
                DropdownMenuItem<String>(
                  enabled: false,
                  value: null,
                  child: Text(
                    'FRC Fields',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...?widget.choices
                    ?.where((e) => e.isFrc && e.game != null)
                    .map(
                      (Field item) => _buildDropdownItem(item.game!),
                    ),
                DropdownMenuItem<String>(
                  enabled: false,
                  value: null,
                  child: Text(
                    'FTC Fields',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...?widget.choices
                    ?.where((e) => e.isFtc && e.game != null)
                    .map(
                      (Field item) => _buildDropdownItem(item.game!),
                    ),
              ],
              value: selectedValue,
              onChanged: (value) {
                setState(() {
                  selectedValue = value;

                  widget.onSelectionChanged.call(value);
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
