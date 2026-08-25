import 'package:flutter/services.dart';

import 'package:material_ui/material_ui.dart';

class DialogTextInput extends StatefulWidget {
  final Function(String value) onSubmit;
  final TextInputFormatter? formatter;
  final String? label;
  final String? initialText;
  final bool allowEmptySubmission;
  final bool autoFocus;
  final bool enabled;
  final bool updateOnChanged;

  final TextEditingController? textEditingController;

  const DialogTextInput({
    super.key,
    required this.onSubmit,
    this.label,
    this.initialText,
    this.allowEmptySubmission = false,
    this.enabled = true,
    this.formatter,
    this.textEditingController,
    this.autoFocus = false,
    this.updateOnChanged = false,
  });

  @override
  State<DialogTextInput> createState() => _DialogTextInputState();
}

class _DialogTextInputState extends State<DialogTextInput> {
  bool focused = false;

  late final TextEditingController textEditingController =
      widget.textEditingController ??
      TextEditingController(text: widget.initialText);

  @override
  void didUpdateWidget(DialogTextInput oldWidget) {
    if (widget.initialText != null) {
      textEditingController.text = widget.initialText!;
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(4.0),
    child: Focus(
      onFocusChange: (value) {
        if (focused && !value) {
          String textValue = textEditingController.text;
          if (textValue.isNotEmpty || widget.allowEmptySubmission) {
            widget.onSubmit.call(textValue);
          }
        }
        focused = value;
      },
      child: TextField(
        autofocus: widget.autoFocus,
        enabled: widget.enabled,
        onChanged: (value) {
          if (widget.updateOnChanged &&
              (value.isNotEmpty || widget.allowEmptySubmission)) {
            widget.onSubmit.call(value);
          }
        },
        onSubmitted: (value) {
          if (value.isNotEmpty || widget.allowEmptySubmission) {
            widget.onSubmit.call(value);
            focused = false;
          }
        },
        onTapOutside: (_) {
          if (!focused) {
            return;
          }
          FocusManager.instance.primaryFocus?.unfocus();
        },
        controller: textEditingController,
        inputFormatters: (widget.formatter != null)
            ? [widget.formatter!]
            : null,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          labelText: widget.label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    ),
  );
}
