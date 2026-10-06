import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/transaction_entity.dart';

/// Compact two-column transaction tile.
/// Gave (green) on left column, Got (red) on right column — like a ledger.
class TransactionTile extends StatelessWidget {
  final TransactionEntity transaction;
  final bool isDeleting;
  final int animationIndex;
  final bool invertPerspective;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onEdit,
    this.onDelete,
    this.isDeleting = false,
    this.animationIndex = 0,
    this.invertPerspective = false,
  });

  @override
  Widget build(BuildContext context) {
    final isGave = invertPerspective ? transaction.isGot : transaction.isGave;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = _fmtAmount(transaction.amount);
    final fmtDate = _fmtDate(transaction.date);

    return AnimatedOpacity(
      opacity: isDeleting ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                children: [
                  // ── Date + note ───────────────────────────────────────────
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 36,
                            decoration: BoxDecoration(
                              color:
                                  isGave ? AppColors.success : AppColors.danger,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  fmtDate,
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface.withOpacity(0.74)),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isGave ? 'You gave' : 'You got',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: cs.onSurface.withOpacity(0.45)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Divider ───────────────────────────────────────────────
                  VerticalDivider(
                    width: 1,
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),

                  // ── Gave column ───────────────────────────────────────────
                  Expanded(
                    flex: 3,
                    child: _AmountCell(
                      amount: isGave ? fmt : null,
                      color: AppColors.success,
                      label: 'Gave',
                    ),
                  ),

                  // ── Divider ───────────────────────────────────────────────
                  VerticalDivider(
                    width: 1,
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),

                  // ── Got column ────────────────────────────────────────────
                  Expanded(
                    flex: 3,
                    child: _AmountCell(
                      amount: !isGave ? fmt : null,
                      color: AppColors.danger,
                      label: 'Got',
                    ),
                  ),
                ],
              ),
            ),
            if (transaction.note?.trim().isNotEmpty == true) ...[
              Divider(
                height: 1,
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_rounded,
                        size: 17, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        transaction.note!.trim(),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          height: 1.45,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: animationIndex * 35))
        .fadeIn(duration: 220.ms)
        .slideX(begin: 0.03, end: 0, curve: Curves.easeOut);
  }

  String _fmtDate(DateTime dt) {
    return DateFormat('d MMM yyyy').format(dt);
  }

  String _fmtAmount(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return NumberFormat('#,##,###').format(v);
    return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
  }
}

class _AmountCell extends StatelessWidget {
  final String? amount;
  final Color color;
  final String label;

  const _AmountCell({this.amount, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (amount != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '₹$amount',
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w800, color: color),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Text(
              '—',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: cs.onSurface.withOpacity(0.2)),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
