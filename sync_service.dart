import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/ledger_repository.dart';
import '../models/account.dart';
import '../models/journal.dart';
import 'supabase_config.dart';

class SyncNotConfigured implements Exception {
  const SyncNotConfigured();
  @override
  String toString() => 'SyncNotConfigured';
}

class SyncNotSignedIn implements Exception {
  const SyncNotSignedIn();
  @override
  String toString() => 'SyncNotSignedIn';
}

/// Summary of one completed sync pass, for the Settings screen to show.
class SyncResult {
  final int accountsPushed;
  final int transactionsPushed;
  final int accountsPulled;
  final int transactionsPulled;

  const SyncResult({
    this.accountsPushed = 0,
    this.transactionsPushed = 0,
    this.accountsPulled = 0,
    this.transactionsPulled = 0,
  });

  bool get isEmpty =>
      accountsPushed == 0 &&
      transactionsPushed == 0 &&
      accountsPulled == 0 &&
      transactionsPulled == 0;
}

/// Pushes local changes up to Supabase and pulls remote changes down.
///
/// Posted transactions are immutable (see LedgerRepository.reverse), so
/// they sync as a plain append-only copy — the only real merge logic is
/// for accounts, which use last-write-wins on `updated_at`.
class SyncService {
  SyncService(this._repo);

  final LedgerRepository _repo;

  bool get isConfigured => SupabaseConfig.isConfigured;

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => isConfigured ? _client.auth.currentUser : null;

  Stream<AuthState> get authStateChanges {
    if (!isConfigured) return const Stream<AuthState>.empty();
    return _client.auth.onAuthStateChange;
  }

  Future<void> signUp({required String email, required String password}) async {
    if (!isConfigured) throw const SyncNotConfigured();
    await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signIn({required String email, required String password}) async {
    if (!isConfigured) throw const SyncNotConfigured();
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    if (!isConfigured) return;
    await _client.auth.signOut();
  }

  /// Pushes everything not yet synced, then pulls everything new from the
  /// server. Throws [SyncNotConfigured] / [SyncNotSignedIn], or whatever
  /// network error Supabase raised — the caller decides how to show it.
  Future<SyncResult> sync() async {
    if (!isConfigured) throw const SyncNotConfigured();
    final user = currentUser;
    if (user == null) throw const SyncNotSignedIn();

    final pushed = await _push(user.id);
    final pulled = await _pull(user.id);
    return SyncResult(
      accountsPushed: pushed.$1,
      transactionsPushed: pushed.$2,
      accountsPulled: pulled.$1,
      transactionsPulled: pulled.$2,
    );
  }

  Future<(int, int)> _push(String userId) async {
    final dirtyAccounts = await _repo.unsyncedAccounts();
    for (final account in dirtyAccounts) {
      await _client.from('accounts').upsert(account.toRemoteMap(userId));
      await _repo.markAccountSynced(account.id, account.updatedAt);
    }

    final dirtyTx = await _repo.unsyncedTransactions();
    for (final tx in dirtyTx) {
      final lines = await _repo.linesOf(tx.id);
      await _client.from('transactions').upsert(tx.toRemoteMap(userId));
      if (lines.isNotEmpty) {
        await _client
            .from('journal_lines')
            .upsert(lines.map((l) => l.toRemoteMap(userId)).toList());
      }
      await _repo.markTransactionSynced(tx.id);
    }

    return (dirtyAccounts.length, dirtyTx.length);
  }

  Future<(int, int)> _pull(String userId) async {
    final remoteAccounts = await _client
        .from('accounts')
        .select()
        .eq('user_id', userId) as List<dynamic>;
    var changedAccounts = 0;
    for (final row in remoteAccounts) {
      final applied = await _repo.mergeAccountFromRemote(
          Account.fromRemoteMap(Map<String, Object?>.from(row as Map)));
      if (applied) changedAccounts++;
    }

    final remoteTx = await _client
        .from('transactions')
        .select()
        .eq('user_id', userId) as List<dynamic>;
    final remoteLines = await _client
        .from('journal_lines')
        .select()
        .eq('user_id', userId) as List<dynamic>;

    final linesByTx = <String, List<JournalLine>>{};
    for (final row in remoteLines) {
      final line =
          JournalLine.fromRemoteMap(Map<String, Object?>.from(row as Map));
      linesByTx.putIfAbsent(line.transactionId, () => []).add(line);
    }

    var newTxCount = 0;
    for (final row in remoteTx) {
      final tx = LedgerTransaction.fromRemoteMap(
          Map<String, Object?>.from(row as Map));
      final before = await _repo.transactionById(tx.id);
      await _repo.insertTransactionFromRemoteIfMissing(
          tx, linesByTx[tx.id] ?? const []);
      if (before == null) newTxCount++;
    }

    return (changedAccounts, newTxCount);
  }
}
