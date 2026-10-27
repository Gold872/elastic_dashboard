import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class EmptyNTWidget extends NTWidget {
  const EmptyNTWidget({super.key}) : super();

  @override
  Widget build(BuildContext context) => const Placeholder();
}
