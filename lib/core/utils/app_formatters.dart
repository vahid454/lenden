import 'package:intl/intl.dart';

/// Shared formatting helpers used across presentation and widgets.
/// Centralised here so formatting is consistent everywhere.
class AppFormatters {
  AppFormatters._();

  // ── Currency ──────────────────────────────────────────────────────────────

  /// Full Indian number format: 1,23,456.78
  static final _inrFull = NumberFormat('#,##,###.##', 'en_IN');

  /// Compact format for large amounts: 1.2L, 3.4Cr
  static String currency(double amount, {bool compact = false}) {
    if (compact) return compactCurrency(amount);
    final formatted = _inrFull.format(amount);
    // Remove trailing .00
    return formatted.endsWith('.00')
        ? formatted.substring(0, formatted.length - 3)
        : formatted;
  }

  /// Always returns a compact readable string.
  static String compactCurrency(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    }
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
  }

  /// Rupee symbol prefix: ₹1,23,456
  static String rupee(double amount, {bool compact = false}) =>
      '₹${currency(amount, compact: compact)}';

  // ── Date ──────────────────────────────────────────────────────────────────

  static final _dateLong   = DateFormat('d MMMM yyyy');
  static final _dateShort  = DateFormat('d MMM yyyy');
  static final _monthYear  = DateFormat('MMMM yyyy');
  static final _time12     = DateFormat('h:mm a');

  /// "Today", "Yesterday", or "14 Mar 2025"
  static String relativeDate(DateTime dt) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return _dateShort.format(dt);
  }

  /// "14 March 2025"
  static String longDate(DateTime dt) => _dateLong.format(dt);

  /// "14 Mar 2025"
  static String shortDate(DateTime dt) => _dateShort.format(dt);

  /// "March 2025"
  static String monthYear(DateTime dt) => _monthYear.format(dt);

  /// "2:30 PM"
  static String time(DateTime dt) => _time12.format(dt);

  /// "YYYY-MM" for grouping queries
  static String yearMonth(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

  // ── Phone ─────────────────────────────────────────────────────────────────

  /// "98765 43210"
  static String phone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return raw;
  }
}
