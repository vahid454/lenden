import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../domain/entities/customer_entity.dart';

/// Displays a single customer as a list tile with avatar, name, phone,
/// and a colour-coded balance indicator (green = owe you, red = you owe).
class CustomerCard extends StatelessWidget {
  final CustomerEntity customer;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isDeleting;
  final int animationIndex;

  const CustomerCard({
    super.key,
    required this.customer,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.isDeleting = false,
    this.animationIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Balance colour logic ───────────────────────────────────────────────
    Color balanceColor;
    Color balanceBg;
    String balanceLabel;
    IconData balanceIcon;

    if (customer.isCreditor) {
      balanceColor = AppColors.success;
      balanceBg = AppColors.successLight;
      balanceLabel = 'Will give';
      balanceIcon = Icons.arrow_downward_rounded;
    } else if (customer.isDebtor) {
      balanceColor = AppColors.danger;
      balanceBg = AppColors.dangerLight;
      balanceLabel = 'Will take';
      balanceIcon = Icons.arrow_upward_rounded;
    } else {
      balanceColor = colorScheme.onSurface.withOpacity(0.45);
      balanceBg = isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant;
      balanceLabel = 'Settled';
      balanceIcon = Icons.check_circle_outline_rounded;
    }

    final amountText = customer.isSettled
        ? 'Cleared'
        : '₹${_formatAmount(customer.absBalance)}';

    return GestureDetector(
      onTap: isDeleting ? null : onTap,
      child: AnimatedOpacity(
        opacity: isDeleting ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
              width: 1,
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: isDeleting ? null : onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // ── Avatar ───────────────────────────────────────────
                    _CustomerAvatar(
                      initials: customer.initials,
                      color: balanceColor,
                    ),

                    const SizedBox(width: 12),

                    // ── Name + Phone ─────────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customer.phone,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // ── Balance chip ─────────────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: balanceBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(balanceIcon, size: 12, color: balanceColor),
                              const SizedBox(width: 4),
                              Text(
                                amountText,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: balanceColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          balanceLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: balanceColor.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // ── Action menu ─────────────────────────────────────
                    if (onEdit != null || onDelete != null) ...[
                      const SizedBox(width: 4),
                      _ActionMenu(
                        onEdit: onEdit,
                        onDelete: onDelete,
                        isDeleting: isDeleting,
                      ),
                    ],
                  ],
                ),
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
    return AppFormatters.currency(amount);
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _CustomerAvatar extends StatelessWidget {
  final String initials;
  final Color color;

  const _CustomerAvatar({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ── Action Menu (Edit / Delete) ───────────────────────────────────────────────

class _ActionMenu extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isDeleting;

  const _ActionMenu({this.onEdit, this.onDelete, this.isDeleting = false});

  @override
  Widget build(BuildContext context) {
    if (isDeleting) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') onEdit?.call();
        if (value == 'delete') onDelete?.call();
      },
      icon: Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        if (onEdit != null)
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(
                  'Edit',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        if (onDelete != null)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.danger),
                const SizedBox(width: 10),
                Text(
                  'Delete',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
