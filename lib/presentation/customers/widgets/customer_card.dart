import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/customer_entity.dart';

/// Customer list tile — edit is available, delete is intentionally removed.
/// Deletion requires contacting admin via Help & Support.
class CustomerCard extends StatelessWidget {
  final CustomerEntity customer;
  final VoidCallback   onTap;
  final VoidCallback?  onEdit;
  // onDelete kept for API compat but unused — deletion is disabled in app.
  final VoidCallback?  onDelete;
  final bool           isDeleting;
  final int            animationIndex;

  const CustomerCard({
    super.key,
    required this.customer,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.isDeleting    = false,
    this.animationIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color balanceColor;
    Color balanceBg;
    String balanceLabel;
    IconData balanceIcon;

    if (customer.isCreditor) {
      balanceColor = AppColors.success;
      balanceBg    = AppColors.successLight;
      balanceLabel = 'Will give';
      balanceIcon  = Icons.arrow_downward_rounded;
    } else if (customer.isDebtor) {
      balanceColor = AppColors.danger;
      balanceBg    = AppColors.dangerLight;
      balanceLabel = 'Will take';
      balanceIcon  = Icons.arrow_upward_rounded;
    } else {
      balanceColor = cs.onSurface.withOpacity(0.45);
      balanceBg    = isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant;
      balanceLabel = 'Settled';
      balanceIcon  = Icons.check_circle_outline_rounded;
    }

    final amountText = customer.isSettled
        ? 'Cleared'
        : '₹${_formatAmount(customer.absBalance)}';

    return GestureDetector(
      onTap: isDeleting ? null : onTap,
      child: AnimatedOpacity(
        opacity:  isDeleting ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color:        cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            boxShadow: isDark ? [] : [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Material(
            color:        Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap:        isDeleting ? null : onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  // Avatar
                  _CustomerAvatar(
                      initials: customer.initials, color: balanceColor),
                  const SizedBox(width: 12),

                  // Name + phone
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.name, style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: cs.onSurface),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(customer.phone, style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.5))),
                    ],
                  )),

                  const SizedBox(width: 12),

                  // Balance chip
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: balanceBg,
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(balanceIcon, size: 12, color: balanceColor),
                        const SizedBox(width: 4),
                        Text(amountText, style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: balanceColor)),
                      ]),
                    ),
                    const SizedBox(height: 4),
                    Text(balanceLabel, style: GoogleFonts.poppins(
                        fontSize: 10, color: balanceColor.withOpacity(0.8),
                        fontWeight: FontWeight.w500)),
                  ]),

                  // Only show edit — no delete
                  if (onEdit != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.edit_outlined, size: 18,
                          color: cs.onSurface.withOpacity(0.35)),
                      onPressed: onEdit,
                      splashRadius: 20,
                      tooltip: 'Edit',
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: animationIndex * 50))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.05, end: 0, curve: Curves.easeOut);
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000)
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000)
      return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return NumberFormat('#,##,###').format(amount);
    return amount.toStringAsFixed(0);
  }
}

class _CustomerAvatar extends StatelessWidget {
  final String initials;
  final Color  color;
  const _CustomerAvatar({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
          color: color.withOpacity(0.12), shape: BoxShape.circle),
      child: Center(child: Text(initials, style: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w700, color: color))),
    );
  }
}
