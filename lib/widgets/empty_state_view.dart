import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// [EmptyStateView] inside an always-scrollable viewport.
///
/// A screen whose body is a `RefreshIndicator` loses pull-to-refresh the moment
/// it shows a non-scrolling empty state — exactly when the user most wants to
/// retry. This keeps the gesture alive by giving the indicator something that
/// still overscrolls, while the content stays vertically centred.
class ScrollableEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? accent;

  const ScrollableEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: EmptyStateView(
            icon: icon,
            title: title,
            body: body,
            actionLabel: actionLabel,
            onAction: onAction,
            accent: accent,
          ),
        ),
      ),
    );
  }
}

/// Standard empty-state visual: tinted glyph, headline, body, optional CTA.
///
/// Replaces ad-hoc Column/Text combos scattered across screens so empty
/// states share the same visual rhythm.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? accent;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppTheme.primaryColor;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: tint, size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: appFont(
                color: AppTheme.onSurface(context),
                fontSize: AppText.sizeSubtitle,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: appFont(
                  color: AppTheme.mutedText(context),
                  fontSize: AppText.sizeLabel,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: tint,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: appFont(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
