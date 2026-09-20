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

  const Account({
    required this.id,
    required this.code,
    required this.nameAm,
    required this.nameEn,
    required this.type,
    this.openingBalance = 0,
    this.isActive = true,
  });

  Account copyWith({
    String? code,
    String? nameAm,
    String? nameEn,
    AccountType? type,
    int? openingBalance,
    bool? isActive,
  }) {
    return Account(
      id: id,
      code: code ?? this.code,
      nameAm: nameAm ?? this.nameAm,
      nameEn: nameEn ?? this.nameEn,
      type: type ?? this.type,
      openingBalance: openingBalance ?? this.openingBalance,
      isActive: isActive ?? this.isActive,
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
      };

  factory Account.fromMap(Map<String, Object?> m) => Account(
        id: m['id'] as String,
        code: m['code'] as String,
        nameAm: m['name_am'] as String,
        nameEn: m['name_en'] as String,
        type: AccountTypeX.fromKey(m['type'] as String),
        openingBalance: (m['opening_balance'] as int?) ?? 0,
        isActive: (m['is_active'] as int? ?? 1) == 1,
      );
}
