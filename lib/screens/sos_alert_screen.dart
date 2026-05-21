import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sos_alert.dart';
import '../providers/app_provider.dart';
import '../services/sos_alarm_service.dart';
import '../theme/app_theme.dart';

/// Full-screen view shown to staff / fellow travelers when they open an
/// incoming `sos_alert` notification.
class SosAlertScreen extends StatefulWidget {
  final SosAlert alert;

  const SosAlertScreen({super.key, required this.alert});

  @override
  State<SosAlertScreen> createState() => _SosAlertScreenState();
}

class _SosAlertScreenState extends State<SosAlertScreen> {
  bool _resolving = false;
  bool _resolved = false;

  static const _sosRed = Color(0xFFE11D48);

  @override
  void dispose() {
    SosAlarmService.instance.stop();
    super.dispose();
  }

  Future<void> _call() async {
    final phone = widget.alert.contactPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      _snack('ไม่สามารถโทรออกได้');
    }
  }

  Future<void> _openMap() async {
    final alert = widget.alert;
    if (!alert.hasLocation) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${alert.latitude},${alert.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _snack('ไม่สามารถเปิดแผนที่ได้');
    }
  }

  Future<void> _resolve() async {
    if (widget.alert.id == 0) {
      _snack('ไม่พบรหัสเคส SOS');
      return;
    }
    setState(() => _resolving = true);
    try {
      await context.read<AppProvider>().resolveSos(widget.alert.id);
      if (!mounted) return;
      setState(() => _resolved = true);
      _snack('ปิดเคส SOS แล้ว');
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _openPhoto(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              child: Center(child: Image.network(url)),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(ctx).top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final hasPhone = (alert.contactPhone ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: _sosRed,
        foregroundColor: Colors.white,
        title: Text(
          'สัญญาณ SOS',
          style: GoogleFonts.anuphan(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _sosRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sos_rounded, color: _sosRed, size: 48),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${alert.userName.isEmpty ? 'เพื่อนร่วมทริป' : alert.userName} ขอความช่วยเหลือ',
            textAlign: TextAlign.center,
            style: GoogleFonts.anuphan(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'มีเพื่อนร่วมทริปของคุณกำลังต้องการความช่วยเหลือ',
            textAlign: TextAlign.center,
            style: GoogleFonts.anuphan(
              fontSize: 13,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 24),
          if (alert.message != null) ...[
            _InfoCard(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'ข้อความ',
              child: Text(
                alert.message!,
                style: GoogleFonts.anuphan(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (hasPhone) ...[
            _InfoCard(
              icon: Icons.phone_rounded,
              label: 'เบอร์ติดต่อ',
              child: Text(
                alert.contactPhone!,
                style: GoogleFonts.anuphan(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (alert.hasLocation) ...[
            _InfoCard(
              icon: Icons.location_on_outlined,
              label: 'ตำแหน่งล่าสุด',
              child: Text(
                '${alert.latitude!.toStringAsFixed(5)}, ${alert.longitude!.toStringAsFixed(5)}',
                style: GoogleFonts.anuphan(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if ((alert.photoUrl ?? '').isNotEmpty) ...[
            _InfoCard(
              icon: Icons.photo_outlined,
              label: 'รูปสถานที่',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GestureDetector(
                  onTap: () => _openPhoto(alert.photoUrl!),
                  child: Image.network(
                    alert.photoUrl!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, _, _) => SizedBox(
                      height: 200,
                      child: Center(
                        child: Text(
                          'โหลดรูปไม่สำเร็จ',
                          style: GoogleFonts.anuphan(
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          if (hasPhone)
            _ActionButton(
              icon: Icons.call_rounded,
              label: 'โทรหา ${alert.userName.isEmpty ? 'ผู้แจ้ง' : alert.userName}',
              color: _sosRed,
              onPressed: _call,
            ),
          if (hasPhone && alert.hasLocation) const SizedBox(height: 12),
          if (alert.hasLocation)
            _ActionButton(
              icon: Icons.map_rounded,
              label: 'เปิดแผนที่ตำแหน่ง',
              color: AppTheme.primaryColor,
              filled: false,
              onPressed: _openMap,
            ),
          const SizedBox(height: 24),
          if (_resolved)
            Center(
              child: Text(
                'เคสนี้ถูกปิดแล้ว',
                style: GoogleFonts.anuphan(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            )
          else
            _ActionButton(
              icon: Icons.check_circle_outline_rounded,
              label: _resolving ? 'กำลังปิดเคส...' : 'ทำเครื่องหมายว่าช่วยเหลือแล้ว',
              color: AppTheme.primaryColor,
              filled: false,
              onPressed: _resolving ? null : _resolve,
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context).withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.mutedText(context)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.anuphan(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.filled = true,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: filled
          ? FilledButton.icon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(icon),
              label: Text(
                label,
                style: GoogleFonts.anuphan(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(icon),
              label: Text(
                label,
                style: GoogleFonts.anuphan(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );
  }
}
