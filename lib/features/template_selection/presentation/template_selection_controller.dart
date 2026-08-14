import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../label_printing/domain/label_template.dart';

/// The label template currently active for the print flow. Set when the
/// user confirms a choice on the Template Selection screen; read by Food
/// Selection (to know which template to start a fresh label for) and by
/// the print page (to know which fields/renderer to show).
final selectedLabelTemplateProvider = StateProvider<LabelTemplateType>(
  (ref) => LabelTemplateType.pokeBowlBurrito,
);
