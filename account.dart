/// የአካውንት ዓይነቶች — the five roots of the chart of accounts.
enum AccountType { asset, liability, equity, income, expense }

extension AccountTypeX on AccountType {
  String get key => name;

  /// Debit-normal accounts grow with debits; the rest grow with credits.
  bool get isDebitNormal =>
      this == AccountType.asset || this == AccountType.expense;

  static AccountType fromKey(String key) =>
      AccountType.values.firstWhere((t) => t.name == key);
}

class Account {
  final String id;
  final String code; // e.g. "1000"
  final String nameAm;
  final String nameEn;
  final AccountType type;
  final int openingBalance; // in santim (1 ETB = 100)
  final bool isActive;

  /// Last time this account was created or edited — the tiebreaker when
  /// merging with the cloud copy (last-write-wins).
  final DateTime updatedAt;

  /// Whether this exact version has been pushed to Supabase yet. Posted
  /// transactions never change once written, so only accounts (which can be
  /// renamed or deactivated) need this per-row dirty flag.
  final bool isSynced;

  Account({
    required this.id,
    required this.code,
    required this.nameAm,
    required this.nameEn,
    required this.type,
    this.openingBalance = 0,
    this.isActive = true,
    DateTime? updatedAt,
    this.isSynced = false,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Account copyWith({
    String? code,
    String? nameAm,
    String? nameEn,
    AccountType? type,
    int? openingBalance,
    bool? isActive,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return Account(
      id: id,
      code: code ?? this.code,
      nameAm: nameAm ?? this.nameAm,
      nameEn: nameEn ?? this.nameEn,
      type: type ?? this.type,
      openingBalance: openingBalance ?? this.openingBalance,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'code': code,
        'name_am': nameAm,
        'name_en': nameEn,
        'type': type.key,
        'opening_balance': openingBalance,
        'is_active': isActive ? 1 : 0,
        'updated_at': updatedAt.toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
      };

  factory Account.fromMap(Map<String, Object?> m) => Account(
        id: m['id'] as String,
        code: m['code'] as String,
        nameAm: m['name_am'] as String,
        nameEn: m['name_en'] as String,
        type: AccountTypeX.fromKey(m['type'] as String),
        openingBalance: (m['opening_balance'] as int?) ?? 0,
        isActive: (m['is_active'] as int? ?? 1) == 1,
        updatedAt: m['updated_at'] != null
            ? DateTime.parse(m['updated_at'] as String)
            : DateTime.now(),
        isSynced: (m['is_synced'] as int? ?? 0) == 1,
      );

  /// Payload for the `accounts` table in Supabase — drops the local-only
  /// `is_synced` flag and adds the owning user's id for row-level security.
  Map<String, Object?> toRemoteMap(String userId) => {
        'id': id,
        'user_id': userId,
        'code': code,
        'name_am': nameAm,
        'name_en': nameEn,
        'type': type.key,
        'opening_balance': openingBalance,
        'is_active': isActive,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Account.fromRemoteMap(Map<String, Object?> m) => Account(
        id: m['id'] as String,
        code: m['code'] as String,
        nameAm: m['name_am'] as String,
        nameEn: m['name_en'] as String,
        type: AccountTypeX.fromKey(m['type'] as String),
        openingBalance: (m['opening_balance'] as num?)?.toInt() ?? 0,
        isActive: m['is_active'] as bool? ?? true,
        updatedAt: DateTime.parse(m['updated_at'] as String),
        isSynced: true,
      );
}
