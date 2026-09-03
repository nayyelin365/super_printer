import 'package:go_router/go_router.dart';

import '../../features/alarm/presentation/alarm_editor_screen.dart';
import '../../features/alarm/presentation/alarm_list_screen.dart';
import '../../features/food_selection/presentation/food_selection_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/label_printing/presentation/label_print_screen.dart';
import '../../features/log_sheet/domain/log_type.dart';
import '../../features/log_sheet/presentation/log_entry_form_screen.dart';
import '../../features/log_sheet/presentation/log_home_screen.dart';
import '../../features/log_sheet/presentation/log_sheet_screen.dart';
import '../../features/log_sheet/presentation/sushi_rice_batch_detail_screen.dart';
import '../../features/log_sheet/presentation/sushi_rice_dashboard_screen.dart';
import '../../features/log_sheet/presentation/sushi_rice_new_batch_screen.dart';
import '../../features/log_sheet/presentation/sushi_rice_ph_log_sheet_screen.dart';
import '../../features/printer_settings/presentation/printer_settings_screen.dart';
import '../../features/receiving_log/presentation/add_receiving_invoice_screen.dart';
import '../../features/receiving_log/presentation/add_receiving_item_screen.dart';
import '../../features/receiving_log/presentation/receiving_log_list_screen.dart';
import '../../features/template_builder/presentation/template_builder_screen.dart';
import '../../features/template_selection/presentation/template_selection_screen.dart';
import '../widgets/app_shell.dart';

/// Top-level navigation for the whole app. Home (`/`) is a plain top-level
/// route — the sidebar-free splash page — while every other screen lives
/// under one [ShellRoute] so [AppShell] (the sidebar) stays mounted across
/// navigation from Template Selection onward. `context.push` drills into
/// the guided flow (Template Selection -> Food Selection -> Print) while
/// keeping a real back stack; `context.go` is used for the sidebar's
/// direct jumps (Print / Settings) and for "Change Template", which
/// intentionally clears back to a fresh Template Selection instead of
/// stacking.
///
/// A factory rather than a module-level singleton — [GoRouter] carries its
/// own navigation-history state, so a shared instance would leak state
/// between separate app runs (most visibly: widget tests, where every test
/// would otherwise resume wherever the previous test's router was left).
GoRouter createAppRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    ShellRoute(
      builder: (context, state, child) => AppShell(
        location: state.uri.toString(),
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/templates',
          builder: (context, state) => const TemplateSelectionScreen(),
        ),
        GoRoute(
          path: '/templates/builder',
          builder: (context, state) => const TemplateBuilderScreen(),
        ),
        GoRoute(
          path: '/food-selection',
          builder: (context, state) => const FoodSelectionScreen(),
        ),
        GoRoute(path: '/print', builder: (context, state) => const LabelPrintScreen()),
        GoRoute(path: '/alarms', builder: (context, state) => const AlarmListScreen()),
        GoRoute(
          path: '/alarms/editor',
          builder: (context, state) => const AlarmEditorScreen(),
        ),
        GoRoute(path: '/settings', builder: (context, state) => const PrinterSettingsScreen()),
        GoRoute(path: '/logs', builder: (context, state) => const LogHomeScreen()),
        GoRoute(
          path: '/logs/:logType',
          builder: (context, state) =>
              LogSheetScreen(logType: LogType.values.byName(state.pathParameters['logType']!)),
        ),
        GoRoute(
          path: '/logs/:logType/entry',
          builder: (context, state) =>
              LogEntryFormScreen(logType: LogType.values.byName(state.pathParameters['logType']!)),
        ),
        GoRoute(
          path: '/logs/sushiRice/dashboard',
          builder: (context, state) => const SushiRiceDashboardScreen(),
        ),
        GoRoute(
          path: '/logs/sushiRice/new',
          builder: (context, state) => const SushiRiceNewBatchScreen(),
        ),
        GoRoute(
          path: '/logs/sushiRice/batch/:batchId',
          builder: (context, state) =>
              SushiRiceBatchDetailScreen(batchId: state.pathParameters['batchId']!),
        ),
        GoRoute(
          path: '/logs/sushiRice/report',
          builder: (context, state) => const SushiRicePhLogSheetScreen(),
        ),
        GoRoute(
          path: '/logs/sushiRice/report/:batchId',
          builder: (context, state) =>
              SushiRicePhLogSheetScreen(batchId: state.pathParameters['batchId']!),
        ),
        GoRoute(
          path: '/receiving-log',
          builder: (context, state) => const ReceivingLogListScreen(),
        ),
        GoRoute(
          path: '/receiving-log/new',
          builder: (context, state) => const AddReceivingInvoiceScreen(),
        ),
        GoRoute(
          path: '/receiving-log/invoice/:invoiceId/new-item',
          builder: (context, state) =>
              AddReceivingItemScreen(invoiceId: state.pathParameters['invoiceId']!),
        ),
      ],
    ),
  ],
);
