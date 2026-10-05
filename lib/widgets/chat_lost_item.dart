import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';

// ของหาย / ลืมของในทริป — การ์ดในแชทและป้ายสถานะที่ใช้ร่วมกับหน้า "ของที่ลืมไว้"
//
// payload (lost_item) มาจาก LostItemService::present() — ในแชทเป็นส่วนสาธารณะ
// (ไม่มีชื่อ/เบอร์/ที่อยู่ของเจ้าของ) หา "ของฉัน" จาก claimed_by_id เอง

({String label, Color color, IconData icon}) lostItemBadge(
  BuildContext context,
  Map<String, dynamic> item,
  int? myUserId,
) {
  final mine =
      myUserId != null && int.tryParse('${item['claimed_by_id']}') == myUserId;
  return switch (item['status']) {
    'returned' => (
      label: mine ? 'ได้รับคืนแล้ว' : 'คืนเจ้าของแล้ว',
      color: AppTheme.primaryColor,
      icon: Icons.check_circle_rounded,
    ),
    'claimed' => (
      label: mine ? 'คุณแจ้งว่าเป็นของคุณ' : 'มีเจ้าของแจ้งแล้ว',
      color: AppTheme.accentColor,
      icon: Icons.person_pin_rounded,
    ),
    _ => (
      label: 'ยังไม่มีเจ้าของ',
      color: AppTheme.warningColor,
      icon: Icons.help_outline_rounded,
    ),
  };
}

/// รูปของ (ไม่มีรูป = ไอคอนกล่อง)
class LostItemPhoto extends StatelessWidget {
  final String? url;
  final double size;

  const LostItemPhoto({super.key, required this.url, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final resolved = ApiConfig.mediaUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        width: size,
        height: size,
        color: AppTheme.subtleSurface(context),
        child: resolved.isEmpty
            ? Icon(
                Icons.inventory_2_outlined,
                color: AppTheme.mutedText(context),
                size: size * 0.42,
              )
            : CachedNetworkImage(
                imageUrl: resolved,
                fit: BoxFit.cover,
                memCacheWidth: (size * 3).round(),
                errorWidget: (_, _, _) => Icon(
                  Icons.broken_image_outlined,
                  color: AppTheme.mutedText(context),
                ),
              ),
      ),
    );
  }
}

/// การ์ดในบับเบิลแชท — รูป + รายละเอียด + สถานะ + ปุ่มเปิดหน้าของหาย
class ChatLostItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int? myUserId;
  final VoidCallback onOpen;

  const ChatLostItemCard({
    super.key,
    required this.item,
    required this.myUserId,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final badge = lostItemBadge(context, item, myUserId);
    final open = item['status'] == 'open';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LostItemPhoto(url: item['photo_url']?.toString()),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📦 ใครลืมของไว้?',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['description']?.toString() ?? '',
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(badge.icon, size: 14, color: badge.color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          badge.label,
                          style: appFont(
                            fontSize: AppText.sizeCaption,
                            fontWeight: FontWeight.w800,
                            color: badge.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: open
              ? FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onOpen();
                  },
                  icon: const Icon(Icons.back_hand_rounded, size: 17),
                  label: Text(
                    'ของฉัน / ดูรายละเอียด',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                )
              : OutlinedButton(
                  onPressed: onOpen,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: AppTheme.border(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                  child: Text(
                    'ดูรายละเอียด',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
