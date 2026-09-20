import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/ledger_repository.dart';
import 'screens/dashboard_screen.dart';
import 'screens/journal_entry_screen.dart';
import 'screens/ledger_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'services/supabase_config.dart';
import 'state/ledger_state.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Offline-first: if this fails (no network, or not configured at all)
  // the app still boots and works entirely from the local database.
  try {
    await SupabaseConfig.init();
  } catch (_) {}
  runApp(const SmartLedgerApp());
}

class SmartLedgerApp extends StatelessWidget {
  const SmartLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LedgerState(LedgerRepository())..load(),
      child: MaterialApp(
        title: 'SmartLedger',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(brightness: Brightness.light),
        darkTheme: buildTheme(brightness: Brightness.dark),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('am'), Locale('en')],
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<LedgerState>().trySyncInBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LedgerState>();
    final s = state.s;

    final pages = const [
      DashboardScreen(),
      LedgerScreen(),
      ReportsScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      floatingActionButton: _index == 0 || _index == 1
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const JournalEntryScreen()),
              ),
              icon: const Icon(Icons.add),
              label: Text(s.newEntry),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: s.dashboard),
          NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book),
              label: s.ledger),
          NavigationDestination(
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: const Icon(Icons.bar_chart),
              label: s.reports),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: s.settings),
        ],
      ),
    );
  }
}
