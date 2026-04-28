import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';

import '../../core/providers/auth_providers.dart';

/// Box names
class HiveBoxes {
  static const String customers    = 'cache_customers';
  static const String transactions = 'cache_transactions';
  static const String settings     = 'settings';
  static const String reports      = 'cache_reports';
}

/// Keys inside the settings box
class HiveKeys {
  static const String pinEnabled     = 'pin_enabled';
  static const String pinHash        = 'pin_hash';
  static const String biometricEnabled = 'biometric_enabled';
  static const String lastSyncTime   = 'last_sync_time';
  static const String isDarkMode     = 'is_dark_mode';
}

/// Initializes all Hive boxes. Call in main() before runApp().
Future<void> initHive() async {
  await Hive.initFlutter();
  await Hive.openBox<String>(HiveBoxes.customers);
  await Hive.openBox<String>(HiveBoxes.transactions);
  await Hive.openBox(HiveBoxes.settings);
  await Hive.openBox<String>(HiveBoxes.reports);
}

// ── Cache Service ─────────────────────────────────────────────────────────────

class CacheService {
  final Logger _log;

  CacheService({Logger? logger}) : _log = logger ?? Logger();

  // ── Customer cache ────────────────────────────────────────────────────────

  Future<void> cacheCustomers(String userId, List<Map<String, dynamic>> data) async {
    try {
      final box = Hive.box<String>(HiveBoxes.customers);
      await box.put(userId, jsonEncode(data));
      _log.d('Cached ${data.length} customers for $userId');
    } catch (e) {
      _log.w('Customer cache write failed: $e');
    }
  }

  List<Map<String, dynamic>> getCachedCustomers(String userId) {
    try {
      final box  = Hive.box<String>(HiveBoxes.customers);
      final json = box.get(userId);
      if (json == null) return [];
      return (jsonDecode(json) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _log.w('Customer cache read failed: $e');
      return [];
    }
  }

  // ── Transaction cache ─────────────────────────────────────────────────────

  Future<void> cacheTransactions(
      String customerId, List<Map<String, dynamic>> data) async {
    try {
      final box = Hive.box<String>(HiveBoxes.transactions);
      await box.put(customerId, jsonEncode(data));
      _log.d('Cached ${data.length} transactions for $customerId');
    } catch (e) {
      _log.w('Transaction cache write failed: $e');
    }
  }

  List<Map<String, dynamic>> getCachedTransactions(String customerId) {
    try {
      final box  = Hive.box<String>(HiveBoxes.transactions);
      final json = box.get(customerId);
      if (json == null) return [];
      return (jsonDecode(json) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _log.w('Transaction cache read failed: $e');
      return [];
    }
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  bool get isPinEnabled =>
      Hive.box(HiveBoxes.settings).get(HiveKeys.pinEnabled, defaultValue: false);

  String? get pinHash =>
      Hive.box(HiveBoxes.settings).get(HiveKeys.pinHash);

  bool get isBiometricEnabled =>
      Hive.box(HiveBoxes.settings).get(HiveKeys.biometricEnabled, defaultValue: false);

  Future<void> setPin(String hashedPin) async {
    final box = Hive.box(HiveBoxes.settings);
    await box.put(HiveKeys.pinEnabled, true);
    await box.put(HiveKeys.pinHash, hashedPin);
  }

  Future<void> disablePin() async {
    final box = Hive.box(HiveBoxes.settings);
    await box.put(HiveKeys.pinEnabled, false);
    await box.delete(HiveKeys.pinHash);
  }

  Future<void> setBiometric(bool enabled) async =>
      Hive.box(HiveBoxes.settings).put(HiveKeys.biometricEnabled, enabled);

  // ── Clear cache on logout ─────────────────────────────────────────────────

  Future<void> clearUserCache() async {
    await Hive.box<String>(HiveBoxes.customers).clear();
    await Hive.box<String>(HiveBoxes.transactions).clear();
    await Hive.box<String>(HiveBoxes.reports).clear();
    _log.i('User cache cleared');
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService(logger: ref.watch(loggerProvider));
});
