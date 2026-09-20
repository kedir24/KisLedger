import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../services/pdf_export.dart';
import '../state/ledger_state.dart';
import '../theme.dart';
import '../utils/money.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _exporting = false;

  Future<void> _export(
    BuildContext context,
    Future<List<int>> Function() build,
  ) async {
    final state = context.read<LedgerState>();
    setState(() => _exporting = true);
    try {
      final bytes = await build();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } on PdfFontMissing {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.s.fontMissing)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LedgerState>();
    final s = state.s;
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            FutureBuilder<(int, int)>(
              future: state.repo.trialBalance(),
              builder: (context, snap) {
                final totals = snap.data ?? (0, 0);
                final ok = totals.$1 == totals.$2;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(s.trialBalance,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                            ),
                            _ExportButton(
                              disabled: _exporting,
                              onPressed: () => _export(context,
                                  () => PdfReports.trialBalancePdfBytes(state)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _line(s.totalDebit, totals.$1, Tokens.debit),
                        _line(s.totalCredit, totals.$2, Tokens.credit),
                        const Divider(height: 20),
                        Row(
                          children: [
                            Icon(ok ? Icons.check_circle : Icons.error_outline,
                                size: 18,
                                color: ok
                                    ? Tokens.inkGreenLight
                                    : Tokens.credit),
                            const SizedBox(width: 8),
                            Text(ok ? s.balancedOk : s.difference),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            _Section(
              title: s.income,
              rows: state.byType(AccountType.income),
              onExport: () => _export(
                  context, () => PdfReports.incomeStatementPdfBytes(state)),
              exporting: _exporting,
            ),
            const SizedBox(height: 14),
            _Section(
              title: s.expense,
              rows: state.byType(AccountType.expense),
              onExport: () => _export(
                  context, () => PdfReports.incomeStatementPdfBytes(state)),
              exporting: _exporting,
            ),
            const SizedBox(height: 14),
            _Section(
              title: s.assets,
              rows: state.byType(AccountType.asset),
              onExport: () => _export(
                  context, () => PdfReports.balanceSheetPdfBytes(state)),
              exporting: _exporting,
            ),
            const SizedBox(height: 14),
            _Section(
                title: s.liabilities,
                rows: state.byType(AccountType.liability)),
            const SizedBox(height: 14),
            _Section(title: s.equity, rows: state.byType(AccountType.equity)),
          ],
        ),
        if (_exporting)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 8)
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Text(s.exporting),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _line(String label, int value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label),
            const Spacer(),
            Text(Money.format(value, withSymbol: false),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onPressed, this.disabled = false});
  final VoidCallback onPressed;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: disabled ? null : onPressed,
      icon: const Icon(Icons.picture_as_pdf_outlined),
      tooltip: context.read<LedgerState>().s.exportPdf,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.rows,
    this.onExport,
    this.exporting = false,
  });
  final String title;
  final List<Account> rows;
  final VoidCallback? onExport;
  final bool exporting;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LedgerState>();
    final total =
        rows.fold<int>(0, (sum, a) => sum + (state.balances[a.id] ?? 0));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(Money.format(total, withSymbol: false),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (onExport != null)
                  _ExportButton(disabled: exporting, onPressed: onExport!),
              ],
            ),
            const SizedBox(height: 8),
            ...rows.map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(state.accountName(a.id),
                              overflow: TextOverflow.ellipsis)),
                      Text(Money.format(state.balances[a.id] ?? 0,
                          withSymbol: false)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
