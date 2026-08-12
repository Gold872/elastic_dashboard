import 'package:provider/provider.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/widgets/draggable_containers/draggable_layout_container.dart';
import 'models/list_layout_model.dart';

class DraggableListLayout extends DraggableLayoutContainer {
  const DraggableListLayout({super.key, super.updateFunctions}) : super();

  @override
  Widget build(BuildContext context) {
    ListLayoutModel model = context.watch<ListLayoutModel>();

    return Stack(
      children: [
        Positioned(
          left: model.displayRect.left,
          top: model.displayRect.top,
          child: model.getWidgetContainer(context),
        ),
        ...super.getStackChildren(model),
      ],
    );
  }
}
