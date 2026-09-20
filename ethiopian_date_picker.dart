import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../utils/ethiopian_calendar.dart';

/// Shows a bottom sheet with Year / Month / Day wheels in the Ethiopian
/// calendar and resolves to the equivalent Gregorian [DateTime] — the rest
/// of the app keeps storing and sorting by Gregorian dates.
Future<DateTime?> showEthiopianDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  bool amharic = true,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final initial = EthiopianDate.fromGregorian(initialDate);
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EthiopianDatePickerSheet(
      initial: initial,
      amharic: amharic,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class _EthiopianDatePickerSheet extends StatefulWidget {
  const _EthiopianDatePickerSheet({
    required this.initial,
    required this.amharic,
    this.firstDate,
    this.lastDate,
  });

  final EthiopianDate initial;
  final bool amharic;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  State<_EthiopianDatePickerSheet> createState() =>
      _EthiopianDatePickerSheetState();
}

class _EthiopianDatePickerSheetState
    extends State<_EthiopianDatePickerSheet> {
  late int _year = widget.initial.year;
  late int _month = widget.initial.month;
  late int _day = widget.initial.day;

  late final FixedExtentScrollController _yearCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _dayCtrl;

  static const _yearSpan = 12; // ± years around the current selection
  late final int _minYear = _year - _yearSpan;
  late final int _maxYear = _year + _yearSpan;

  @override
  void initState() {
    super.initState();
    _yearCtrl =
        FixedExtentScrollController(initialItem: _year - _minYear);
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  void _clampDay() {
    final maxDay = EthiopianDate.daysInMonth(_year, _month);
    if (_day > maxDay) {
      _day = maxDay;
      _dayCtrl.dispose();
      _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxDay = EthiopianDate.daysInMonth(_year, _month);
    final theme = Theme.of(context);
    final names = widget.amharic
        ? EthiopianDate.monthNamesAm
        : EthiopianDate.monthNamesEn;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(widget.amharic ? 'ተወው' : 'Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final eth = EthiopianDate(_year, _month, _day);
                    Navigator.of(context).pop(eth.toGregorian());
                  },
                  child: Text(widget.amharic ? 'እሺ' : 'Done'),
                ),
              ],
            ),
            const Divider(height: 1),
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: CupertinoPicker(
                      scrollController: _monthCtrl,
                      itemExtent: 40,
                      onSelectedItemChanged: (i) => setState(() {
                        _month = i + 1;
                        _clampDay();
                      }),
                      children: [
                        for (final name in names)
                          Center(child: Text(name))
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: CupertinoPicker(
                      scrollController: _dayCtrl,
                      itemExtent: 40,
                      onSelectedItemChanged: (i) =>
                          setState(() => _day = i + 1),
                      children: [
                        for (var d = 1; d <= maxDay; d++)
                          Center(child: Text('$d'))
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: CupertinoPicker(
                      scrollController: _yearCtrl,
                      itemExtent: 40,
                      onSelectedItemChanged: (i) => setState(() {
                        _year = _minYear + i;
                        _clampDay();
                      }),
                      children: [
                        for (var y = _minYear; y <= _maxYear; y++)
                          Center(child: Text('$y'))
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
