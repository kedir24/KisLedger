import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/ledger_state.dart';
import '../theme.dart';
import '../utils/money.dart';
import 'journal_entry_screen.dart';
import 'quick_entry_sheet.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LedgerState>();
    final s = state.s;

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: state.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(s.appName,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 10),
          _CashCard(
              label: s.cashOnHand, santim: state.cashOnHand),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: s.income,
                  santim: state.totalIncome,
                  color: Tokens.inkGreenLight,
                  icon: Icons.south_west,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: s.expense,
                  santim: state.totalExpense,
                  color: Tokens.credit,
                  icon: Icons.north_east,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NetCard(label: s.net, santim: state.netResult),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const QuickEntrySheet(),
                  ),
                  icon: const Icon(Icons.bolt_outlined),
                  label: Text(s.quickEntry),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(s.recentEntries,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (state.recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(s.noEntriesYet,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6))),
            )
          else
            ...state.recent.take(8).map((tx) => _EntryRow(txId: tx.id)),
        ],
      ),
    );
  }
}

class _CashCard extends StatelessWidget {
  const _CashCard({required this.label, required this.santim});
  final String label;
  final int santim;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: Colors.white.withOpacity(0.8))),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.format(santim),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.santim,
    required this.color,
    required this.icon,
  });
  final String label;
  final int santim;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.65))),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(Money.format(santim, withSymbol: false),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetCard extends StatelessWidget {
  const _NetCard({required this.label, required this.santim});
  final String label;
  final int santim;

  @override
  Widget build(BuildContext context) {
    final positive = santim >= 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(
              Money.format(santim),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: positive ? Tokens.inkGreenLight : Tokens.credit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.txId});
  final String txId;

  @override
  Widget build(BuildContext context) {
    final state = context.read<LedgerState>();
    final tx = state.recent.firstWhere((t) => t.id == txId);

    return FutureBuilder(
      future: state.repo.linesOf(tx.id),
      builder: (context, snap) {
        final lines = snap.data ?? const [];
        final total = lines.fold<int>(0, (sum, l) => sum + l.debit);
        final names = lines
            .map((l) => state.accountName(l.accountId))
            .toSet()
            .take(2)
            .join(' → ');

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(tx.memo.isEmpty ? names : tx.memo,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${state.formatDate(tx.date)} · $names',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(Money.format(total, withSymbol: false),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JournalEntryScreen(existingId: tx.id),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
