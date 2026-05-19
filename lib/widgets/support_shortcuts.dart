import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Resolves a contact channel from `stats.contact` (returned by the backend's
/// `/stats` endpoint), with hard-coded fallbacks for graceful degradation when
/// the backend hasn't been seeded yet.
class SupportContact {
  static const _defaults = {
    'phone': '0626126006',
    'line': '@luilaykhao',
    'line_url': 'https://line.me/R/ti/p/@luilaykhao',
    'email': 'luilaykhao.info@gmail.com',
  };

  final String phone;
  final String line;
  final String lineUrl;
  final String email;

  const SupportContact({
    required this.phone,
    required this.line,
    required this.lineUrl,
    required this.email,
  });

  factory SupportContact.fromStats(Map<String, dynamic>? stats) {
    final contact = stats?['contact'];
    final map = contact is Map ? Map<String, dynamic>.from(contact) : const {};
    String pick(String key) {
      final value = map[key];
      if (value == null) return _defaults[key] ?? '';
      final str = value.toString().trim();
      if (str.isEmpty) return _defaults[key] ?? '';
      return str;
    }

    return SupportContact(
      phone: pick('phone'),
      line: pick('line'),
      lineUrl: pick('line_url'),
      email: pick('email'),
    );
  }
}

class SupportShortcuts extends StatelessWidget {
  const SupportShortcuts({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.select<AppProvider, Map<String, dynamic>?>(
      (p) => p.stats,
    );
    final contact = SupportContact.fromStats(stats);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ติดต่อด่วน',
            style: GoogleFonts.anuphan(
              color: AppTheme.onSurface(context),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'เลือกช่องทางที่สะดวกที่สุด ทีมงานพร้อมตอบทุกวัน 08:00–22:00',
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _ShortcutTile(
            icon: Icons.chat_bubble_rounded,
            color: const Color(0xFF06C755),
            title: 'LINE Official',
            subtitle: contact.line,
            onTap: () => _launch(context, Uri.parse(contact.lineUrl)),
            onLongPress: () => _copy(context, contact.line, 'คัดลอก LINE ID แล้ว'),
          ),
          const SizedBox(height: 10),
          _ShortcutTile(
            icon: Icons.phone_rounded,
            color: AppTheme.primaryColor,
            title: 'โทรหาเรา',
            subtitle: contact.phone,
            onTap: () => _launch(
              context,
              Uri(scheme: 'tel', path: contact.phone.replaceAll(' ', '')),
            ),
            onLongPress: () => _copy(context, contact.phone, 'คัดลอกเบอร์โทรแล้ว'),
          ),
          const SizedBox(height: 10),
          _ShortcutTile(
            icon: Icons.mail_outline_rounded,
            color: const Color(0xFFD97706),
            title: 'อีเมล',
            subtitle: contact.email,
            onTap: () => _launch(
              context,
              Uri(scheme: 'mailto', path: contact.email),
            ),
            onLongPress: () => _copy(context, contact.email, 'คัดลอกอีเมลแล้ว'),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเปิดช่องทางนี้ได้')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเปิดช่องทางนี้ได้')),
        );
      }
    }
  }

  Future<void> _copy(BuildContext context, String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ShortcutTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ShortcutTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.onSurface(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.mutedText(context),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppTheme.mutedText(context),
            ),
          ],
        ),
      ),
    );
  }
}
