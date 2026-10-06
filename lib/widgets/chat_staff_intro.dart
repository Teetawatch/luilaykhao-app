import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';

// การ์ด "แนะนำทีมงาน" — เด้งเข้าห้องแชทของรอบตอนแอดมินมอบหมายสตาฟ
//
// payload (staff_intro) มาจาก StaffIntroService::present() ฝั่งเซิร์ฟเวอร์ สด ๆ
// ทุกครั้งที่โหลดข้อความ สตาฟแก้โปรไฟล์เมื่อไหร่การ์ดก็เปลี่ยนตาม ส่วน phone
// เป็น null เมื่อสตาฟถูกปลดจากรอบแล้ว (จบทริป) หรือไม่ได้กรอกเบอร์ไว้
//
// ใช้ซ้ำในหน้า "โปรไฟล์ทีมงาน" เป็นตัวอย่างว่าลูกทริปจะเห็นอะไร

class StaffIntroCard extends StatelessWidget {
  final Map<String, dynamic> intro;

  /// บัญชีที่เปิดดูอยู่ — การ์ดของตัวเองไม่ต้องมีปุ่มโทร/ทักทายหาตัวเอง
  final int? myUserId;

  /// เติมคำทักทายลงช่องพิมพ์ (ในห้องแชท) — null = ไม่โชว์ปุ่ม
  final ValueChanged<String>? onGreet;

  /// มุมขวาบน เช่น เวลาโพสต์
  final String? trailing;

  const StaffIntroCard({
    super.key,
    required this.intro,
    this.myUserId,
    this.onGreet,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final name = intro['name']?.toString() ?? 'ทีมงาน';
    final phone = intro['phone']?.toString() ?? '';
    final bio = intro['bio']?.toString() ?? '';
    final trails = _strings(intro['trails']);
    final skills = _strings(intro['skills']);
    final rounds = int.tryParse('${intro['rounds_count']}') ?? 0;
    final thisTrip = int.tryParse('${intro['this_trip_rounds']}') ?? 0;
    final rating = double.tryParse('${intro['rating_avg'] ?? ''}');
    final ratingCount = int.tryParse('${intro['rating_count']}') ?? 0;
    final isMe =
        myUserId != null && int.tryParse('${intro['user_id']}') == myUserId;

    final stats = <({IconData icon, String label})>[
      if (rounds > 0)
        (icon: Icons.hiking_rounded, label: 'ดูแลมาแล้ว $rounds รอบ'),
      if (thisTrip > 0)
        (icon: Icons.verified_rounded, label: 'ทริปนี้ $thisTrip รอบ'),
      if (rating != null)
        (
          icon: Icons.star_rounded,
          label: '${rating.toStringAsFixed(1)} ($ratingCount รีวิว)',
        ),
      if (rounds == 0) (icon: Icons.spa_rounded, label: 'ทีมงานไฟแรง'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '🎽 แนะนำทีมงานประจำรอบ',
                style: appFont(
                  fontSize: AppText.sizeMicro,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              if (trailing != null && trailing!.isNotEmpty)
                Text(
                  trailing!,
                  style: appFont(
                    fontSize: AppText.sizeMicro,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedText(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StaffPhoto(url: intro['avatar_url']?.toString(), name: name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeSubtitle,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        for (final s in stats)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                s.icon,
                                size: 13,
                                color: s.icon == Icons.star_rounded
                                    ? AppTheme.warningColor
                                    : AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                s.label,
                                style: appFont(
                                  fontSize: AppText.sizeCaption,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.mutedText(context),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              bio,
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w500,
                color: AppTheme.onSurface(context).withValues(alpha: 0.88),
                height: 1.5,
              ),
            ),
          ],
          if (trails.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ChipSection(
              label: 'ป่าที่เคยเดิน',
              icon: Icons.terrain_rounded,
              items: trails,
            ),
          ],
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ChipSection(
              label: 'ถนัด',
              icon: Icons.medical_services_outlined,
              items: skills,
            ),
          ],
          if (!isMe && (phone.isNotEmpty || onGreet != null)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onGreet != null)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onGreet!('สวัสดี$name 👋 ');
                      },
                      icon: const Icon(Icons.waving_hand_rounded, size: 17),
                      label: Text(
                        'ทักทาย',
                        style: appFont(
                          fontSize: AppText.sizeLabel,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (onGreet != null && phone.isNotEmpty)
                  const SizedBox(width: 8),
                if (phone.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _call(phone),
                      icon: const Icon(
                        Icons.call_rounded,
                        size: 17,
                        color: AppTheme.primaryColor,
                      ),
                      label: Text(
                        phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          fontSize: AppText.sizeLabel,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: BorderSide(color: AppTheme.border(context)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  static Future<void> _call(String phone) async {
    HapticFeedback.selectionClick();
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');
    try {
      await launchUrl(uri);
    } catch (_) {
      // เครื่องที่โทรออกไม่ได้ (แท็บเล็ต/อีมูเลเตอร์) — ปล่อยผ่านเงียบ ๆ
    }
  }
}

class _ChipSection extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> items;

  const _ChipSection({
    required this.label,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w700,
            color: AppTheme.mutedText(context),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final item in items)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(
                    alpha: AppTheme.isDark(context) ? 0.16 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 13, color: AppTheme.primaryColor),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StaffPhoto extends StatelessWidget {
  final String? url;
  final String name;

  const _StaffPhoto({required this.url, required this.name});

  static const _size = 52.0;

  @override
  Widget build(BuildContext context) {
    final resolved = ApiConfig.mediaUrl(url);
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;
    final fallback = Container(
      alignment: Alignment.center,
      color: AppTheme.primaryColor.withValues(alpha: 0.12),
      child: Text(
        initial,
        style: appFont(
          fontSize: AppText.sizeTitle,
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryColor,
        ),
      ),
    );

    return ClipOval(
      child: SizedBox(
        width: _size,
        height: _size,
        child: resolved.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: resolved,
                fit: BoxFit.cover,
                memCacheWidth: (_size * 3).round(),
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
