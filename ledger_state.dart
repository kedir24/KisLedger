import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../data/ledger_repository.dart';
import '../models/account.dart';
import '../models/journal.dart';
import '../utils/ethiopian_calendar.dart';
import '../utils/strings.dart';

class LedgerState extends ChangeNotifier {
  LedgerState(this._repo);

  final LedgerRepository _repo;
  LedgerRepository get repo => _repo;

  AppLang _lang = AppLang.am;
  AppLang get lang => _lang;
  S get s => S(_lang);

  CalendarSystem _calendar = CalendarSystem.ethiopian;
  CalendarSystem get calendar => _calendar;

  void setCalendar(CalendarSystem value) {
    _calendar = value;
    notifyListeners();
  }

  static final DateFormat _gregorianFmt = DateFormat('dd/MM/yyyy');

  /// Formats [date] using whichever calendar the user has chosen.
  String formatDate(DateTime date, {bool short = false}) {
    if (_calendar == CalendarSystem.gregorian) {
      return _gregorianFmt.format(date);
    }
    final eth = EthiopianDate.fromGregorian(date);
    return eth.format(amharic: _lang == AppLang.am);
  }

  bool _loading = true;
  bool get loading => _loading;

  List<Account> _accounts = const [];
  List<Account> get accounts => _accounts;

  Map<String, int> _balances = const {};
  Map<String, int> get balances => _balances;

  List<LedgerTransaction> _recent = const [];
  List<LedgerTransaction> get recent => _recent;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _accounts = await _repo.accounts();
    _balances = await _repo.balances();
    _recent = await _repo.transactions(limit: 20);
    _loading = false;
    notifyListeners();
  }

  void setLanguage(AppLang lang) {
    _lang = lang;
    notifyListeners();
  }

  Account? accountById(String id) {
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  String accountName(String id) {
    final a = accountById(id);
    if (a == null) return '—';
    return _lang == AppLang.am ? a.nameAm : a.nameEn;
  }

  List<Account> byType(AccountType type) =>
      _accounts.where((a) => a.type == type).toList();

  int totalFor(AccountType type) => byType(type)
      .fold(0, (sum, a) => sum + (_balances[a.id] ?? 0));

  int get totalIncome => totalFor(AccountType.income);
  int get totalExpense => totalFor(AccountType.expense);
  int get netResult => totalIncome - totalExpense;
  int get cashOnHand =>
      (_balances['acc-cash'] ?? 0) +
      (_balances['acc-bank'] ?? 0) +
      (_balances['acc-telebirr'] ?? 0);

  Future<void> post(JournalEntry entry) async {
    await _repo.post(entry);
    await load();
  }

  Future<void> reverse(String transactionId) async {
    await _repo.reverse(transactionId);
    await load();
  }

  /// Quick entry shortcuts that write the correct debit/credit pair.
  Future<void> quickIncome({
    required int santim,
    required String toAssetId,
    required String incomeAccountId,
    required DateTime date,
    String memo = '',
  }) =>
      _postPair(
        debitAccountId: toAssetId,
        creditAccountId: incomeAccountId,
        santim: santim,
        date: date,
        memo: memo,
      );

  Future<void> quickExpense({
    required int santim,
    required String expenseAccountId,
    required String fromAssetId,
    required DateTime date,
    String memo = '',
  }) =>
      _postPair(
        debitAccountId: expenseAccountId,
        creditAccountId: fromAssetId,
        santim: santim,
        date: date,
        memo: memo,
      );

  Future<void> _postPair({
    required String debitAccountId,
    required String creditAccountId,
    required int santim,
    required DateTime date,
    String memo = '',
  }) async {
    final txId = _repo.newId();
    final entry = JournalEntry(
      transaction: LedgerTransaction(
        id: txId,
        date: date,
        memo: memo,
        createdAt: DateTime.now(),
      ),
      lines: [
        JournalLine(
            id: _repo.newId(),
            transactionId: txId,
            accountId: debitAccountId,
            debit: santim),
        JournalLine(
            id: _repo.newId(),
            transactionId: txId,
            accountId: creditAccountId,
            credit: santim),
      ],
    );
    await post(entry);
  }
}
