import '../constants/app_constants.dart';

/// Form field validators — returns null if valid, error string if invalid.
class Validators {
  Validators._();

  /// Validates Indian 10-digit mobile number (digits only, starts with 6–9).
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your mobile number';
    }
    if (value.length != AppConstants.phoneLength) {
      return 'Please enter a valid 10-digit number';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
      return 'Please enter a valid Indian mobile number';
    }
    return null;
  }

  /// Validates person or business name.
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }
    final trimmed = value.trim();
    if (trimmed.length < AppConstants.minNameLength) {
      return 'Name must be at least ${AppConstants.minNameLength} characters';
    }
    if (trimmed.length > AppConstants.maxNameLength) {
      return 'Name cannot exceed ${AppConstants.maxNameLength} characters';
    }
    if (!RegExp(r"^[a-zA-Z\s\u0900-\u097F]+$").hasMatch(trimmed)) {
      return 'Name can only contain letters';
    }
    return null;
  }

  /// Optional name validation (allows empty).
  static String? optionalName(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return name(value);
  }

  /// Validates a monetary amount string.
  static String? amount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an amount';
    }
    final parsed = double.tryParse(value);
    if (parsed == null) return 'Please enter a valid amount';
    if (parsed <= 0) return 'Amount must be greater than ₹0';
    if (parsed > 10000000) return 'Amount cannot exceed ₹1 crore';
    return null;
  }
}
