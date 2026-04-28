import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/transaction_entity.dart';

/// A single transaction row in the ledger.
/// Green = You Gave (you will receive), Red = You Got (you gave money back).
class TransactionTile extends StatelessWidget {
  final TransactionEntity transaction;
  final VoidCallback?     onEdit;
  final VoidCallback?     onDelete;
  final bool              isDeleting;
  final int               animationIndex;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onEdit,
    this.onDelete,
    this.isDeleting    = false,
    this.animationIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isGave     = transaction.isGave;
    final color      = isGave ? AppColors.success : AppColors.danger;
    final bgColor    = isGave ? AppColors.successLight : AppColors.dangerLight;
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final cs         = Theme.of(context).colorScheme;

    return AnimatedOpacity(
      opacity:  isDeleting ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin:     const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color:        cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            width: 1,
          ),
          boxShadow: isDark ? [] : [
            BoxShadow(
              color:  Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color:        Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap:        isDeleting ? null : onEdit,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // ── Type icon pill ──────────────────────────────────────
                  Container(
                    width:  44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:        bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isGave
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          color: color,
                          size:  18,
                        ),
                        Text(
                          isGave ? 'GAVE' : 'GOT',
                          style: GoogleFonts.poppins(
                            fontSize:   7,
                            fontWeight: FontWeight.w800,
                            color:      color,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ── Date + Note ─────────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(transaction.date),
                          style: GoogleFonts.poppins(
                            fontSize:   13,
                            fontWeight: FontWeight.w600,
                            color:      cs.onSurface,
                          ),
                        ),
                        if (transaction.note != null &&
                            transaction.note!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            transaction.note!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color:    cs.onSurface.withOpacity(0.5),
                            ),
                            maxLines:  1,
                            overflow:  TextOverflow.ellipsis,
                          ),
                        ] else ...[
                          const SizedBox(height: 2),
                          Text(
                            transaction.isGave ? 'You gave money' : 'You got money',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color:    cs.onSurface.withOpacity(0.35),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Amount ──────────────────────────────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isGave ? '+' : '-'}₹${_fmtAmount(transaction.amount)}',
                        style: GoogleFonts.poppins(
                          fontSize:   15,
                          fontWeight: FontWeight.w700,
                          color:      color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTime(transaction.date),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color:    cs.onSurface.withOpacity(0.35),
                        ),
                      ),
                    ],
                  ),

                  // ── Action menu ─────────────────────────────────────────
                  if (!isDeleting && (onEdit != null || onDelete != null))
                    _TileMenu(onEdit: onEdit, onDelete: onDelete)
                  else if (isDeleting)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
          ),
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
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return NumberFormat('#,##,###').format(v);
    return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
  }
}

// ── Popup menu ────────────────────────────────────────────────────────────────

class _TileMenu extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TileMenu({this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'edit')   onEdit?.call();
        if (v == 'delete') onDelete?.call();
      },
      icon: Icon(
        Icons.more_vert_rounded,
        size:  18,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        if (onEdit != null)
          PopupMenuItem(
            value: 'edit',
            child: _menuRow(Icons.edit_outlined, 'Edit', AppColors.primary),
          ),
        if (onDelete != null)
          PopupMenuItem(
            value: 'delete',
            child: _menuRow(
                Icons.delete_outline_rounded, 'Delete', AppColors.danger),
          ),
      ],
    );
  }

  Widget _menuRow(IconData icon, String label, Color color) => Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Text(label, style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w500)),
    ],
  );
}
