import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class DialogColorPicker extends StatefulWidget {
  final Function(Color color) onColorPicked;
  final String label;
  final Color initialColor;
  final Color? defaultColor;
  final MainAxisSize rowSize;

  const DialogColorPicker({
    super.key,
    required this.onColorPicked,
    required this.label,
    required this.initialColor,
    this.rowSize = MainAxisSize.min,
    this.defaultColor,
  });

  @override
  State<DialogColorPicker> createState() => _DialogColorPickerState();
}

class _DialogColorPickerState extends State<DialogColorPicker> {
  late Color initialColor;
  Color? selectedColor;

  TextEditingController hexInputController = TextEditingController();

  @override
  void initState() {
    super.initState();

    initialColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.center,
    mainAxisSize: widget.rowSize,
    children: [
      Text(widget.label),
      const SizedBox(width: 10),
      ElevatedButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Select Color'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    child: ColorPicker(
                      pickerColor: selectedColor ?? initialColor,
                      enableAlpha: false,
                      hexInputBar: true,
                      hexInputController: hexInputController,
                      onColorChanged: (Color color) {
                        setState(() {
                          selectedColor = color;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: hexInputController,
                      autofocus: false,
                      decoration: InputDecoration(
                        constraints: const BoxConstraints(maxWidth: 150),
                        contentPadding: const EdgeInsets.fromLTRB(
                          8,
                          4,
                          8,
                          4,
                        ),
                        labelText: 'Hex Code',
                        prefixText: '#',
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      maxLength: 6,
                      inputFormatters: [
                        // Any custom input formatter can be passed
                        // here or use any Form validator you want.
                        UpperCaseTextFormatter(),
                        FilteringTextInputFormatter.allow(
                          RegExp(kValidHexPattern),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    widget.onColorPicked.call(initialColor);

                    setState(() {
                      selectedColor = initialColor;
                    });
                  },
                  child: const Text('Cancel'),
                ),
                if (widget.defaultColor != null)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                      widget.onColorPicked.call(widget.defaultColor!);

                      setState(() {
                        selectedColor = widget.defaultColor!;
                      });
                    },
                    child: const Text('Restore Default'),
                  ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    widget.onColorPicked.call(
                      selectedColor ?? initialColor,
                    );

                    setState(() {
                      initialColor = selectedColor ?? initialColor;
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ).then((value) {
            bool dismissed = value ?? true;
            if (dismissed) {
              widget.onColorPicked.call(initialColor);

              setState(() {
                selectedColor = initialColor;
              });
            }
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: selectedColor ?? initialColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7.5),
          ),
        ),
        child: Container(),
      ),
    ],
  );
}
