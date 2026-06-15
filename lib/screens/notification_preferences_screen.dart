import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notification_preferences.dart';
import '../theme/app_theme.dart';

class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key});

  static const _meta = <String, ({String label, String subtitle, IconData icon})>{
    'booking': (
      label: 'การจอง',
      subtitle: 'แจ้งเมื่อจองสำเร็จหรือถูกยกเลิก',
      icon: Icons.confirmation_number_outlined,
    ),
    'payment': (
      label: 'การชำระเงิน',
      subtitle: 'แจ้งเมื่อชำระเงินสำเร็จหรือมีปัญหา',
      icon: Icons.payments_outlined,
    ),
    'promotion': (
      label: 'โปรโมชั่นและข่าวสาร',
      subtitle: 'ดีลใหม่และส่วนลดจากทีมงาน',
      icon: Icons.local_offer_outlined,
    ),
    'reminder': (
      label: 'เตือนก่อนเดินทาง',
      subtitle: 'แจ้งเตือน 24 ชม. และ 1 ชม. ก่อนทริป',
      icon: Icons.alarm,
    ),
    'tracking': (
      label: 'ติดตามรถ',
      subtitle: 'อัปเดตตำแหน่งและเวลาถึงจุดรับ',
      icon: Icons.directions_bus_outlined,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<NotificationPreferences>();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.onSurface(context)),
        title: Text(
          'การแจ้งเตือน',
          style: appFont(
            color: AppTheme.onSurface(context),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          for (final entry in _meta.entries)
            _PreferenceTile(
              icon: entry.value.icon,
              label: entry.value.label,
              subtitle: entry.value.subtitle,
              enabled: prefs.isEnabled(entry.key),
              onChanged: (value) =>
                  context.read<NotificationPreferences>().setEnabled(
                    entry.key,
                    value,
                  ),
            ),
        ],
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _PreferenceTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 22),
        ),
        title: Text(
          label,
          style: appFont(
            color: AppTheme.onSurface(context),
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: appFont(
            color: AppTheme.mutedText(context),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        value: enabled,
        activeThumbColor: AppTheme.primaryColor,
        onChanged: onChanged,
      ),
    );
  }
}
