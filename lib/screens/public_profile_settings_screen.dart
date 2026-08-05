import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_view.dart';

/// โปรไฟล์นักเดินสาธารณะ — เปิด/ปิด และแชร์ลิงก์ /u/{handle}
///
/// ค่าเริ่มต้นคือ "ปิด" และหน้านี้พูดชัดว่าเปิดแล้วใครเห็นอะไร: สถิติการเดินทาง
/// กับตราสะสม ไม่ใช่รายการจองหรือข้อมูลติดต่อ คนที่ยังไม่อยากให้ใครเห็นก็ไม่ต้อง
/// ทำอะไรเลย
class PublicProfileSettingsScreen extends StatefulWidget {
  const PublicProfileSettingsScreen({super.key});

  @override
  State<PublicProfileSettingsScreen> createState() =>
      _PublicProfileSettingsScreenState();
}

class _PublicProfileSettingsScreenState
    extends State<PublicProfileSettingsScreen> {
  final _bioController = TextEditingController();

  Map<String, dynamic>? _settings;
  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final settings = await context.read<AppProvider>().publicProfileSettings();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _enabled = settings['enabled'] == true;
        _bioController.text = '${settings['bio'] ?? ''}';
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await context.read<AppProvider>().updatePublicProfile(
        enabled: _enabled,
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _settings = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกการตั้งค่าโปรไฟล์สาธารณะแล้ว')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final url = '${settings?['url'] ?? ''}';

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'โปรไฟล์สาธารณะ',
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : settings == null
          ? EmptyStateView(
              icon: Icons.wifi_off_rounded,
              title: 'โหลดการตั้งค่าไม่สำเร็จ',
              body: _error,
              actionLabel: 'ลองใหม่',
              onAction: _load,
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'ให้คนอื่นดูเส้นทางที่คุณเคยไป',
                  style: appFont(
                    fontSize: AppText.sizeH2,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'เปิดแล้วจะมีหน้าโปรไฟล์สาธารณะของคุณ แสดงสถิติการเดินทาง '
                  'ตราสะสม และทริปที่เดินจบแล้ว — ไม่แสดงการจอง เบอร์โทร '
                  'หรืออีเมลของคุณ ปิดเมื่อไหร่ลิงก์ก็ปิดตามทันที',
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedText(context),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.subtleSurface(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: SwitchListTile.adaptive(
                    value: _enabled,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _enabled = value);
                    },
                    title: Text(
                      'เปิดโปรไฟล์สาธารณะ',
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    activeThumbColor: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bioController,
                  maxLength: 160,
                  maxLines: 3,
                  minLines: 2,
                  decoration: InputDecoration(
                    labelText: 'แนะนำตัวสั้น ๆ',
                    hintText: 'เช่น ชอบเดินป่าหน้าหนาว กำลังไล่เก็บยอดดอยภาคเหนือ',
                    filled: true,
                    fillColor: AppTheme.subtleSurface(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    _saving ? 'กำลังบันทึก...' : 'บันทึกการตั้งค่า',
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_enabled && url.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'ลิงก์โปรไฟล์ของคุณ',
                    style: appFont(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.subtleSurface(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Text(
                      url,
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: url));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('คัดลอกลิงก์แล้ว')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('คัดลอก'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => SharePlus.instance.share(
                            ShareParams(text: url),
                          ),
                          icon: const Icon(Icons.ios_share_rounded, size: 18),
                          label: const Text('แชร์'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final uri = Uri.tryParse(url);
                            if (uri != null) {
                              launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('เปิด'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}
