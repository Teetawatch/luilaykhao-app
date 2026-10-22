import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/partner_ref_store.dart';
import '../theme/app_theme.dart';
import 'travel_widgets.dart';

/// รหัสผู้แนะนำ (พาร์ทเนอร์ช่วยขาย) ในขั้นสรุปของการจอง
///
/// ไม่มีส่วนลด — มีไว้ให้คอมไปถึงคนที่แนะนำ โค้ดที่จำไว้จากลิงก์ขึ้นเป็น
/// "แนะนำโดย …" เลย ไม่มีก็พับเป็นลิงก์เล็ก ๆ ไม่ให้แย่งที่ช่องโค้ดส่วนลด
class PartnerCodeTile extends StatefulWidget {
  final ValueChanged<PartnerRef?> onChanged;

  const PartnerCodeTile({super.key, required this.onChanged});

  @override
  State<PartnerCodeTile> createState() => _PartnerCodeTileState();
}

class _PartnerCodeTileState extends State<PartnerCodeTile> {
  final _input = TextEditingController();
  String? _displayName;
  bool _open = false;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _lookup(String code) async {
    final app = context.read<AppProvider>();
    final res = await app.api.get('partners/check', query: {'code': code});
    final data = asMap(app.api.data(res));
    return data['valid'] == true ? data : null;
  }

  Future<void> _restore() async {
    final stored = await PartnerRefStore.read();
    if (stored == null || !mounted) return;
    // ส่งไปกับการจองก่อนเสมอ แม้เช็คชื่อไม่ทัน (เน็ตหลุด) — เซิร์ฟเวอร์ตัดสินเอง
    widget.onChanged(stored);
    try {
      final found = await _lookup(stored.code);
      if (!mounted) return;
      if (found == null) {
        // โค้ดที่หยุดใช้ไปแล้ว ไม่ต้องจำต่อ
        await PartnerRefStore.forget();
        widget.onChanged(null);
        return;
      }
      setState(() => _displayName = textOf(found['display_name']));
    } catch (_) {}
  }

  Future<void> _check() async {
    final code = PartnerRefStore.normalize(_input.text);
    if (code.isEmpty || _checking) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final found = await _lookup(code);
      if (!mounted) return;
      if (found == null) {
        setState(() => _error = 'ไม่พบรหัสนี้ ลองตรวจตัวสะกดอีกครั้ง');
        return;
      }
      final ref = PartnerRef(textOf(found['code'], code), 'code');
      await PartnerRefStore.remember(ref.code, source: 'code');
      HapticFeedback.selectionClick();
      widget.onChanged(ref);
      if (mounted) setState(() => _displayName = textOf(found['display_name']));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'ตรวจสอบรหัสไม่สำเร็จ ลองใหม่อีกครั้ง');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _remove() async {
    await PartnerRefStore.forget();
    widget.onChanged(null);
    if (!mounted) return;
    setState(() {
      _displayName = null;
      _input.clear();
      _open = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);

    if (_displayName != null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
        child: Row(
          children: [
            const Icon(
              Icons.handshake_outlined,
              size: 20,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'แนะนำโดย $_displayName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ),
            TextButton(
              onPressed: _remove,
              child: Text(
                'เอาออก',
                style: appFont(fontSize: AppText.sizeLabel, color: muted),
              ),
            ),
          ],
        ),
      );
    }

    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _open = true),
          icon: Icon(Icons.handshake_outlined, size: 18, color: muted),
          label: Text(
            'มีรหัสผู้แนะนำ/พาร์ทเนอร์?',
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                textCapitalization: TextCapitalization.characters,
                maxLength: 20,
                onSubmitted: (_) => _check(),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'รหัสผู้แนะนำ',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _checking ? null : _check,
              child: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('ตรวจสอบ'),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: appFont(
              fontSize: AppText.sizeCaption,
              color: AppTheme.errorColor,
            ),
          ),
        ],
      ],
    );
  }
}
