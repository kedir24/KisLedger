import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/ledger_state.dart';
import '../theme.dart';
import '../utils/strings.dart';
import 'auth_sheet.dart';

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
        _CloudSyncCard(state: state, s: s),
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

class _CloudSyncCard extends StatelessWidget {
  const _CloudSyncCard({required this.state, required this.s});
  final LedgerState state;
  final S s;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(s.cloudSync,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (!state.cloudConfigured)
              Text(s.cloudNotConfigured,
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6)))
            else if (!state.isSignedIn)
              FilledButton.icon(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const AuthSheet(),
                ),
                icon: const Icon(Icons.login),
                label: Text(s.signIn),
              )
            else
              _SignedInSync(state: state, s: s),
          ],
        ),
      ),
    );
  }
}

class _SignedInSync extends StatelessWidget {
  const _SignedInSync({required this.state, required this.s});
  final LedgerState state;
  final S s;

  @override
  Widget build(BuildContext context) {
    final syncing = state.syncStatus == SyncStatus.syncing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('${s.signedInAs}: ${state.userEmail ?? ''}',
                  overflow: TextOverflow.ellipsis),
            ),
            TextButton(
              onPressed: () => state.signOut(),
              child: Text(s.signOut),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              state.pendingCount == 0
                  ? Icons.check_circle
                  : Icons.cloud_upload_outlined,
              size: 16,
              color: state.pendingCount == 0
                  ? Tokens.inkGreenLight
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 6),
            Text(
              state.pendingCount == 0
                  ? s.allSynced
                  : '${s.pendingChanges}: ${state.pendingCount}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        if (state.syncStatus == SyncStatus.error &&
            state.syncError != null) ...[
          const SizedBox(height: 6),
          Text(state.syncError!,
              style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: syncing ? null : () => state.syncNow(),
          icon: syncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync),
          label: Text(syncing ? s.syncing : s.syncNow),
        ),
      ],
    );
  }
}
