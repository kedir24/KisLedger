import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/ledger_repository.dart';
import '../models/account.dart';
import '../state/ledger_state.dart';
import '../utils/money.dart';

/// Thrown when the Amharic font asset declared in pubspec.yaml is missing,
/// so the UI can explain what to fix instead of showing a blank PDF.
class PdfFontMissing implements Exception {
  const PdfFontMissing();
  @override
  String toString() =>
      'assets/fonts/NotoSansEthiopic-*.ttf not found — add the font files '
      'listed in pubspec.yaml before exporting a PDF with Amharic text.';
}

/// Builds the app's PDF reports. Amharic text needs the Noto Sans Ethiopic
/// font embedded — the default PDF base fonts have no Ge'ez glyphs.
class PdfReports {
  PdfReports._();

  static pw.ThemeData? _cachedTheme;

  static Future<pw.ThemeData> _theme() async {
    final cached = _cachedTheme;
    if (cached != null) return cached;

    Future<pw.Font> load(String asset) async {
      final ByteData data;
      try {
        data = await rootBundle.load(asset);
      } catch (_) {
        throw const PdfFontMissing();
      }
      return pw.Font.ttf(data);
    }

    final theme = pw.ThemeData.withFont(
      base: await load('assets/fonts/NotoSansEthiopic-Regular.ttf'),
      bold: await load('assets/fonts/NotoSansEthiopic-Bold.ttf'),
    );
    _cachedTheme = theme;
    return theme;
  }

  static pw.Widget _header(
    pw.Context context, {
    required String appName,
    required String title,
    required String generatedOn,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(appName,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 18)),
            pw.Text(generatedOn,
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey700)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(title,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 14)),
        pw.Divider(thickness: 1, color: PdfColors.grey400),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _totalsTable(
    List<List<String>> rows, {
    required List<String> headers,
    List<int>? numericCols,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
          color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignments: {
        for (var i = 0; i < headers.length; i++)
          i: (numericCols?.contains(i) ?? i > 0)
              ? pw.Alignment.centerRight
              : pw.Alignment.centerLeft,
      },
      cellHeight: 22,
      border: pw.TableBorder(
        horizontalInside: const pw.BorderSide(color: PdfColors.grey300),
        bottom: const pw.BorderSide(color: PdfColors.grey400),
      ),
    );
  }

  static pw.Widget _balancedFooter(bool balanced, String okLabel,
      String diffLabel, int differenceSantim) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        balanced
            ? okLabel
            : '$diffLabel: ${Money.format(differenceSantim.abs())}',
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: balanced ? PdfColors.green800 : PdfColors.red800,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Trial balance
  // ---------------------------------------------------------------------

  static Future<List<int>> trialBalancePdfBytes(LedgerState state) async {
    final theme = await _theme();
    final s = state.s;
    final doc = pw.Document(theme: theme);

    var totalDebit = 0;
    var totalCredit = 0;
    final rows = <List<String>>[];
    for (final a in state.accounts) {
      final bal = state.balances[a.id] ?? 0;
      if (bal == 0) continue;
      final debitCol = a.type.isDebitNormal ? bal : 0;
      final creditCol = a.type.isDebitNormal ? 0 : bal;
      totalDebit += debitCol;
      totalCredit += creditCol;
      rows.add([
        '${a.code} · ${state.accountName(a.id)}',
        debitCol == 0 ? '—' : Money.format(debitCol, withSymbol: false),
        creditCol == 0 ? '—' : Money.format(creditCol, withSymbol: false),
      ]);
    }
    rows.add([
      s.total,
      Money.format(totalDebit, withSymbol: false),
      Money.format(totalCredit, withSymbol: false),
    ]);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (ctx) => _header(
          ctx,
          appName: s.appName,
          title: s.trialBalance,
          generatedOn: state.formatDate(DateTime.now()),
        ),
        build: (ctx) => [
          _totalsTable(rows,
              headers: [s.account, s.debit, s.credit], numericCols: [1, 2]),
          _balancedFooter(totalDebit == totalCredit, s.balancedOk,
              s.difference, totalDebit - totalCredit),
        ],
      ),
    );
    return doc.save();
  }

  // ---------------------------------------------------------------------
  // Income statement (P&L)
  // ---------------------------------------------------------------------

  static Future<List<int>> incomeStatementPdfBytes(LedgerState state) async {
    final theme = await _theme();
    final s = state.s;
    final doc = pw.Document(theme: theme);

    List<List<String>> section(AccountType type) => state
        .byType(type)
        .where((a) => (state.balances[a.id] ?? 0) != 0)
        .map((a) => [
              state.accountName(a.id),
              Money.format(state.balances[a.id] ?? 0, withSymbol: false),
            ])
        .toList();

    final incomeRows = section(AccountType.income);
    final expenseRows = section(AccountType.expense);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (ctx) => _header(
          ctx,
          appName: s.appName,
          title: '${s.reports} · P&L',
          generatedOn: state.formatDate(DateTime.now()),
        ),
        build: (ctx) => [
          pw.Text(s.income,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          _totalsTable(incomeRows, headers: [s.account, s.amount]),
          pw.SizedBox(height: 4),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
                '${s.income}: ${Money.format(state.totalIncome)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 16),
          pw.Text(s.expense,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          _totalsTable(expenseRows, headers: [s.account, s.amount]),
          pw.SizedBox(height: 4),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
                '${s.expense}: ${Money.format(state.totalExpense)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Divider(thickness: 1, color: PdfColors.grey400),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
                '${s.net}: ${Money.format(state.netResult)}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 13,
                  color: state.netResult >= 0
                      ? PdfColors.green800
                      : PdfColors.red800,
                )),
          ),
        ],
      ),
    );
    return doc.save();
  }


  // ---------------------------------------------------------------------
  // Balance sheet
  // ---------------------------------------------------------------------

  static Future<List<int>> balanceSheetPdfBytes(LedgerState state) async {
    final theme = await _theme();
    final s = state.s;
    final doc = pw.Document(theme: theme);

    List<List<String>> section(AccountType type) => state
        .byType(type)
        .where((a) => (state.balances[a.id] ?? 0) != 0)
        .map((a) => [
              state.accountName(a.id),
              Money.format(state.balances[a.id] ?? 0, withSymbol: false),
            ])
        .toList();

    final totalAssets = state.totalFor(AccountType.asset);
    final totalLiabilities = state.totalFor(AccountType.liability);
    final totalEquity = state.totalFor(AccountType.equity) + state.netResult;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (ctx) => _header(
          ctx,
          appName: s.appName,
          title: s.reports,
          generatedOn: state.formatDate(DateTime.now()),
        ),
        build: (ctx) => [
          pw.Text(s.assets,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          _totalsTable(section(AccountType.asset),
              headers: [s.account, s.amount]),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                  '${s.assets}: ${Money.format(totalAssets)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(s.liabilities,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          _totalsTable(section(AccountType.liability),
              headers: [s.account, s.amount]),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                  '${s.liabilities}: ${Money.format(totalLiabilities)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(s.equity,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          _totalsTable(
            [
              ...section(AccountType.equity),
              [s.net, Money.format(state.netResult, withSymbol: false)],
            ],
            headers: [s.account, s.amount],
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                  '${s.equity}: ${Money.format(totalEquity)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
          ),
          pw.Divider(thickness: 1, color: PdfColors.grey400),
          _balancedFooter(
            totalAssets == totalLiabilities + totalEquity,
            s.balancedOk,
            s.difference,
            totalAssets - (totalLiabilities + totalEquity),
          ),
        ],
      ),
    );
    return doc.save();
  }

  // ---------------------------------------------------------------------
  // Single-account ledger (with running balance)
  // ---------------------------------------------------------------------

  static Future<List<int>> accountLedgerPdfBytes(
    LedgerState state,
    Account account,
    List<LedgerRow> rows,
  ) async {
    final theme = await _theme();
    final s = state.s;
    final doc = pw.Document(theme: theme);

    final tableRows = rows
        .map((r) => [
              state.formatDate(r.transaction.date, short: true),
              r.transaction.memo.isEmpty ? r.line.note : r.transaction.memo,
              r.line.debit == 0
                  ? '—'
                  : Money.format(r.line.debit, withSymbol: false),
              r.line.credit == 0
                  ? '—'
                  : Money.format(r.line.credit, withSymbol: false),
              Money.format(r.runningBalance, withSymbol: false),
            ])
        .toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (ctx) => _header(
          ctx,
          appName: s.appName,
          title: '${s.ledger} · ${state.accountName(account.id)}',
          generatedOn: state.formatDate(DateTime.now()),
        ),
        build: (ctx) => [
          _totalsTable(
            tableRows,
            headers: [s.date, s.memo, s.debit, s.credit, s.runningBalance],
            numericCols: [2, 3, 4],
          ),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '${s.balance}: ${rows.isEmpty ? Money.format(account.openingBalance) : Money.format(rows.last.runningBalance)}',
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }
}
