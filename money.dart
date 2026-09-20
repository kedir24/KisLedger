import 'package:intl/intl.dart';

/// Money is stored as an integer number of santim to avoid float drift.
class Money {
  static final NumberFormat _plain = NumberFormat('#,##0.00');

  static String format(int santim, {bool withSymbol = true}) {
    final text = _plain.format(santim / 100);
    return withSymbol ? '$text ብር' : text;
  }

  static String formatCompact(int santim) {
    final birr = santim / 100;
    if (birr.abs() >= 1000000) {
      return '${(birr / 1000000).toStringAsFixed(1)}M';
    }
    if (birr.abs() >= 1000) {
      return '${(birr / 1000).toStringAsFixed(1)}K';
    }
    return birr.toStringAsFixed(0);
  }

  /// Parses user input like "1,250.50" or "1250" into santim.
  /// Returns null when the text is not a valid non-negative amount.
  static int? parse(String input) {
    final cleaned = input.replaceAll(',', '').replaceAll(' ', '').trim();
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null || value.isNaN || value < 0) return null;
    return (value * 100).round();
  }
}
