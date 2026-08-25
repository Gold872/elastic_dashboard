import 'package:material_ui/material_ui.dart';

class DialogToggleSwitch extends StatefulWidget {
  final Function(bool value) onToggle;
  final bool initialValue;
  final String? label;

  const DialogToggleSwitch({
    super.key,
    this.initialValue = false,
    this.label,
    required this.onToggle,
  });

  @override
  State<DialogToggleSwitch> createState() => _DialogToggleSwitchState();
}

class _DialogToggleSwitchState extends State<DialogToggleSwitch> {
  late bool value = widget.initialValue;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4.0),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5.0),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: Text(widget.label ?? '', textAlign: TextAlign.center),
          ),
          const SizedBox(width: 3),
          Switch(
            onChanged: (value) {
              widget.onToggle(value);

              setState(() => this.value = value);
            },
            value: value,
          ),
        ],
      ),
    ),
  );
}
