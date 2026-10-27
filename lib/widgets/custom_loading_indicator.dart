import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/util/test_utils.dart';

class CustomLoadingIndicator extends CircularProgressIndicator {
  CustomLoadingIndicator({super.key}) : super(value: (isUnitTest ? 0 : null));
}
