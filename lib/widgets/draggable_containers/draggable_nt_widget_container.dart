import 'package:material_ui/material_ui.dart';

import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/draggable_containers/draggable_widget_container.dart';
import 'models/nt_widget_container_model.dart';

class DraggableNTWidgetContainer extends DraggableWidgetContainer {
  const DraggableNTWidgetContainer({super.key, super.updateFunctions})
    : super();

  @override
  Widget build(BuildContext context) {
    NTWidgetContainerModel model = context.watch<NTWidgetContainerModel>();

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
