import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../models/journal.dart';
import 'db.dart';

class LedgerRow {
  final LedgerTransaction transaction;
  final JournalLine line;
  final int runningBalance;

  const LedgerRow({
    required this.transaction,
    required this.line,
    required this.runningBalance,
  });
}

class PostException implements Exception {
  final String code;
  PostException(this.code);
  @override
  String toString() => 'PostException($code)';
}

class LedgerRepository {
  LedgerRepository({AppDatabase? db, Uuid? uuid})
      : _appDb = db ?? AppDatabase.instance,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _appDb;
  final Uuid _uuid;

  String newId() => _uuid.v4();

  Future<List<Account>> accounts({bool activeOnly = true}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'accounts',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'code ASC',
    );
    return rows.map(Account.fromMap).toList();
  }

  Future<void> upsertAccount(Account account) async {
    final db = await _appDb.database;
    await db.insert('accounts', account.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Writes a balanced entry in one transaction. Throws [PostException]
  /// when the entry does not satisfy the double-entry rule.
  Future<LedgerTransaction> post(JournalEntry entry) async {
    final problem = entry.validate();
    if (problem != null) throw PostException(problem);

    final db = await _appDb.database;
    await db.transaction((txn) async {
      await txn.insert('transactions', entry.transaction.toMap());
      for (final line in entry.lines) {
        await txn.insert(
          'journal_lines',
          line.copyWith(transactionId: entry.transaction.id).toMap(),
        );
      }
    });
    return entry.transaction;
  }

  /// Posted entries are never edited or deleted; this writes the mirror image.
  Future<LedgerTransaction> reverse(String transactionId,
      {DateTime? date}) async {
    final db = await _appDb.database;
    final original = await transactionById(transactionId);
    if (original == null) throw PostException('not_found');

    final existing = await db.query('transactions',
        where: 'reversal_of_id = ?', whereArgs: [transactionId], limit: 1);
    if (existing.isNotEmpty) throw PostException('already_reversed');

    final lines = await linesOf(transactionId);
    final reversal = LedgerTransaction(
      id: newId(),
      date: date ?? DateTime.now(),
      reference: original.reference,
      memo: 'Reversal of ${original.memo}',
      createdAt: DateTime.now(),
      reversalOfId: transactionId,
    );

    final flipped = lines
        .map((l) => JournalLine(
              id: newId(),
              transactionId: reversal.id,
              accountId: l.accountId,
              debit: l.credit,
              credit: l.debit,
              note: l.note,
            ))
        .toList();

    return post(JournalEntry(transaction: reversal, lines: flipped));
  }

  Future<LedgerTransaction?> transactionById(String id) async {
    final db = await _appDb.database;
    final rows =
        await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return LedgerTransaction.fromMap(rows.first);
  }

  Future<List<JournalLine>> linesOf(String transactionId) async {
    final db = await _appDb.database;
    final rows = await db.query('journal_lines',
        where: 'transaction_id = ?', whereArgs: [transactionId]);
    return rows.map(JournalLine.fromMap).toList();
  }

  Future<List<LedgerTransaction>> transactions({int? limit}) async {
    final db = await _appDb.database;
    final rows = await db.query('transactions',
        orderBy: 'date DESC, created_at DESC', limit: limit);
    return rows.map(LedgerTransaction.fromMap).toList();
  }

  /// Running-balance view of one account, oldest first.
  Future<List<LedgerRow>> ledgerFor(
    Account account, {
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _appDb.database;
    final where = <String>['l.account_id = ?'];
    final args = <Object?>[account.id];
    if (from != null) {
      where.add('t.date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('t.date <= ?');
      args.add(to.toIso8601String());
    }

    final rows = await db.rawQuery('''
      SELECT l.*, t.date AS t_date, t.reference AS t_reference,
             t.memo AS t_memo, t.created_at AS t_created_at,
             t.attachment_path AS t_attachment, t.reversal_of_id AS t_reversal
      FROM journal_lines l
      JOIN transactions t ON t.id = l.transaction_id
      WHERE ${where.join(' AND ')}
      ORDER BY t.date ASC, t.created_at ASC
    ''', args);

    var running = account.openingBalance;
    final out = <LedgerRow>[];
    for (final r in rows) {
      final line = JournalLine.fromMap(r);
      running += account.type.isDebitNormal
          ? line.signedAmount
          : -line.signedAmount;
      out.add(LedgerRow(
        transaction: LedgerTransaction(
          id: r['transaction_id'] as String,
          date: DateTime.parse(r['t_date'] as String),
          reference: (r['t_reference'] as String?) ?? '',
          memo: (r['t_memo'] as String?) ?? '',
          attachmentPath: r['t_attachment'] as String?,
          createdAt: DateTime.parse(r['t_created_at'] as String),
          reversalOfId: r['t_reversal'] as String?,
        ),
        line: line,
        runningBalance: running,
      ));
    }
    return out;
  }

  /// Signed balance per account id, following each account's normal side.
  Future<Map<String, int>> balances({DateTime? asOf}) async {
    final db = await _appDb.database;
    final all = await accounts(activeOnly: false);
    final rows = await db.rawQuery('''
      SELECT l.account_id AS account_id,
             SUM(l.debit) AS debit,
             SUM(l.credit) AS credit
      FROM journal_lines l
      JOIN transactions t ON t.id = l.transaction_id
      ${asOf != null ? 'WHERE t.date <= ?' : ''}
      GROUP BY l.account_id
    ''', asOf != null ? [asOf.toIso8601String()] : null);

    final sums = {
      for (final r in rows)
        r['account_id'] as String:
            ((r['debit'] as int?) ?? 0) - ((r['credit'] as int?) ?? 0)
    };

    return {
      for (final a in all)
        a.id: a.openingBalance +
            (a.type.isDebitNormal ? (sums[a.id] ?? 0) : -(sums[a.id] ?? 0))
    };
  }

  /// Sums every posted line. A healthy book always returns (x, x).
  Future<(int debit, int credit)> trialBalance() async {
    final db = await _appDb.database;
    final r = await db.rawQuery(
        'SELECT SUM(debit) AS d, SUM(credit) AS c FROM journal_lines');
    return ((r.first['d'] as int?) ?? 0, (r.first['c'] as int?) ?? 0);
  }
}
