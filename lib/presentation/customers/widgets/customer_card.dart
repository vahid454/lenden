import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/customer_entity.dart';

/// Premium customer list tile — tap to open ledger.
/// Edit and delete intentionally removed for data safety.
class CustomerCard extends StatelessWidget {
  final CustomerEntity customer;
  final VoidCallback   onTap;
  final VoidCallback?  onEdit;   // kept for API compat only
  final VoidCallback?  onDelete; // kept for API compat only
  final bool           isDeleting;
  final int            animationIndex;
  final bool           invertPerspective; // true when shared ledger
  final bool           showSharedBadge;

  const CustomerCard({
    super.key,
    required this.customer,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.isDeleting        = false,
    this.animationIndex    = 0,
    this.invertPerspective = false,
    this.showSharedBadge   = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveBalance =
        invertPerspective ? -customer.balance : customer.balance;

    Color balanceColor;
    Color balanceBg;
    String balanceLabel;
    IconData balanceIcon;

    if (effectiveBalance > 0) {
      balanceColor = AppColors.success;
      balanceBg    = AppColors.successLight;
      balanceLabel = invertPerspective ? 'You owe' : 'Will give';
      balanceIcon  = Icons.arrow_downward_rounded;
    } else if (effectiveBalance < 0) {
      balanceColor = AppColors.danger;
      balanceBg    = AppColors.dangerLight;
      balanceLabel = invertPerspective ? 'Owes you' : 'Will take';
      balanceIcon  = Icons.arrow_upward_rounded;
    } else {
      balanceColor = cs.onSurface.withOpacity(0.4);
      balanceBg    = isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant;
      balanceLabel = 'Settled';
      balanceIcon  = Icons.check_circle_outline_rounded;
    }

    final amountText = effectiveBalance == 0
        ? 'Cleared'
        : '₹${_fmt(effectiveBalance.abs())}';

    return AnimatedOpacity(
      opacity:  isDeleting ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color:        cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
          boxShadow: isDark ? [] : [
            BoxShadow(
                color:     Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset:    const Offset(0, 3)),
          ],
        ),
        child: Material(
          color:        Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap:        isDeleting ? null : onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                // ── Avatar ────────────────────────────────────────────────
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                          color: balanceColor.withOpacity(0.12),
                          shape: BoxShape.circle),
                      child: Center(child: Text(customer.initials,
                          style: GoogleFonts.poppins(
                              fontSize: 17, fontWeight: FontWeight.w700,
                              color: balanceColor))),
                    ),
                    if (showSharedBadge)
                      Positioned(
                        right: -2, bottom: -2,
                        child: Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.surface, width: 2),
                          ),
                          child: const Icon(Icons.sync_rounded,
                              size: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 14),

                // ── Name + phone ───────────────────────────────────────────
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: Text(customer.name,
                          style: GoogleFonts.poppins(fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (showSharedBadge) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Shared',
                              style: GoogleFonts.poppins(fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(customer.phone,
                        style: GoogleFonts.poppins(fontSize: 12,
                            color: cs.onSurface.withOpacity(0.45))),
                  ],
                )),

                const SizedBox(width: 10),

                // ── Balance chip ───────────────────────────────────────────
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
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
              ]),
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: animationIndex * 45))
        .fadeIn(duration: 280.ms)
        .slideX(begin: 0.04, end: 0, curve: Curves.easeOut);
  }

  String _fmt(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000)   return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return NumberFormat('#,##,###').format(v);
    return v.toStringAsFixed(0);
  }
}
