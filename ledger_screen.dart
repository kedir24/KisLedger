import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/ledger_repository.dart';
import '../models/account.dart';
import '../state/ledger_state.dart';
import '../theme.dart';
import '../utils/money.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  String? _accountId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LedgerState>();
    final s = state.s;
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final account = _accountId == null
        ? (state.accounts.isEmpty ? null : state.accounts.first)
        : state.accountById(_accountId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: account?.id,
            decoration: InputDecoration(labelText: s.account),
            items: state.accounts
                .map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.code} · ${state.accountName(a.id)}',
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _accountId = v),
          ),
        ),
        if (account != null)
          Expanded(child: _LedgerTable(account: account)),
      ],
    );
  }
}

class _LedgerTable extends StatelessWidget {
  const _LedgerTable({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LedgerState>();
    final s = state.s;

    return FutureBuilder<List<LedgerRow>>(
      future: state.repo.ledgerFor(account),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data!;
        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(s.noEntriesYet, textAlign: TextAlign.center),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Text(s.balance,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text(Money.format(rows.last.runningBalance),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                  child: DataTable(
                    columnSpacing: 20,
                    headingRowHeight: 40,
                    columns: [
                      DataColumn(label: Text(s.date)),
                      DataColumn(label: Text(s.memo)),
                      DataColumn(label: Text(s.debit), numeric: true),
                      DataColumn(label: Text(s.credit), numeric: true),
                      DataColumn(
                          label: Text(s.runningBalance), numeric: true),
                    ],
                    rows: rows
                        .map((r) => DataRow(cells: [
                              DataCell(Text(state.formatDate(
                                  r.transaction.date,
                                  short: true))),
                              DataCell(SizedBox(
                                width: 140,
                                child: Text(
                                  r.transaction.memo.isEmpty
                                      ? r.line.note
                                      : r.transaction.memo,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                              DataCell(Text(
                                r.line.debit == 0
                                    ? '—'
                                    : Money.format(r.line.debit,
                                        withSymbol: false),
                                style:
                                    const TextStyle(color: Tokens.debit),
                              )),
                              DataCell(Text(
                                r.line.credit == 0
                                    ? '—'
                                    : Money.format(r.line.credit,
                                        withSymbol: false),
                                style:
                                    const TextStyle(color: Tokens.credit),
                              )),
                              DataCell(Text(
                                Money.format(r.runningBalance,
                                    withSymbol: false),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              )),
                            ]))
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
