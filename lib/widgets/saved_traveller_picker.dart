import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Bottom sheet listing the travellers this customer has saved, so booking for
/// the same group again is a tap per person instead of eleven fields per person.
///
/// Returns the chosen traveller's payload, already shaped like the passenger
/// form expects. Returns null when nothing was picked.
class SavedTravellerPicker extends StatefulWidget {
  const SavedTravellerPicker({super.key});

  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SavedTravellerPicker(),
    );
  }

  @override
  State<SavedTravellerPicker> createState() => _SavedTravellerPickerState();
}

class _SavedTravellerPickerState extends State<SavedTravellerPicker> {
  List<Map<String, dynamic>> _travellers = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final raw = await context.read<AppProvider>().savedTravellers();
      if (!mounted) return;
      setState(() {
        _travellers = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _pick(Map<String, dynamic> traveller) async {
    HapticFeedback.selectionClick();
    final id = int.tryParse('${traveller['id'] ?? ''}');
    if (id != null) {
      // Fire-and-forget: ordering is a convenience, not worth blocking on.
      context.read<AppProvider>().markSavedTravellerUsed(id);
    }
    Navigator.of(context).pop(traveller);
  }

  Future<void> _delete(Map<String, dynamic> traveller) async {
    final id = int.tryParse('${traveller['id'] ?? ''}');
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ลบออกจากสมุด?'),
        content: Text('${traveller['name'] ?? ''} จะถูกลบออกจากสมุดผู้ร่วมเดินทาง'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<AppProvider>().deleteSavedTraveller(id);
      if (!mounted) return;
      setState(() => _travellers.removeWhere((t) => t['id'] == traveller['id']));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ลบไม่สำเร็จ ลองใหม่อีกครั้ง')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'สมุดผู้ร่วมเดินทาง',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.onSurface(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'แตะเพื่อกรอกข้อมูลคนนี้ลงในฟอร์ม',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'ปิด',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(child: _body()),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_failed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'โหลดสมุดไม่สำเร็จ',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: _load, child: const Text('ลองอีกครั้ง')),
          ],
        ),
      );
    }

    if (_travellers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 40,
              color: AppTheme.mutedText(context),
            ),
            const SizedBox(height: 12),
            Text(
              'ยังไม่มีใครในสมุด',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'หลังจองเสร็จ กด "เก็บผู้ร่วมเดินทางไว้ใช้ครั้งหน้า" '
              'แล้วครั้งต่อไปจะกรอกให้อัตโนมัติ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: _travellers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final traveller = _travellers[index];
        final label = '${traveller['label'] ?? ''}'.trim();
        final nickname = '${traveller['nickname'] ?? ''}'.trim();
        final phone = '${traveller['phone'] ?? ''}'.trim();

        final subtitleParts = [
          if (nickname.isNotEmpty) '($nickname)',
          if (phone.isNotEmpty) phone,
        ];

        return Material(
          color: AppTheme.subtleSurface(context),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _pick(traveller),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${traveller['name'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.onSurface(context),
                                ),
                              ),
                            ),
                            if (label.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (subtitleParts.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitleParts.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'ลบ ${traveller['name'] ?? ''} ออกจากสมุด',
                    onPressed: () => _delete(traveller),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
