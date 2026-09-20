import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../state/ledger_state.dart';
import '../utils/money.dart';

/// For users who do not think in debits and credits. The sheet asks two
/// plain questions and writes the correct pair behind the scenes.
class QuickEntrySheet extends StatefulWidget {
  const QuickEntrySheet({super.key});

  @override
  State<QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends State<QuickEntrySheet> {
  bool _isIncome = true;
  String? _categoryId;
  String _walletId = 'acc-cash';
  final _amount = TextEditingController();
  final _memo = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<LedgerState>();
    final santim = Money.parse(_amount.text);
    if (santim == null || santim == 0 || _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.s.validationMessage('zero_amount'))),
      );
      return;
    }

    setState(() => _saving = true);
    if (_isIncome) {
      await state.quickIncome(
        santim: santim,
        toAssetId: _walletId,
        incomeAccountId: _categoryId!,
        date: DateTime.now(),
        memo: _memo.text.trim(),
      );
    } else {
      await state.quickExpense(
        santim: santim,
        expenseAccountId: _categoryId!,
        fromAssetId: _walletId,
        date: DateTime.now(),
        memo: _memo.text.trim(),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LedgerState>();
    final s = state.s;
    final categories = state
        .byType(_isIncome ? AccountType.income : AccountType.expense);
    final wallets = state.byType(AccountType.asset);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.quickEntry,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(s.income)),
              ButtonSegment(value: false, label: Text(s.expense)),
            ],
            selected: {_isIncome},
            onSelectionChanged: (sel) => setState(() {
              _isIncome = sel.first;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration:
                InputDecoration(labelText: s.amount, suffixText: 'ብር'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _categoryId,
            hint: Text(s.selectAccount),
            decoration: InputDecoration(
                labelText: _isIncome ? s.income : s.expense),
            items: categories
                .map((a) => DropdownMenuItem(
                    value: a.id, child: Text(state.accountName(a.id))))
                .toList(),
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _walletId,
            decoration: InputDecoration(labelText: s.cashOnHand),
            items: wallets
                .map((a) => DropdownMenuItem(
                    value: a.id, child: Text(state.accountName(a.id))))
                .toList(),
            onChanged: (v) => setState(() => _walletId = v ?? 'acc-cash'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memo,
            decoration: InputDecoration(labelText: s.memo),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(s.save),
          ),
        ],
      ),
    );
  }
}
