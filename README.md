# SmartLedger

የ double-entry መዝገብ (Debit / Credit / Balance) ለአነስተኛ ንግዶች — Flutter + sqflite, offline-first.

## ማስኬጃ

```bash
flutter create . --project-name smartledger --platforms=android,ios
flutter pub get
flutter run
flutter test
```

`flutter create .` የሚያስፈልገው `android/`, `ios/`, `web/` የመሳሰሉ platform folders ለማመንጨት ብቻ ነው — በ `lib/` ያለው ኮድ አይነካም።

የአማርኛ ፊደል በትክክል እንዲታይ `assets/fonts/` ውስጥ [Noto Sans Ethiopic](https://fonts.google.com/noto/specimen/Noto+Sans+Ethiopic) ሶስቱን ፋይሎች አስገባ፤ ካልፈለግህ በ `pubspec.yaml` ያለውን `fonts:` ክፍልና በ `theme.dart` ያለውን `fontFamily` አጥፋ።

## መዋቅር

```
lib/
  models/account.dart        የአካውንት ዓይነትና normal-balance ደንብ
  models/journal.dart        Transaction, JournalLine, የ validate() ደንብ
  data/db.dart               sqflite schema + የመነሻ chart of accounts
  data/ledger_repository.dart post / reverse / balances / ledgerFor
  services/pdf_export.dart   Trial Balance / P&L / Balance Sheet / Ledger PDF
  services/sync_service.dart Supabase push / pull / auth
  services/supabase_config.dart  dart-define ውቅር (URL/anon key)
  state/ledger_state.dart    ChangeNotifier + quick entry shortcuts
  screens/                   Dashboard, Journal entry, Ledger, Reports, Settings
  utils/money.dart           santim ↔ ብር
  utils/strings.dart         አማርኛ / English
  utils/ethiopian_calendar.dart  ኢትዮጵያዊ ⇄ ግሪጎሪያዊ ቀን መቀየሪያ
  widgets/ethiopian_date_picker.dart  የኢትዮጵያ ቀን መምረጫ (wheel picker)
test/journal_test.dart       የ double-entry እና የቀን መቀየሪያ unit tests
```

## የሂሳብ ደንቦች

- ገንዘብ በ **santim** (int) ይከማቻል። double አይጠቀምም።
- ለእያንዳንዱ ግብይት `SUM(debit) == SUM(credit)`፤ ካልሆነ `post()` `PostException` ይወረውራል።
- እያንዳንዱ መስመር ዴቢት **ወይም** ክሬዲት ብቻ ይይዛል።
- Balance፦
  - ASSET / EXPENSE → `debit − credit`
  - LIABILITY / EQUITY / INCOME → `credit − debit`
- የተመዘገበ ግብይት አይሰረዝም፤ `reverse()` ተቃራኒ ግቤት ይጽፋል (audit trail ይጠበቃል)።

## የኢትዮጵያ ዘመን አቆጣጠር

- `lib/utils/ethiopian_calendar.dart` ውስጥ ያለው `EthiopianDate` ራሱን ችሎ የተሰራ converter ነው (ውጫዊ package አያስፈልገውም)፤ ከ Wikipedia ማጣቀሻ ቀናት (1992፣ 1996፣ 1998 ዓ.ም.) እና ከ2,000+ round-trip ሙከራዎች ጋር ተረጋግጧል።
- ቀኑ በውስጥ (DB) ሁሌም በ Gregorian ISO string ይቀመጣል፤ ለ display እና ለ picker ብቻ ወደ ኢትዮጵያዊ ይቀየራል — ይሄ sync እና sort ቀላል ያደርገዋል።
- `LedgerState.calendar` (ኢትዮጵያዊ/ግሪጎሪያዊ) በ Settings ገጽ ይቀየራል፤ `LedgerState.formatDate()` በሁሉም ገጾች (Dashboard, Ledger, Journal Entry) ጥቅም ላይ ይውላል።
- `lib/widgets/ethiopian_date_picker.dart` ውስጥ ያለው `showEthiopianDatePicker()` በ 13 ወር (ጳጉሜ 5/6 ቀን በትክክል) የሚሰራ wheel picker ነው።

## PDF Export

- `lib/services/pdf_export.dart` — Trial Balance, Income Statement (P&L), Balance Sheet, እና በአካውንት የተጣራ Ledger PDF ይሠራል፣ `pdf` + `printing` packages በመጠቀም ሙሉ በሙሉ offline።
- **Reports** ገጽ ላይ ባለው 📄 ቁልፍ፣ ወይም **Ledger** ገጽ ላይ ካለው ቁልፍ ተጠቅመህ ትልካለህ — `Printing.layoutPdf()` የስርዓቱን native "Print / Share / Save as PDF" ማያ ይከፍታል፤ ማተሚያ ሳይኖርም "Save as PDF" መርጦ ማስቀመጥ ወይም ወደ WhatsApp/Telegram/ኢሜይል ማጋራት ይቻላል።
- **አማርኛ ጽሑፍ በ PDF ውስጥ ለማሳየት** `assets/fonts/NotoSansEthiopic-Regular.ttf` እና `-Bold.ttf` መኖር አለባቸው (ከላይ ባለው "ማስኬጃ" ክፍል የተጠቀሱት ተመሳሳይ ፋይሎች ናቸው)። ካልተገኙ አፑ ስህተት አይሰብርም፤ ፋይሉ የት እንደሚገባ የሚገልጽ መልእክት ያሳያል።
- ገንዘብ ሁሌም በ `Money.format()` በኩል ስለሚታይ በ PDF እና በ UI መካከል ልዩነት አይኖርም።

## Cloud Sync (Supabase)

- **አንዴ ብቻ**፦ የ Supabase ፕሮጀክት ፍጠር፣ ከዚያ `supabase/schema.sql` ን በ Supabase SQL Editor ውስጥ አስኪድ (ሠንጠረዦችና Row Level Security ደንቦችን ይፈጥራል)።
- ኮዱ የፕሮጀክቱን URL/anon key አያውቅም — በ build ጊዜ ብቻ ትሰጣለህ፤ ምስጢሩ በኮድ ውስጥ አይቀመጥም፦
  ```bash
  flutter run \
    --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
    --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
  ```
  ካልሰጠህ አፑ ያለ ምንም ስህተት offline-only ሆኖ ይቀጥላል፤ Settings ላይ "ክላውድ ገና አልተዋቀረም" ይላል።
- **አካሄድ**፦ ግብይቶች (transactions/journal_lines) ፈጽሞ ስለማይታረሙ (reverse እንጂ delete/edit የለም) sync ቀላል ነው — አዲስ የተፈጠሩትን ብቻ በ id upsert ማድረግ ነው። አካውንቶች ብቻ ሊታረሙ ስለሚችሉ `updated_at` በመጠቀም **last-write-wins** ይሠራል።
- **መቼ ይሠራል**፦ ግብይት ከተመዘገበ በኋላ፣ አፑ ወደ ፊት ሲመጣ (app resume)፣ እና ከ Settings ላይ "አሁን አመሳስል" ተጭኖ። ኢንተርኔት ከሌለ ስህተት በጸጥታ ይታለፋል፤ ያልተላኩ ለውጦች ቁጥር (pending count) Settings ላይ ይታያል።
- **Sign in**፦ ቀላል ኢሜይል/የይለፍ ቃል (Supabase Auth)። እያንዳንዱ ተጠቃሚ የራሱን ውሂብ ብቻ ማየት ይችላል (RLS: `auth.uid() = user_id`)።
- `lib/services/sync_service.dart` — push/pull/auth
- `lib/services/supabase_config.dart` — dart-define ውቅር
- `lib/screens/auth_sheet.dart` — sign in/up ማያ

## ቀጥሎ የሚጨመር

- የደረሰኝ ፎቶ ማያያዝ (`attachment_path` አምድ ተዘጋጅቷል)
- PIN / biometric lock እና የተመሰጠረ DB (sqlcipher)
