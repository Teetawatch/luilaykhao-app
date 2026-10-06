import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'gift_voucher_card.dart';

/// บัตรที่เลือกใช้ตอนจอง — สิ่งที่ขั้นตอนการจองต้องรู้มีแค่นี้
class SelectedGiftVoucher {
  final String code;
  final num balance;

  const SelectedGiftVoucher({required this.code, required this.balance});

  String get displayCode => formatVoucherCode(code);
}

/// เลือกบัตรของขวัญตอนจอง: บัตรในบัญชี (แตะเลือก) หรือพิมพ์รหัสบัตรที่ได้มา
///
/// คืน null เมื่อปิดโดยไม่เลือก — ยอดจริงที่หักคิดใหม่ที่หลังบ้านตอนสร้างการจอง
Future<SelectedGiftVoucher?> showGiftVoucherPicker(BuildContext context) {
  return showModalBottomSheet<SelectedGiftVoucher>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTheme.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusXl),
      ),
    ),
    builder: (_) => const _GiftVoucherPickerSheet(),
  );
}

class _GiftVoucherPickerSheet extends StatefulWidget {
  const _GiftVoucherPickerSheet();

  @override
  State<_GiftVoucherPickerSheet> createState() =>
      _GiftVoucherPickerSheetState();
}

class _GiftVoucherPickerSheetState extends State<_GiftVoucherPickerSheet> {
  final _code = TextEditingController();
  bool _loading = true;
  bool _checking = false;
  String? _error;
  List<Map<String, dynamic>> _usable = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AppProvider>().giftVouchers();
      final wallet = data['wallet'];
      if (!mounted) return;
      setState(() {
        _usable = wallet is List
            ? wallet
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .where(
                    (v) =>
                        v['status'] == 'active' &&
                        (num.tryParse('${v['balance']}') ?? 0) > 0,
                  )
                  .toList()
            : const [];
        _loading = false;
      });
    } catch (_) {
      // เลือกจากบัญชีไม่ได้ก็ยังพิมพ์รหัสเองได้ — ไม่ต้องขวาง
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _check() async {
    final code = _code.text.trim();
    if (code.isEmpty || _checking) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final v = await context.read<AppProvider>().lookupGiftVoucher(code);
      if (!mounted) return;
      if (v['usable'] != true) {
        setState(
          () => _error = v['owned_by_other'] == true
              ? 'บัตรนี้เป็นของบัญชีอื่น'
              : 'บัตรนี้${giftVoucherStatusLabel('${v['status']}')} ใช้ไม่ได้',
        );
        return;
      }
      Navigator.pop(
        context,
        SelectedGiftVoucher(
          code: '${v['code']}',
          balance: num.tryParse('${v['balance']}') ?? 0,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.message.isNotEmpty
              ? e.message
              : 'ไม่พบบัตรของขวัญนี้',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'ตรวจสอบรหัสไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(
                'ใช้บัตรของขวัญ',
                style: appFont(
                  fontSize: AppText.sizeTitle,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ยอดจะถูกหักจากบัตรตอนยืนยันการจอง เหลือเท่าไรเก็บไว้ใช้ครั้งหน้าได้',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  height: 1.5,
                  color: AppTheme.mutedText(context),
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else
                for (final v in _usable) ...[
                  GiftVoucherCard.fromJson(
                    v,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(
                        context,
                        SelectedGiftVoucher(
                          code: '${v['code']}',
                          balance: num.tryParse('${v['balance']}') ?? 0,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              if (!_loading && _usable.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'ยังไม่มีบัตรที่ใช้ได้ในบัญชี ถ้ามีรหัสบัตรกรอกด้านล่างได้เลย',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _check(),
                      decoration: const InputDecoration(
                        hintText: 'รหัสบัตร GV-XXXXX-XXXXX',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _checking ? null : _check,
                    child: _checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('ใช้รหัสนี้'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.errorColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
