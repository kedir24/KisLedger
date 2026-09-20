import 'package:flutter_test/flutter_test.dart';
import 'package:smartledger/models/account.dart';
import 'package:smartledger/models/journal.dart';
import 'package:smartledger/utils/ethiopian_calendar.dart';
import 'package:smartledger/utils/money.dart';

JournalEntry entryWith(List<JournalLine> lines) => JournalEntry(
      transaction: LedgerTransaction(
        id: 'tx1',
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
      lines: lines,
    );

void main() {
  group('double-entry validation', () {
    test('accepts a balanced two-line entry', () {
      final entry = entryWith([
        const JournalLine(
            id: 'l1', transactionId: 'tx1', accountId: 'acc-cash', debit: 50000),
        const JournalLine(
            id: 'l2',
            transactionId: 'tx1',
            accountId: 'acc-sales',
            credit: 50000),
      ]);
      expect(entry.validate(), isNull);
      expect(entry.isBalanced, isTrue);
      expect(entry.difference, 0);
    });

    test('rejects an entry where the sides do not match', () {
      final entry = entryWith([
        const JournalLine(
            id: 'l1', transactionId: 'tx1', accountId: 'acc-cash', debit: 50000),
        const JournalLine(
            id: 'l2',
            transactionId: 'tx1',
            accountId: 'acc-sales',
            credit: 40000),
      ]);
      expect(entry.validate(), 'out_of_balance');
      expect(entry.difference, 10000);
    });

    test('rejects a line carrying both a debit and a credit', () {
      final entry = entryWith([
        const JournalLine(
            id: 'l1',
            transactionId: 'tx1',
            accountId: 'acc-cash',
            debit: 100,
            credit: 100),
        const JournalLine(
            id: 'l2', transactionId: 'tx1', accountId: 'acc-sales', credit: 100),
      ]);
      expect(entry.validate(), 'line_needs_one_side');
    });

    test('rejects a single-line entry', () {
      final entry = entryWith([
        const JournalLine(
            id: 'l1', transactionId: 'tx1', accountId: 'acc-cash', debit: 100),
      ]);
      expect(entry.validate(), 'needs_two_lines');
    });

    test('rejects a line without an account', () {
      final entry = entryWith([
        const JournalLine(
            id: 'l1', transactionId: 'tx1', accountId: '', debit: 100),
        const JournalLine(
            id: 'l2', transactionId: 'tx1', accountId: 'acc-sales', credit: 100),
      ]);
      expect(entry.validate(), 'line_needs_account');
    });

    test('splits across three lines still balance', () {
      final entry = entryWith([
        const JournalLine(
            id: 'l1', transactionId: 'tx1', accountId: 'acc-cash', debit: 30000),
        const JournalLine(
            id: 'l2', transactionId: 'tx1', accountId: 'acc-ar', debit: 20000),
        const JournalLine(
            id: 'l3',
            transactionId: 'tx1',
            accountId: 'acc-sales',
            credit: 50000),
      ]);
      expect(entry.validate(), isNull);
    });
  });

  group('normal balance side', () {
    test('assets and expenses are debit-normal', () {
      expect(AccountType.asset.isDebitNormal, isTrue);
      expect(AccountType.expense.isDebitNormal, isTrue);
    });

    test('liabilities, equity and income are credit-normal', () {
      expect(AccountType.liability.isDebitNormal, isFalse);
      expect(AccountType.equity.isDebitNormal, isFalse);
      expect(AccountType.income.isDebitNormal, isFalse);
    });
  });

  group('money parsing', () {
    test('parses plain and grouped amounts into santim', () {
      expect(Money.parse('1250'), 125000);
      expect(Money.parse('1,250.50'), 125050);
      expect(Money.parse(' 12.5 '), 1250);
    });

    test('returns null for invalid or negative input', () {
      expect(Money.parse(''), isNull);
      expect(Money.parse('abc'), isNull);
      expect(Money.parse('-10'), isNull);
    });
  });

  group('Ethiopian calendar', () {
    // Reference dates from the Ethiopian-calendar article on Wikipedia.
    test('matches known New Year anchor dates', () {
      expect(EthiopianDate(1998, 1, 1).toGregorian(),
          DateTime(2005, 9, 11));
      expect(EthiopianDate(1996, 1, 1).toGregorian(),
          DateTime(2003, 9, 12));
      expect(EthiopianDate(1992, 1, 1).toGregorian(),
          DateTime(1999, 9, 12));
    });

    test('New Year falls on 12 September the year before a Gregorian leap year',
        () {
      // 2000 EC begins in Gregorian 2007, the year before leap year 2008.
      expect(EthiopianDate(2000, 1, 1).toGregorian(),
          DateTime(2007, 9, 12));
      // 2016 EC begins in Gregorian 2023, the year before leap year 2024.
      expect(EthiopianDate(2016, 1, 1).toGregorian(),
          DateTime(2023, 9, 12));
    });

    test('round-trips Gregorian -> Ethiopian -> Gregorian', () {
      for (var offset = -4000; offset <= 4000; offset += 137) {
        final g = DateTime(2010, 1, 1).add(Duration(days: offset));
        final e = EthiopianDate.fromGregorian(g);
        expect(e.toGregorian(), g, reason: 'mismatch for $g -> $e');
      }
    });

    test('Pagume has 6 days in a leap year and 5 otherwise', () {
      expect(EthiopianDate.isLeap(2015), isTrue);
      expect(EthiopianDate.daysInMonth(2015, 13), 6);
      expect(EthiopianDate.isLeap(2016), isFalse);
      expect(EthiopianDate.daysInMonth(2016, 13), 5);
    });
  });
}
