import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/ledger_repository.dart';
import '../models/journal.dart';
import '../state/ledger_state.dart';
import '../theme.dart';
import '../utils/money.dart';
import '../utils/strings.dart';
import '../widgets/ethiopian_date_picker.dart';

/// Draft line held while the user is typing; amounts stay as text so a
/// half-typed number never corrupts the totals.
class _DraftLine {
  String? accountId;
  String amountText = '';
  bool isDebit = true;
  String note = '';

  int get santim => Money.parse(amountText) ?? 0;
}

class JournalEntryScreen extends StatefulWidget {
  const JournalEntryScreen({super.key, this.existingId});

  /// When set the screen opens read-only, showing a posted entry.
  final String? existingId;

  @override
  State<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends State<JournalEntryScreen> {
  DateTime _date = DateTime.now();
  final _memo = TextEditingController();
  final _reference = TextEditingController();
  final List<_DraftLine> _lines = [
    _DraftLine()..isDebit = true,
    _DraftLine()..isDebit = false,
  ];
  bool _saving = false;

  @override
  void dispose() {
    _memo.dispose();
    _reference.dispose();
    super.dispose();
  }

  int get _totalDebit =>
      _lines.where((l) => l.isDebit).fold(0, (s, l) => s + l.santim);
  int get _totalCredit =>
      _lines.where((l) => !l.isDebit).fold(0, (s, l) => s + l.santim);
  int get _difference => _totalDebit - _totalCredit;
  bool get _balanced => _difference == 0 && _totalDebit > 0;

  JournalEntry _buildEntry(LedgerRepository repo) {
    final txId = repo.newId();
    return JournalEntry(
      transaction: LedgerTransaction(
        id: txId,
        date: _date,
        memo: _memo.text.trim(),
        reference: _reference.text.trim(),
        createdAt: DateTime.now(),
      ),
      lines: _lines
          .map((l) => JournalLine(
                id: repo.newId(),
                transactionId: txId,
                accountId: l.accountId ?? '',
                debit: l.isDebit ? l.santim : 0,
                credit: l.isDebit ? 0 : l.santim,
                note: l.note,
              ))
          .toList(),
    );
  }

  Future<void> _post() async {
    final state = context.read<LedgerState>();
    final s = state.s;
    final entry = _buildEntry(state.repo);
    final problem = entry.validate();
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.validationMessage(problem))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await state.post(entry);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.posted)));
    } on PostException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.validationMessage(e.code))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.existingId != null) {
      return _PostedEntryView(transactionId: widget.existingId!);
    }

    final state = context.watch<LedgerState>();
    final s = state.s;

    return Scaffold(
      appBar: AppBar(title: Text(s.newEntry)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = state.calendar == CalendarSystem.ethiopian
                        ? await showEthiopianDatePicker(
                            context: context,
                            initialDate: _date,
                            amharic: state.lang == AppLang.am,
                          )
                        : await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2015),
                            lastDate: DateTime(2100),
                          );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: s.date),
                    child: Text(state.formatDate(_date)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _reference,
                  decoration: InputDecoration(labelText: s.reference),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memo,
            decoration: InputDecoration(labelText: s.memo),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < _lines.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LineEditor(
                line: _lines[i],
                index: i,
                canRemove: _lines.length > 2,
                onChanged: () => setState(() {}),
                onRemove: () => setState(() => _lines.removeAt(i)),
              ),
            ),
          TextButton.icon(
            onPressed: () => setState(() => _lines.add(_DraftLine())),
            icon: const Icon(Icons.add),
            label: Text(s.addLine),
          ),
          const SizedBox(height: 12),
          _BalanceBar(
            totalDebit: _totalDebit,
            totalCredit: _totalCredit,
            difference: _difference,
            balanced: _balanced,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _balanced && !_saving ? _post : null,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(s.post),
          ),
        ],
      ),
    );
  }
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    required this.line,
    required this.index,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final _DraftLine line;
  final int index;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LedgerState>();
    final s = state.s;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: line.accountId,
                    decoration: InputDecoration(labelText: s.account),
                    hint: Text(s.selectAccount),
                    items: state.accounts
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(
                                '${a.code} · ${state.accountName(a.id)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      line.accountId = v;
                      onChanged();
                    },
                  ),
                ),
                if (canRemove)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close),
                    tooltip: s.cancel,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text(s.debit)),
                    ButtonSegment(value: false, label: Text(s.credit)),
                  ],
                  selected: {line.isDebit},
                  onSelectionChanged: (sel) {
                    line.isDebit = sel.first;
                    onChanged();
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    textAlign: TextAlign.end,
                    decoration: InputDecoration(
                      labelText: s.amount,
                      suffixText: 'ብር',
                    ),
                    onChanged: (v) {
                      line.amountText = v;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceBar extends StatelessWidget {
  const _BalanceBar({
    required this.totalDebit,
    required this.totalCredit,
    required this.difference,
    required this.balanced,
  });

  final int totalDebit;
  final int totalCredit;
  final int difference;
  final bool balanced;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LedgerState>().s;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(context, s.totalDebit, totalDebit, Tokens.debit),
            const SizedBox(height: 6),
            _row(context, s.totalCredit, totalCredit, Tokens.credit),
            const Divider(height: 22),
            Row(
              children: [
                Icon(
                  balanced ? Icons.check_circle : Icons.error_outline,
                  size: 18,
                  color: balanced ? Tokens.inkGreenLight : Tokens.credit,
                ),
                const SizedBox(width: 8),
                Text(
                  balanced ? s.balancedOk : s.difference,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: balanced ? Tokens.inkGreenLight : Tokens.credit,
                  ),
                ),
                const Spacer(),
                if (!balanced)
                  Text(
                    Money.format(difference.abs()),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Tokens.credit),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, int value, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Text(Money.format(value, withSymbol: false),
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Posted entries are immutable. The only action offered is a reversal.
class _PostedEntryView extends StatelessWidget {
  const _PostedEntryView({required this.transactionId});
  final String transactionId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LedgerState>();
    final s = state.s;

    return Scaffold(
      appBar: AppBar(title: Text(s.posted)),
      body: FutureBuilder(
        future: Future.wait([
          state.repo.transactionById(transactionId),
          state.repo.linesOf(transactionId),
        ]),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tx = snap.data![0] as LedgerTransaction?;
          final lines = snap.data![1] as List<JournalLine>;
          if (tx == null) return const SizedBox.shrink();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(state.formatDate(tx.date),
                  style: Theme.of(context).textTheme.titleMedium),
              if (tx.memo.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(tx.memo),
              ],
              const SizedBox(height: 16),
              ...lines.map((l) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        title: Text(state.accountName(l.accountId)),
                        subtitle: Text(l.debit > 0 ? s.debit : s.credit),
                        trailing: Text(
                          Money.format(
                              l.debit > 0 ? l.debit : l.credit,
                              withSymbol: false),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: l.debit > 0 ? Tokens.debit : Tokens.credit,
                          ),
                        ),
                      ),
                    ),
                  )),
              const SizedBox(height: 16),
              if (!tx.isReversal)
                OutlinedButton.icon(
                  onPressed: () async {
                    await state.reverse(tx.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.undo),
                  label: Text(s.reverse),
                ),
            ],
          );
        },
      ),
    );
  }
}
