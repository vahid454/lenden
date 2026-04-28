class AppConstants {
  AppConstants._(); // Prevent instantiation

  // ── SharedPreferences Keys ────────────────────────────────────────────────
  static const String prefUserId         = 'user_id';
  static const String prefUserName       = 'user_name';
  static const String prefUserPhone      = 'user_phone';
  static const String prefBusinessName   = 'business_name';
  static const String prefIsDarkMode     = 'is_dark_mode';
  static const String prefIsOnboarded    = 'is_onboarded';
  static const String prefIsPinEnabled   = 'is_pin_enabled';

  // ── Firestore Collection Names ────────────────────────────────────────────
  static const String colUsers        = 'users';
  static const String colCustomers    = 'customers';
  static const String colTransactions = 'transactions';

  // ── Transaction Types ─────────────────────────────────────────────────────
  static const String txTypeGave = 'gave';
  static const String txTypeGot  = 'got';

  // ── OTP Config ────────────────────────────────────────────────────────────
  static const int otpLength              = 6;
  static const Duration otpTimeout        = Duration(seconds: 60);
  static const Duration resendCooldown    = Duration(seconds: 30);

  // ── Validation ────────────────────────────────────────────────────────────
  static const int minNameLength  = 2;
  static const int maxNameLength  = 50;
  static const int phoneLength    = 10;
  static const double maxAmount   = 10000000; // ₹1 Crore

  // ── Pagination ────────────────────────────────────────────────────────────
  static const int customerPageSize   = 20;
  static const int txPageSize         = 30;

  // ── Currency ──────────────────────────────────────────────────────────────
  static const String currencySymbol = '₹';
  static const String currencyCode   = 'INR';

  // ── App Info ──────────────────────────────────────────────────────────────
  static const String appName    = 'LenDen';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Apna hisaab, apni marzi';

  // ── Country ───────────────────────────────────────────────────────────────
  static const String defaultCountryCode = '+91';
  static const String defaultCountryFlag = '🇮🇳';
}
