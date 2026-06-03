import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/notification_navigator.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';

/// หน้าจอ "เข้าร่วมการจองของเพื่อน" — เพื่อนวางลิงก์/รหัสคำเชิญที่เจ้าของส่งมา
/// แล้วกดเข้าร่วม การผูกอ้างจากบัญชีที่ล็อกอินอยู่ (เบอร์/อีเมล/LINE/FB/Google
/// ก็ใช้ได้ทั้งหมด) จึงไม่ต้องสนใจว่าเพื่อนสมัครด้วยวิธีใด
class JoinBookingScreen extends StatefulWidget {
  final String? initialToken;

  const JoinBookingScreen({super.key, this.initialToken});

  @override
  State<JoinBookingScreen> createState() => _JoinBookingScreenState();
}

class _JoinBookingScreenState extends State<JoinBookingScreen> {
  late final TextEditingController _controller;
  Map<String, dynamic>? _preview;
  bool _loading = false;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialToken ?? '');
    if ((widget.initialToken ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookup());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// ดึง token จากข้อความที่วาง — รับได้ทั้งลิงก์เต็มที่ลงท้ายด้วย `/join/TOKEN`,
  /// deep link `luilaykhao://join/TOKEN` หรือรหัสล้วน
  String _extractToken(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final segs = uri.pathSegments;
      final idx = segs.indexOf('join');
      if (idx >= 0 && idx + 1 < segs.length) {
        return segs[idx + 1].trim();
      }
      if (uri.host == 'join' && segs.isNotEmpty) {
        return segs.first.trim();
      }
      if (value.contains('/')) {
        return segs.last.trim();
      }
    }
    return value;
  }

  Future<void> _lookup() async {
    final token = _extractToken(_controller.text);
    if (token.isEmpty) {
      setState(() => _error = 'กรุณาวางลิงก์หรือรหัสคำเชิญ');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });
    try {
      final data = await context.read<AppProvider>().previewBookingInvite(token);
      if (!mounted) return;
      setState(() => _preview = {...data, 'token': token});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    final token = _preview?['token']?.toString() ?? '';
    if (token.isEmpty) return;
    setState(() => _joining = true);
    try {
      final data = await context.read<AppProvider>().acceptBookingInvite(token);
      if (!mounted) return;
      final title = data['trip_title']?.toString() ?? 'ทริป';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เข้าร่วม "$title" สำเร็จแล้ว')),
      );
      Navigator.of(context).pop(true);
      NotificationNavigator.goToBookings();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _error = _cleanError(e);
      });
    }
  }

  String _cleanError(Object e) =>
      e.toString().replaceFirst('Exception: ', '').trim();

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final alreadyMember = preview?['already_member'] == true;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: const Text('เข้าร่วมการจอง'),
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'มีเพื่อนเชิญเข้าทริปไหม?',
              style: GoogleFonts.anuphan(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'วางลิงก์หรือรหัสคำเชิญที่เจ้าของการจองส่งมา เพื่อเข้ากลุ่มแชท '
              'และติดตามสถานะรถได้จากบัญชีของคุณเอง',
              style: GoogleFonts.anuphan(
                fontSize: 13.5,
                color: AppTheme.mutedText(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 2,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _lookup(),
              decoration: InputDecoration(
                hintText: 'วางลิงก์หรือรหัสคำเชิญที่นี่',
                filled: true,
                fillColor: AppTheme.subtleSurface(context),
                suffixIcon: IconButton(
                  tooltip: 'วางจากคลิปบอร์ด',
                  icon: const Icon(Icons.content_paste_rounded),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    final text = data?.text?.trim() ?? '';
                    if (text.isNotEmpty) {
                      _controller.text = text;
                      _lookup();
                    }
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loading ? null : _lookup,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
              label: const Text('ตรวจสอบคำเชิญ'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _InfoBanner(
                color: Colors.red,
                icon: Icons.error_outline_rounded,
                text: _error!,
              ),
            ],
            if (preview != null) ...[
              const SizedBox(height: 20),
              _InvitePreviewCard(preview: preview),
              const SizedBox(height: 20),
              if (alreadyMember)
                const _InfoBanner(
                  color: Colors.green,
                  icon: Icons.check_circle_outline_rounded,
                  text: 'คุณเข้าร่วมการจองนี้อยู่แล้ว ดูได้ในการจองของฉัน',
                )
              else
                PrimaryCTAButton(
                  label: _joining ? 'กำลังเข้าร่วม...' : 'เข้าร่วมการจองนี้',
                  icon: Icons.group_add_rounded,
                  onPressed: _joining ? null : _join,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InvitePreviewCard extends StatelessWidget {
  final Map<String, dynamic> preview;

  const _InvitePreviewCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    final invitedBy = preview['invited_by']?.toString() ?? '';
    final tripTitle = preview['trip_title']?.toString() ?? 'ทริป';
    final date = preview['departure_date']?.toString() ?? '';
    final ref = preview['booking_ref']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (invitedBy.isNotEmpty)
            Text(
              '$invitedBy เชิญคุณเข้าร่วม',
              style: GoogleFonts.anuphan(
                fontSize: 13,
                color: AppTheme.mutedText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            tripTitle,
            style: GoogleFonts.anuphan(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          const SizedBox(height: 10),
          if (date.isNotEmpty)
            _PreviewRow(icon: Icons.event_rounded, text: 'เดินทาง $date'),
          if (ref.isNotEmpty)
            _PreviewRow(icon: Icons.confirmation_number_rounded, text: ref),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PreviewRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.anuphan(
              fontSize: 13.5,
              color: AppTheme.onSurface(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _InfoBanner({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.anuphan(
                fontSize: 13,
                color: AppTheme.onSurface(context),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
