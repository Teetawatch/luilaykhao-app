import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// ทางออกเมื่อ SOS ในแอปส่งไม่ผ่านเพราะไม่มีอินเทอร์เน็ต
///
/// แอปส่ง SOS ผ่าน API ล้วน ซึ่งต้องการ data — บนดอยจึงเท่ากับปุ่มที่กดแล้ว
/// ไม่เกิดอะไรขึ้น แต่ในจุดเดียวกันนั้นสัญญาณเสียงและ SMS มักยังพอมี เพราะวิ่ง
/// คนละช่องกันและใช้กำลังส่งต่ำกว่า แผ่นนี้จึงเปิดทางนั้นให้แทน
///
/// สองข้อจำกัดที่กำหนดรูปร่างของหน้าจอนี้
///   1. **ส่ง SMS เองโดยแอปไม่ได้** iOS ไม่อนุญาตให้แอปส่งข้อความแทนผู้ใช้เลย
///      และบน Android สิทธิ์ SEND_SMS แทบเป็นไปไม่ได้ที่จะผ่าน Play Store
///      สิ่งที่ทำได้คือ **เปิดแอปข้อความพร้อมข้อความที่พิมพ์ไว้ให้แล้ว** ผู้ใช้
///      กดส่งเอง — หน้าจอจึงต้องบอกตรง ๆ ว่ายังเหลืออีกหนึ่งปุ่มให้กด ไม่ใช่
///      ทำเหมือนส่งไปแล้ว
///   2. **เบอร์ทั้งหมดต้องมาจากแคช** ([TripDayPack]) ถ้าต้องโหลดตอนเปิดแผ่นนี้
///      ก็ไม่มีทางได้ เพราะสถานการณ์ที่เปิดมันคือสถานการณ์ที่โหลดอะไรไม่ได้
class SosFallbackSheet extends StatelessWidget {
  /// สตาฟ/คนขับ/ศูนย์ช่วยเหลือ — จาก `GET schedules/{id}/emergency-contacts`
  final List<Map<String, dynamic>> contacts;

  /// เบอร์ราชการของประเทศที่รอบนี้ไปอยู่ (ไทย = 191/1669/1155)
  final Map<String, String> emergencyNumbers;

  /// ข้อความที่จะเติมให้ในแอปข้อความ — พร้อมชื่อ พิกัด และสิ่งที่เกิดขึ้น
  final String smsBody;

  /// SOS ถูกเก็บเข้าคิวเรียบร้อยแล้วหรือไม่ — เปลี่ยนคำอธิบายด้านบนของแผ่น
  final bool queued;

  const SosFallbackSheet({
    super.key,
    required this.contacts,
    required this.emergencyNumbers,
    required this.smsBody,
    this.queued = true,
  });

  static const _sosRed = Color(0xFFE11D48);

  static Future<void> show(
    BuildContext context, {
    required List<Map<String, dynamic>> contacts,
    required Map<String, String> emergencyNumbers,
    required String smsBody,
    bool queued = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SosFallbackSheet(
        contacts: contacts,
        emergencyNumbers: emergencyNumbers,
        smsBody: smsBody,
        queued: queued,
      ),
    );
  }

  /// ข้อความที่ใส่ให้ในแอปข้อความ
  ///
  /// สั้นและเรียงตามลำดับที่คนอ่านบนหน้าจอล็อกต้องการ: ใคร → อยู่ไหน → เกิดอะไร
  /// พิกัดเป็นลิงก์แผนที่เพราะปลายทางคือคนที่ต้องขับรถ/เดินไปหา ไม่ใช่คนที่จะมา
  /// นั่งแปลงพิกัดเอง
  static String composeSms({
    required String travellerName,
    String? tripTitle,
    String? message,
    double? latitude,
    double? longitude,
    DateTime? occurredAt,
  }) {
    final parts = <String>['[SOS] $travellerName ขอความช่วยเหลือ'];

    if (tripTitle != null && tripTitle.trim().isNotEmpty) {
      parts.add('ทริป ${tripTitle.trim()}');
    }

    if (message != null && message.trim().isNotEmpty) {
      parts.add(message.trim());
    }

    if (latitude != null && longitude != null) {
      parts.add(
        'https://maps.google.com/?q='
        '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}',
      );
    } else {
      parts.add('(ระบุพิกัดไม่ได้)');
    }

    if (occurredAt != null) {
      final local = occurredAt.toLocal();
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      parts.add('เวลา $hh:$mm น.');
    }

    return parts.join(' ');
  }

  Future<void> _call(BuildContext context, String phone) async {
    HapticFeedback.heavyImpact();
    final uri = Uri.parse('tel:${_digits(phone)}');
    if (!await launchUrl(uri) && context.mounted) {
      _toast(context, 'เปิดแอปโทรศัพท์ไม่ได้');
    }
  }

  Future<void> _sms(BuildContext context, String phone) async {
    HapticFeedback.heavyImpact();
    // `?body=` เป็นพารามิเตอร์ที่ทั้ง iOS และ Android รับ แต่ต้อง encode เอง
    // ผ่าน Uri(...) ไม่ได้ เพราะบางเครื่องตีความ query ของ scheme sms: ต่างกัน
    final uri = Uri.parse(
      'sms:${_digits(phone)}?body=${Uri.encodeComponent(smsBody)}',
    );
    if (!await launchUrl(uri) && context.mounted) {
      _toast(context, 'เปิดแอปข้อความไม่ได้');
    }
  }

  String _digits(String phone) => phone.replaceAll(RegExp(r'[^0-9+]'), '');

  void _toast(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  const Icon(Icons.signal_cellular_off_rounded,
                      color: _sosRed, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ส่ง SOS ผ่านแอปไม่ได้',
                      style: appFont(
                        fontSize: AppText.sizeTitle,
                        fontWeight: FontWeight.w900,
                        color: _sosRed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                queued
                    ? 'ระบบเก็บสัญญาณของคุณไว้แล้ว และจะส่งให้อัตโนมัติทันทีที่'
                          'กลับมามีสัญญาณ (เปิดแอปค้างไว้) ระหว่างนี้โทรหรือส่ง'
                          'ข้อความได้เลย — สัญญาณโทรศัพท์มักยังใช้ได้ในที่ที่'
                          'อินเทอร์เน็ตใช้ไม่ได้'
                    : 'โทรหรือส่งข้อความได้เลย — สัญญาณโทรศัพท์มักยังใช้ได้ใน'
                          'ที่ที่อินเทอร์เน็ตใช้ไม่ได้',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  height: 1.55,
                  color: AppTheme.mutedText(context),
                ),
              ),
              const SizedBox(height: 20),

              if (contacts.isEmpty)
                const _NoContactsNote()
              else ...[
                const _Heading(text: 'ทีมงานของรอบนี้'),
                const SizedBox(height: 10),
                ...contacts.map(
                  (contact) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ContactRow(
                      label: '${contact['label'] ?? 'ติดต่อ'}',
                      name: '${contact['name'] ?? ''}',
                      phone: '${contact['phone'] ?? ''}',
                      onCall: () => _call(context, '${contact['phone']}'),
                      onSms: () => _sms(context, '${contact['phone']}'),
                    ),
                  ),
                ),
              ],

              if (emergencyNumbers.isNotEmpty) ...[
                const SizedBox(height: 12),
                const _Heading(text: 'เบอร์ฉุกเฉินราชการ'),
                const SizedBox(height: 10),
                ...emergencyNumbers.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ContactRow(
                      label: entry.key,
                      name: '',
                      phone: entry.value,
                      onCall: () => _call(context, entry.value),
                      // เบอร์สามหลักของราชการรับ SMS ไม่ได้ — ปุ่มที่กดแล้ว
                      // ไม่มีอะไรเกิดขึ้นแย่กว่าไม่มีปุ่ม โดยเฉพาะตอนฉุกเฉิน
                      onSms: null,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.subtleSurface(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: AppTheme.mutedText(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ปุ่ม "ข้อความ" จะเปิดแอปข้อความพร้อมพิมพ์ให้แล้ว '
                        'คุณต้องกดส่งเองอีกครั้ง',
                        style: appFont(
                          fontSize: AppText.sizeCaption,
                          height: 1.5,
                          color: AppTheme.mutedText(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: Text(
                    'ปิด',
                    style: appFont(
                      fontSize: AppText.sizeSubtitle,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: appFont(
        fontSize: AppText.sizeCaption,
        fontWeight: FontWeight.w700,
        color: AppTheme.mutedText(context),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final String label;
  final String name;
  final String phone;
  final VoidCallback onCall;
  final VoidCallback? onSms;

  const _ContactRow({
    required this.label,
    required this.name,
    required this.phone,
    required this.onCall,
    required this.onSms,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.trim().isEmpty ? label : '$name · $label',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  phone,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ],
            ),
          ),
          _ActionButton(
            icon: Icons.call_rounded,
            label: 'โทร',
            onTap: onCall,
            primary: true,
          ),
          if (onSms != null) ...[
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.sms_rounded,
              label: 'ข้อความ',
              onTap: onSms!,
              primary: false,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    const sosRed = Color(0xFFE11D48);

    return Material(
      color: primary ? sosRed : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: primary
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: sosRed.withValues(alpha: 0.45)),
                ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: primary ? Colors.white : sosRed),
              const SizedBox(height: 2),
              Text(
                label,
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w800,
                  color: primary ? Colors.white : sosRed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// เครื่องที่ไม่เคยเปิดแอปตอนมีสัญญาณเลยจึงไม่มีเบอร์ในแคช — เกิดได้จริงกับคนที่
/// ติดตั้งแอปแล้วเจอเหตุก่อนที่ TripDayPack จะได้ทำงาน
class _NoContactsNote extends StatelessWidget {
  const _NoContactsNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Text(
        'ยังไม่มีเบอร์ทีมงานเก็บไว้ในเครื่อง — เปิดหน้า "วันเดินทาง" ตอนมี'
        'สัญญาณสักครั้งเพื่อบันทึกไว้ใช้ตอนฉุกเฉิน',
        style: appFont(
          fontSize: AppText.sizeLabel,
          height: 1.5,
          color: AppTheme.mutedText(context),
        ),
      ),
    );
  }
}
