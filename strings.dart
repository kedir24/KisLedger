enum AppLang { am, en }

enum CalendarSystem { ethiopian, gregorian }

/// A small hand-rolled string table. Swap for gen_l10n once the copy settles.
class S {
  final AppLang lang;
  const S(this.lang);

  String _(String am, String en) => lang == AppLang.am ? am : en;

  String get appName => 'SmartLedger';
  String get dashboard => _('ዋና ገጽ', 'Dashboard');
  String get entries => _('ግብይቶች', 'Entries');
  String get ledger => _('መዝገብ', 'Ledger');
  String get reports => _('ሪፖርቶች', 'Reports');
  String get settings => _('ቅንብሮች', 'Settings');
  String get calendarSystem => _('የቀን አቆጣጠር', 'Calendar');
  String get ethiopianCalendar => _('ኢትዮጵያዊ', 'Ethiopian');
  String get gregorianCalendar => _('ግሪጎሪያዊ', 'Gregorian');

  String get income => _('ገቢ', 'Income');
  String get expense => _('ወጪ', 'Expense');
  String get net => _('የተጣራ', 'Net');
  String get balance => _('ቀሪ ሂሳብ', 'Balance');
  String get debit => _('ዴቢት', 'Debit');
  String get credit => _('ክሬዲት', 'Credit');
  String get cashOnHand => _('በእጅ ያለ ገንዘብ', 'Cash on hand');

  String get newEntry => _('አዲስ ግብይት', 'New entry');
  String get quickEntry => _('ፈጣን ግቤት', 'Quick entry');
  String get recentEntries => _('የቅርብ ግብይቶች', 'Recent entries');
  String get noEntriesYet =>
      _('ገና ምንም ግብይት የለም። በ + ቁልፍ ጀምር።', 'No entries yet. Tap + to start.');

  String get date => _('ቀን', 'Date');
  String get memo => _('መግለጫ', 'Description');
  String get reference => _('ማጣቀሻ', 'Reference');
  String get account => _('አካውንት', 'Account');
  String get amount => _('መጠን', 'Amount');
  String get addLine => _('መስመር ጨምር', 'Add line');
  String get post => _('መዝግብ', 'Post entry');
  String get posted => _('ተመዝግቧል', 'Posted');
  String get reverse => _('መልስ (Reverse)', 'Reverse entry');
  String get reversed => _('ተመላሽ ሆኗል', 'Reversed');
  String get selectAccount => _('አካውንት ምረጥ', 'Select account');

  String get totalDebit => _('ጠቅላላ ዴቢት', 'Total debit');
  String get totalCredit => _('ጠቅላላ ክሬዲት', 'Total credit');
  String get difference => _('ልዩነት', 'Difference');
  String get balancedOk => _('ሚዛኑ ትክክል ነው', 'Entry is balanced');

  String get trialBalance => _('የሙከራ ሚዛን', 'Trial balance');
  String get runningBalance => _('ተከታታይ ቀሪ', 'Running balance');

  String get assets => _('ንብረቶች', 'Assets');
  String get liabilities => _('ዕዳዎች', 'Liabilities');
  String get equity => _('ካፒታል', 'Equity');

  String get cancel => _('ተወው', 'Cancel');
  String get save => _('አስቀምጥ', 'Save');

  /// Turns a validation reason code into a message.
  String validationMessage(String code) {
    switch (code) {
      case 'needs_two_lines':
        return _('ቢያንስ ሁለት መስመር ያስፈልጋል።', 'An entry needs at least two lines.');
      case 'line_needs_one_side':
        return _('እያንዳንዱ መስመር ዴቢት ወይም ክሬዲት ብቻ ይይዝ።',
            'Each line takes either a debit or a credit, not both.');
      case 'line_needs_account':
        return _('ለእያንዳንዱ መስመር አካውንት ምረጥ።', 'Pick an account for every line.');
      case 'zero_amount':
        return _('መጠኑ ከዜሮ በላይ መሆን አለበት።', 'The amount must be above zero.');
      case 'out_of_balance':
        return _('ዴቢትና ክሬዲት አልተመጣጠኑም።', 'Debits and credits do not match.');
      default:
        return _('ግብይቱ መመዝገብ አይችልም።', 'This entry cannot be posted.');
    }
  }
}
