/// Ethiopian (Ge'ez) calendar conversion.
///
/// The Ethiopian year is 7-8 years behind the Gregorian year and has 13
/// months: 12 of exactly 30 days plus Pagume, a short 13th month of 5 days
/// (6 in a leap year). New Year (Meskerem 1) falls on 11 September in the
/// Gregorian calendar, except it falls on 12 September in the year before a
/// Gregorian leap year.
///
/// Anchor and leap rule verified against Wikipedia's Ethiopian-calendar
/// article: 1998 EC began 11 Sept 2005, 1996 EC began 12 Sept 2003, and
/// 1992 EC began 12 Sept 1999 all round-trip correctly with the formulas
/// below (year % 4 == 3 is an Ethiopian leap year).
class EthiopianDate {
  final int year;
  final int month; // 1-13, where 13 is Pagume
  final int day;

  const EthiopianDate(this.year, this.month, this.day);

  static const _anchorYear = 1998;
  static final DateTime _anchorGregorian = DateTime(2005, 9, 11);

  static bool isLeap(int year) => year % 4 == 3;

  static int daysInMonth(int year, int month) {
    if (month < 13) return 30;
    return isLeap(year) ? 6 : 5;
  }

  /// Converts a Gregorian date (time-of-day is ignored) to Ethiopian.
  factory EthiopianDate.fromGregorian(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    var remaining = target.difference(_anchorGregorian).inDays;
    var year = _anchorYear;

    if (remaining >= 0) {
      while (true) {
        final len = isLeap(year) ? 366 : 365;
        if (remaining < len) break;
        remaining -= len;
        year++;
      }
    } else {
      while (remaining < 0) {
        year--;
        remaining += isLeap(year) ? 366 : 365;
      }
    }

    final month = remaining ~/ 30 + 1;
    final day = remaining % 30 + 1;
    return EthiopianDate(year, month, day);
  }

  DateTime toGregorian() {
    var total = 0;
    if (year >= _anchorYear) {
      for (var y = _anchorYear; y < year; y++) {
        total += isLeap(y) ? 366 : 365;
      }
    } else {
      for (var y = year; y < _anchorYear; y++) {
        total -= isLeap(y) ? 366 : 365;
      }
    }
    total += (month - 1) * 30 + (day - 1);
    return _anchorGregorian.add(Duration(days: total));
  }

  static const monthNamesAm = [
    'መስከረም',
    'ጥቅምት',
    'ኅዳር',
    'ታኅሳስ',
    'ጥር',
    'የካቲት',
    'መጋቢት',
    'ሚያዝያ',
    'ግንቦት',
    'ሰኔ',
    'ሐምሌ',
    'ነሐሴ',
    'ጳጉሜ',
  ];

  static const monthNamesEn = [
    'Meskerem',
    'Tikimt',
    'Hidar',
    'Tahsas',
    'Tir',
    'Yekatit',
    'Megabit',
    'Miazia',
    'Ginbot',
    'Sene',
    'Hamle',
    'Nehase',
    'Pagume',
  ];

  String monthName(bool amharic) =>
      (amharic ? monthNamesAm : monthNamesEn)[month - 1];

  /// e.g. "9 መስከረም 2019" or "9 Meskerem 2019".
  String format({bool amharic = true}) => '$day ${monthName(amharic)} $year';

  EthiopianDate copyWith({int? year, int? month, int? day}) =>
      EthiopianDate(year ?? this.year, month ?? this.month, day ?? this.day);
}
