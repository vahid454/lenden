import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../utils/app_formatters.dart';

/// Handles all share operations: WhatsApp, general share sheet, PDF share.
class ShareService {
  // ── WhatsApp ledger summary ───────────────────────────────────────────────

  static Future<void> shareOnWhatsApp({
    required CustomerEntity customer,
    required List<TransactionEntity> transactions,
    required String senderName,
    required String businessName,
  }) async {
    final msg = _buildLedgerMessage(
      customer:      customer,
      transactions:  transactions,
      senderName:    senderName,
      businessName:  businessName,
    );

    final encoded = Uri.encodeComponent(msg);
    final number  = customer.phone.replaceAll(RegExp(r'\D'), '');
    // Attempt to open chat directly with the customer's number
    final waUri   = Uri.parse('whatsapp://send?phone=91$number&text=$encoded');
    final fallUri = Uri.parse('https://wa.me/91$number?text=$encoded');

    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri);
    } else if (await canLaunchUrl(fallUri)) {
      await launchUrl(fallUri, mode: LaunchMode.externalApplication);
    }
  }

  // ── General share sheet ───────────────────────────────────────────────────

  static Future<void> shareText({
    required CustomerEntity customer,
    required List<TransactionEntity> transactions,
    required String senderName,
    required String businessName,
  }) async {
    final msg = _buildLedgerMessage(
      customer:     customer,
      transactions: transactions,
      senderName:   senderName,
      businessName: businessName,
    );

    await Share.share(
      msg,
      subject: 'Ledger with ${customer.name} — LenDen',
    );
  }

  // ── PDF share ─────────────────────────────────────────────────────────────

  static Future<void> sharePdf(File pdfFile, String customerName) async {
    await Share.shareXFiles(
      [XFile(pdfFile.path)],
      subject: 'Ledger — $customerName',
      text: 'Here is your account statement from LenDen.',
    );
  }

  // ── Message builder ───────────────────────────────────────────────────────

  static String _buildLedgerMessage({
    required CustomerEntity customer,
    required List<TransactionEntity> transactions,
    required String senderName,
    required String businessName,
  }) {
    final buf     = StringBuffer();
    final bizLine = businessName.isNotEmpty ? '*$businessName*\n' : '';

    buf.writeln('🏦 *LenDen — Account Statement*');
    buf.writeln(bizLine);
    buf.writeln('Party: *${customer.name}*');
    buf.writeln('Date: ${AppFormatters.shortDate(DateTime.now())}');
    buf.writeln('─────────────────────────');

    if (transactions.isNotEmpty) {
      // Show last 10 only to keep message readable
      final recent = transactions.take(10).toList();
      for (final tx in recent) {
        final icon  = tx.isGave ? '🟢' : '🔴';
        final label = tx.isGave ? 'Gave' : 'Got ';
        final note  = tx.note?.isNotEmpty == true ? ' (${tx.note})' : '';
        buf.writeln(
            '$icon $label  ${AppFormatters.rupee(tx.amount).padLeft(10)}  '
            '${AppFormatters.shortDate(tx.date)}$note');
      }
      if (transactions.length > 10) {
        buf.writeln('... and ${transactions.length - 10} more entries');
      }
      buf.writeln('─────────────────────────');
    }

    // Balance line
    if (customer.isSettled) {
      buf.writeln('✅ *Balance: SETTLED*');
    } else if (customer.isCreditor) {
      buf.writeln(
          '💰 *${customer.name} to give: ${AppFormatters.rupee(customer.absBalance)}*');
    } else {
      buf.writeln(
          '💸 *You to give: ${AppFormatters.rupee(customer.absBalance)}*');
    }

    buf.writeln('');
    buf.writeln('_Sent via LenDen App_');
    return buf.toString();
  }
}
