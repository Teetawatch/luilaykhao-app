part of 'payment_screen.dart';

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: AppTheme.cardDecoration(
        context,
        radius: 24,
        borderColor: AppTheme.border(context).withValues(alpha: 0.65),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _accent.withValues(
              alpha: AppTheme.isDark(context) ? 0.18 : 0.10,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _accent, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.anuphan(
              color: AppTheme.onSurface(context),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool compact;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: selected
              ? _accent.withValues(
                  alpha: AppTheme.isDark(context) ? 0.18 : 0.08,
                )
              : AppTheme.fieldSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _accent : AppTheme.border(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? _accent : AppTheme.mutedText(context),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: selected
                          ? _accent
                          : AppTheme.onSurface(context),
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 12.5 : 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.mutedText(context),
                      fontSize: compact ? 10.5 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: _accent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final BuildContext context;

  const _InfoPill({
    required this.context,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext _) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.fieldSurface(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.mutedText(context)),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.mutedText(context), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.anuphan(
              color: valueColor ?? AppTheme.onSurface(context),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  final _InstallmentPreview row;

  const _InstallmentRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final isFirst = row.no == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isFirst
            ? AppTheme.warningTint(context)
            : AppTheme.fieldSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFirst
              ? AppTheme.warningColor.withValues(alpha: 0.35)
              : AppTheme.border(context),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isFirst
                  ? AppTheme.warningColor.withValues(alpha: 0.15)
                  : AppTheme.subtleSurface(context),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${row.no}',
                style: GoogleFonts.anuphan(
                  color: isFirst
                      ? AppTheme.warningColor
                      : AppTheme.mutedText(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'งวดที่ ${row.no}',
                  style: GoogleFonts.anuphan(
                    color: AppTheme.onSurface(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                Text(
                  dateText(row.dueDate),
                  style: GoogleFonts.anuphan(
                    color: AppTheme.mutedText(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            money(row.amount),
            style: GoogleFonts.anuphan(
              color: isFirst ? AppTheme.warningColor : _accent,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _BankInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _BankInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.fieldSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.anuphan(
              color: AppTheme.onSurface(context),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _CopyButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.anuphan(fontWeight: FontWeight.w800, fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _accent,
        side: BorderSide(color: AppTheme.border(context)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool filled;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: filled
              ? _accent.withValues(
                  alpha: AppTheme.isDark(context) ? 0.16 : 0.07,
                )
              : AppTheme.fieldSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: filled ? _accent : AppTheme.border(context),
            width: filled ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: filled ? _accent : AppTheme.mutedText(context),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.mutedText(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: filled ? _accent : AppTheme.onSurface(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.anuphan(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RequiredBadge extends StatelessWidget {
  final bool done;

  const _RequiredBadge({required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: done
            ? _accent.withValues(alpha: 0.10)
            : AppTheme.warningTint(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: done
              ? _accent.withValues(alpha: 0.20)
              : AppTheme.warningColor.withValues(alpha: 0.30),
        ),
      ),
      child: Text(
        done ? 'แนบแล้ว' : 'จำเป็น',
        style: GoogleFonts.anuphan(
          color: done ? _accent : AppTheme.warningColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.fieldSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _accent, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.anuphan(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppTheme.onSurface(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.border(context).withValues(alpha: 0.50),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

