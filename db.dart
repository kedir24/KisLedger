import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/account.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'smartledger.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _create,
    );
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        name_am TEXT NOT NULL,
        name_en TEXT NOT NULL,
        type TEXT NOT NULL,
        opening_balance INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        reference TEXT,
        memo TEXT,
        attachment_path TEXT,
        created_at TEXT NOT NULL,
        reversal_of_id TEXT REFERENCES transactions(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE journal_lines (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL REFERENCES transactions(id),
        account_id TEXT NOT NULL REFERENCES accounts(id),
        debit INTEGER NOT NULL DEFAULT 0,
        credit INTEGER NOT NULL DEFAULT 0,
        note TEXT
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_lines_account ON journal_lines(account_id)');
    await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');

    for (final account in seedAccounts) {
      await db.insert('accounts', account.toMap());
    }
  }

  /// A starter chart of accounts for a small Ethiopian shop.
  static const seedAccounts = <Account>[
    Account(
        id: 'acc-cash',
        code: '1000',
        nameAm: 'ጥሬ ገንዘብ',
        nameEn: 'Cash',
        type: AccountType.asset),
    Account(
        id: 'acc-bank',
        code: '1010',
        nameAm: 'ባንክ',
        nameEn: 'Bank',
        type: AccountType.asset),
    Account(
        id: 'acc-telebirr',
        code: '1020',
        nameAm: 'ቴሌብር',
        nameEn: 'Telebirr',
        type: AccountType.asset),
    Account(
        id: 'acc-ar',
        code: '1100',
        nameAm: 'ተቀባይ ሂሳብ',
        nameEn: 'Accounts receivable',
        type: AccountType.asset),
    Account(
        id: 'acc-inventory',
        code: '1200',
        nameAm: 'ዕቃ ክምችት',
        nameEn: 'Inventory',
        type: AccountType.asset),
    Account(
        id: 'acc-ap',
        code: '2000',
        nameAm: 'ተከፋይ ሂሳብ',
        nameEn: 'Accounts payable',
        type: AccountType.liability),
    Account(
        id: 'acc-loan',
        code: '2100',
        nameAm: 'ብድር',
        nameEn: 'Loan payable',
        type: AccountType.liability),
    Account(
        id: 'acc-capital',
        code: '3000',
        nameAm: 'የባለቤት ካፒታል',
        nameEn: "Owner's capital",
        type: AccountType.equity),
    Account(
        id: 'acc-sales',
        code: '4000',
        nameAm: 'የሽያጭ ገቢ',
        nameEn: 'Sales revenue',
        type: AccountType.income),
    Account(
        id: 'acc-service',
        code: '4100',
        nameAm: 'የአገልግሎት ገቢ',
        nameEn: 'Service income',
        type: AccountType.income),
    Account(
        id: 'acc-cogs',
        code: '5000',
        nameAm: 'የተሸጠ ዕቃ ወጪ',
        nameEn: 'Cost of goods sold',
        type: AccountType.expense),
    Account(
        id: 'acc-rent',
        code: '5100',
        nameAm: 'የቤት ኪራይ',
        nameEn: 'Rent',
        type: AccountType.expense),
    Account(
        id: 'acc-salary',
        code: '5200',
        nameAm: 'ደመወዝ',
        nameEn: 'Salaries',
        type: AccountType.expense),
    Account(
        id: 'acc-transport',
        code: '5300',
        nameAm: 'ትራንስፖርት',
        nameEn: 'Transport',
        type: AccountType.expense),
    Account(
        id: 'acc-utilities',
        code: '5400',
        nameAm: 'ውሃና መብራት',
        nameEn: 'Utilities',
        type: AccountType.expense),
  ];
}
