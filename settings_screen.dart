import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/ledger_state.dart';
import '../utils/strings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LedgerState>();
    final s = state.s;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.settings,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SegmentedButton<AppLang>(
                  segments: const [
                    ButtonSegment(value: AppLang.am, label: Text('አማርኛ')),
                    ButtonSegment(value: AppLang.en, label: Text('English')),
                  ],
                  selected: {state.lang},
                  onSelectionChanged: (sel) =>
                      state.setLanguage(sel.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.calendarSystem,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SegmentedButton<CalendarSystem>(
                  segments: [
                    ButtonSegment(
                        value: CalendarSystem.ethiopian,
                        label: Text(s.ethiopianCalendar)),
                    ButtonSegment(
                        value: CalendarSystem.gregorian,
                        label: Text(s.gregorianCalendar)),
                  ],
                  selected: {state.calendar},
                  onSelectionChanged: (sel) =>
                      state.setCalendar(sel.first),
                ),
                const SizedBox(height: 10),
                Text(
                  state.formatDate(DateTime.now()),
                  style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.account,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...state.accounts.map((a) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(state.accountName(a.id)),
                      subtitle: Text('${a.code} · ${a.type.name}'),
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
