/// One side of a journal entry. Exactly one of [debit] / [credit] is non-zero.
class JournalLine {
  final String id;
  final String transactionId;
  final String accountId;
  final int debit; // santim, >= 0
  final int credit; // santim, >= 0
  final String note;

  const JournalLine({
    required this.id,
    required this.transactionId,
    required this.accountId,
    this.debit = 0,
    this.credit = 0,
    this.note = '',
  });

  bool get isValid =>
      debit >= 0 && credit >= 0 && (debit == 0) != (credit == 0);

  int get signedAmount => debit - credit;

  JournalLine copyWith({
    String? transactionId,
    String? accountId,
    int? debit,
    int? credit,
    String? note,
  }) =>
      JournalLine(
        id: id,
        transactionId: transactionId ?? this.transactionId,
        accountId: accountId ?? this.accountId,
        debit: debit ?? this.debit,
        credit: credit ?? this.credit,
        note: note ?? this.note,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'transaction_id': transactionId,
        'account_id': accountId,
        'debit': debit,
        'credit': credit,
        'note': note,
      };

  factory JournalLine.fromMap(Map<String, Object?> m) => JournalLine(
        id: m['id'] as String,
        transactionId: m['transaction_id'] as String,
        accountId: m['account_id'] as String,
        debit: (m['debit'] as int?) ?? 0,
        credit: (m['credit'] as int?) ?? 0,
        note: (m['note'] as String?) ?? '',
      );

  /// Payload for the `journal_lines` table in Supabase.
  Map<String, Object?> toRemoteMap(String userId) => {
        'id': id,
        'user_id': userId,
        'transaction_id': transactionId,
        'account_id': accountId,
        'debit': debit,
        'credit': credit,
        'note': note,
      };

  factory JournalLine.fromRemoteMap(Map<String, Object?> m) => JournalLine(
        id: m['id'] as String,
        transactionId: m['transaction_id'] as String,
        accountId: m['account_id'] as String,
        debit: (m['debit'] as num?)?.toInt() ?? 0,
        credit: (m['credit'] as num?)?.toInt() ?? 0,
        note: (m['note'] as String?) ?? '',
      );
}

/// A posted transaction. Never deleted — reverse it instead.
///
/// Because posted transactions are immutable, syncing them needs no
/// last-write-wins logic: a transaction either exists on both sides with
/// identical content, or it needs to be copied across once. [isSynced]
/// just remembers whether that one-time copy has happened yet.
class LedgerTransaction {
  final String id;
  final DateTime date;
  final String reference;
  final String memo;
  final String? attachmentPath;
  final DateTime createdAt;
  final String? reversalOfId;
  final bool isSynced;

  const LedgerTransaction({
    required this.id,
    required this.date,
    required this.createdAt,
    this.reference = '',
    this.memo = '',
    this.attachmentPath,
    this.reversalOfId,
    this.isSynced = false,
  });

  bool get isReversal => reversalOfId != null;

  LedgerTransaction copyWith({bool? isSynced}) => LedgerTransaction(
        id: id,
        date: date,
        createdAt: createdAt,
        reference: reference,
        memo: memo,
        attachmentPath: attachmentPath,
        reversalOfId: reversalOfId,
        isSynced: isSynced ?? this.isSynced,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'reference': reference,
        'memo': memo,
        'attachment_path': attachmentPath,
        'created_at': createdAt.toIso8601String(),
        'reversal_of_id': reversalOfId,
        'is_synced': isSynced ? 1 : 0,
      };

  factory LedgerTransaction.fromMap(Map<String, Object?> m) =>
      LedgerTransaction(
        id: m['id'] as String,
        date: DateTime.parse(m['date'] as String),
        reference: (m['reference'] as String?) ?? '',
        memo: (m['memo'] as String?) ?? '',
        attachmentPath: m['attachment_path'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        reversalOfId: m['reversal_of_id'] as String?,
        isSynced: (m['is_synced'] as int? ?? 0) == 1,
      );

  /// Payload for the `transactions` table in Supabase.
  Map<String, Object?> toRemoteMap(String userId) => {
        'id': id,
        'user_id': userId,
        'date': date.toIso8601String(),
        'reference': reference,
        'memo': memo,
        'attachment_path': attachmentPath,
        'created_at': createdAt.toIso8601String(),
        'reversal_of_id': reversalOfId,
      };

  factory LedgerTransaction.fromRemoteMap(Map<String, Object?> m) =>
      LedgerTransaction(
        id: m['id'] as String,
        date: DateTime.parse(m['date'] as String),
        reference: (m['reference'] as String?) ?? '',
        memo: (m['memo'] as String?) ?? '',
        attachmentPath: m['attachment_path'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        reversalOfId: m['reversal_of_id'] as String?,
        isSynced: true,
      );
}

/// A transaction together with its lines, as it is edited and posted.
class JournalEntry {
  final LedgerTransaction transaction;
  final List<JournalLine> lines;

  const JournalEntry({required this.transaction, required this.lines});

  int get totalDebit => lines.fold(0, (sum, l) => sum + l.debit);
  int get totalCredit => lines.fold(0, (sum, l) => sum + l.credit);

  /// Positive when debits exceed credits. Must be zero to post.
  int get difference => totalDebit - totalCredit;

  bool get isBalanced => difference == 0 && totalDebit > 0;

  /// Returns null when the entry can be posted, otherwise a reason code
  /// that the UI turns into a localized message.
  String? validate() {
    if (lines.length < 2) return 'needs_two_lines';
    if (lines.any((l) => !l.isValid)) return 'line_needs_one_side';
    if (lines.any((l) => l.accountId.isEmpty)) return 'line_needs_account';
    if (totalDebit == 0) return 'zero_amount';
    if (difference != 0) return 'out_of_balance';
    return null;
  }
}
