import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../data/ledger_repository.dart';
import '../models/account.dart';
import '../models/journal.dart';
import '../services/sync_service.dart';
import '../utils/ethiopian_calendar.dart';
import '../utils/strings.dart';

enum SyncStatus { idle, syncing, success, error }

class LedgerState extends ChangeNotifier {
  LedgerState(this._repo) : sync = SyncService(_repo);

  final LedgerRepository _repo;
  LedgerRepository get repo => _repo;

  final SyncService sync;

  bool get cloudConfigured => sync.isConfigured;
  bool get isSignedIn => sync.currentUser != null;
  String? get userEmail => sync.currentUser?.email;

  SyncStatus _syncStatus = SyncStatus.idle;
  SyncStatus get syncStatus => _syncStatus;

  String? _syncError;
  String? get syncError => _syncError;

  DateTime? _lastSyncedAt;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

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
    await _refreshData();
    _loading = false;
    notifyListeners();

    if (isSignedIn) _backgroundSync();
  }

  Future<void> _refreshData() async {
    _accounts = await _repo.accounts();
    _balances = await _repo.balances();
    _recent = await _repo.transactions(limit: 20);
    _pendingCount = await _repo.pendingSyncCount();
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

  Future<void> upsertAccount(Account account) async {
    await _repo.upsertAccount(account);
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

  // ---------------------------------------------------------------------
  // Cloud sync
  // ---------------------------------------------------------------------

  Future<void> signIn({required String email, required String password}) async {
    await sync.signIn(email: email, password: password);
    notifyListeners();
    await load();
  }

  Future<void> signUp({required String email, required String password}) async {
    await sync.signUp(email: email, password: password);
    notifyListeners();
  }

  Future<void> signOut() async {
    await sync.signOut();
    _syncStatus = SyncStatus.idle;
    _syncError = null;
    _lastSyncedAt = null;
    notifyListeners();
  }

  /// Explicit, user-triggered sync — updates status so the Settings screen
  /// can show progress or a clear error.
  Future<void> syncNow() async {
    _syncStatus = SyncStatus.syncing;
    _syncError = null;
    notifyListeners();
    try {
      await sync.sync();
      _lastSyncedAt = DateTime.now();
      _syncStatus = SyncStatus.success;
      await _refreshData();
    } catch (e) {
      _syncStatus = SyncStatus.error;
      _syncError = e.toString();
    }
    notifyListeners();
  }

  /// Best-effort sync run automatically after local writes or on load.
  /// Failures (most commonly: no internet) are swallowed quietly — the
  /// pending-changes count still shows there is work to push next time.
  Future<void> _backgroundSync() async {
    if (!cloudConfigured || !isSignedIn) return;
    try {
      await sync.sync();
      _lastSyncedAt = DateTime.now();
      await _refreshData();
      notifyListeners();
    } catch (_) {
      // Offline or a transient error — the next post, app resume, or
      // manual "Sync now" tap will try again.
    }
  }

  /// Public entry point for triggers outside this class — e.g. the app
  /// coming back to the foreground, when connectivity may have returned.
  Future<void> trySyncInBackground() => _backgroundSync();
}
