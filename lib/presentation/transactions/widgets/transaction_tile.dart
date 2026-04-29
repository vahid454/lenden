import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../domain/entities/transaction_entity.dart';

/// READ-ONLY transaction tile — edit and delete are intentionally disabled.
/// Transactions are permanent records. Users must contact support to correct errors.
class TransactionTile extends StatelessWidget {
  final TransactionEntity transaction;
  final bool              isDeleting;
  final int               animationIndex;
  final bool invertPerspective;

  // onEdit and onDelete kept in signature for API compat but are ignored.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onEdit,
    this.onDelete,
    this.isDeleting    = false,
    this.animationIndex = 0,
    this.invertPerspective = false,
  });

  @override
  Widget build(BuildContext context) {
    final isGave  = invertPerspective ? transaction.isGot : transaction.isGave;
    final color   = isGave ? AppColors.success : AppColors.danger;
    final bgColor = isGave ? AppColors.successLight : AppColors.dangerLight;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cs      = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color:        cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: isDark ? [] : [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Type icon pill
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: bgColor, borderRadius: BorderRadius.circular(12)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isGave
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: color, size: 18,
                  ),
                  Text(
                    isGave ? 'GAVE' : 'GOT',
                    style: GoogleFonts.poppins(
                        fontSize: 7, fontWeight: FontWeight.w800,
                        color: color, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Date + note
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(transaction.date),
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: cs.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction.note?.isNotEmpty == true
                        ? transaction.note!
                        : isGave ? 'You gave money' : 'You got money',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: transaction.note?.isNotEmpty == true
                          ? cs.onSurface.withOpacity(0.5)
                          : cs.onSurface.withOpacity(0.35),
                      fontStyle: transaction.note?.isNotEmpty == true
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isGave ? '+' : '-'}₹${_fmtAmount(transaction.amount)}',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(transaction.date),
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: cs.onSurface.withOpacity(0.35)),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: animationIndex * 40))
        .fadeIn(duration: 250.ms)
        .slideX(begin: 0.04, end: 0, curve: Curves.easeOut);
  }

  String _formatDate(DateTime dt) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('d MMM yyyy').format(dt);
  }

  String _formatTime(DateTime dt) => DateFormat('h:mm a').format(dt);

  String _fmtAmount(double v) {
    return AppFormatters.currency(v);
  }
}
