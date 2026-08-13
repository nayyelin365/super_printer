import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_sidebar.dart';

/// Which panel of the printer workspace (print vs. settings) is showing.
///
/// Lives in a provider — rather than local widget state — so screens
/// outside the sidebar (e.g. an "Edit" action on the print screen, or a
/// close button on the settings screen) can switch panels too.
final appSectionProvider = StateProvider<AppSection>((ref) => AppSection.print);
