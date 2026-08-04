import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'staff_check_in_screen.dart' show asMap, asList, textOf;

/// ใบแจกอุปกรณ์เช่าของรอบเดินทาง
///
/// สตาฟใช้สองจังหวะ: ก่อนออกเดินทาง (แจกให้ครบ) และตอนจบทริป (ไล่รับคืน)
/// ด้านบนเป็นยอดรวมต่อชิ้นของทั้งรอบ เพื่อเช็คว่าต้องขนของไปเท่าไร ด้านล่าง
/// เป็นรายการจองที่ติ๊กได้ทีละชิ้น
class StaffRentalsScreen extends StatefulWidget {
  final int scheduleId;
  final String title;

  const StaffRentalsScreen({
    super.key,
    required this.scheduleId,
    required this.title,
  });

  @override
  State<StaffRentalsScreen> createState() => _StaffRentalsScreenState();
}

class _StaffRentalsScreenState extends State<StaffRentalsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  /// คีย์ "ref|ชื่อของ" ที่กำลังบันทึกอยู่ — กันกดรัวและโชว์สปินเนอร์เฉพาะชิ้นนั้น
  final Set<String> _busy = {};

  /// ซ่อนรายการที่แจกครบแล้ว — ตอนแจกจริงหน้างานอยากเห็นแต่คนที่ยังไม่ได้ของ
  bool _onlyPending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppProvider>().loadStaffRentals(
        widget.scheduleId,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _mark(
    String bookingRef,
    String itemName,
    String action,
    bool done,
  ) async {
    final key = '$bookingRef|$itemName|$action';
    if (_busy.contains(key)) return;

    HapticFeedback.selectionClick();
    setState(() => _busy.add(key));
    try {
      final data = await context.read<AppProvider>().markStaffRental(
        widget.scheduleId,
        bookingRef: bookingRef,
        itemName: itemName,
        action: action,
        done: done,
      );
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        // งานสตาฟชิดซ้ายทุกหน้า (ธีมรวมตั้ง centerTitle: true ไว้)
        centerTitle: false,
        title: Text(
          'อุปกรณ์ที่ต้องแจก',
          style: appFont(fontSize: AppText.sizeTitle, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'โหลดใหม่',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.error_outline_rounded,
            size: 44,
            color: AppTheme.mutedText(context),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
              ),
            ),
          ),
        ],
      );
    }

    final summary = asMap(_data?['summary']);
    final items = asList(_data?['items']).map(asMap).toList();
    var bookings = asList(_data?['bookings']).map(asMap).toList();

    if (bookings.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.backpack_outlined,
            size: 48,
            color: AppTheme.mutedText(context),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'รอบนี้ยังไม่มีใครเช่าอุปกรณ์',
              style: appFont(
                fontSize: AppText.sizeSubtitle,
                fontWeight: FontWeight.w700,
                color: AppTheme.mutedText(context),
              ),
            ),
          ),
        ],
      );
    }

    if (_onlyPending) {
      bookings = bookings.where((b) => b['all_handed_out'] != true).toList();
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        _RentalSummaryCard(summary: summary, items: items),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              'รายการจอง',
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w700,
                color: AppTheme.mutedText(context),
              ),
            ),
            const Spacer(),
            FilterChip(
              selected: _onlyPending,
              onSelected: (v) => setState(() => _onlyPending = v),
              label: Text(
                'เฉพาะที่ยังไม่แจก',
                style: appFont(fontSize: AppText.sizeCaption, fontWeight: FontWeight.w700),
              ),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (bookings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'แจกครบทุกคนแล้ว 🎉',
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        for (final booking in bookings) ...[
          _RentalBookingCard(
            booking: booking,
            busy: _busy,
            onMark: _mark,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// ยอดรวมของทั้งรอบ — ต้องขนอะไรไปกี่ชิ้น และแจก/รับคืนไปแล้วเท่าไร
class _RentalSummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> items;

  const _RentalSummaryCard({required this.summary, required this.items});

  int _int(dynamic value) => int.tryParse(textOf(value, '0')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final total = _int(summary['total_pieces']);
    final handed = _int(summary['handed_out_pieces']);
    final returned = _int(summary['returned_pieces']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.backpack_rounded,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'ต้องเตรียมทั้งหมด $total ชิ้น',
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'แจกแล้ว $handed / $total · รับคืนแล้ว $returned / $total',
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RentalTotalRow(
                name: textOf(item['name']),
                quantity: _int(item['quantity']),
                handedOut: _int(item['handed_out']),
                returned: _int(item['returned']),
              ),
            ),
        ],
      ),
    );
  }
}

class _RentalTotalRow extends StatelessWidget {
  final String name;
  final int quantity;
  final int handedOut;
  final int returned;

  const _RentalTotalRow({
    required this.name,
    required this.quantity,
    required this.handedOut,
    required this.returned,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = quantity == 0 ? 0.0 : (handedOut / quantity).clamp(0.0, 1.0);
    final done = handedOut >= quantity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'แจก $handedOut/$quantity · คืน $returned',
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w800,
                color: done ? AppTheme.primaryColor : AppTheme.mutedText(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            backgroundColor: AppTheme.border(context),
            valueColor: AlwaysStoppedAnimation(
              done ? AppTheme.primaryColor : const Color(0xFF059669),
            ),
          ),
        ),
      ],
    );
  }
}

/// การจองหนึ่งใบ พร้อมอุปกรณ์ที่เช่าและปุ่มติ๊กแจก/รับคืนรายชิ้น
class _RentalBookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Set<String> busy;
  final Future<void> Function(
    String bookingRef,
    String itemName,
    String action,
    bool done,
  )
  onMark;

  const _RentalBookingCard({
    required this.booking,
    required this.busy,
    required this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    final ref = textOf(booking['booking_ref']);
    final name = textOf(booking['customer_name'], ref);
    final phone = textOf(booking['customer_phone']);
    final items = asList(booking['items']).map(asMap).toList();
    final allHandedOut = booking['all_handed_out'] == true;
    final allReturned = booking['all_returned'] == true;

    return Container(
      decoration: AppTheme.cardDecoration(context),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    Text(
                      ref,
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (allReturned)
                const _RentalStatusPill(
                  label: 'รับคืนครบ',
                  color: AppTheme.primaryColor,
                  icon: Icons.assignment_turned_in_rounded,
                )
              else if (allHandedOut)
                const _RentalStatusPill(
                  label: 'แจกครบ',
                  color: Color(0xFF059669),
                  icon: Icons.check_circle_rounded,
                )
              else
                const _RentalStatusPill(
                  label: 'ยังไม่แจก',
                  color: Color(0xFFD97706),
                  icon: Icons.pending_actions_rounded,
                ),
              if (phone.isNotEmpty)
                IconButton(
                  tooltip: 'โทรหาลูกค้า',
                  onPressed: () =>
                      launchUrl(Uri(scheme: 'tel', path: phone)),
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in items)
            _RentalItemRow(
              bookingRef: ref,
              item: item,
              busy: busy,
              onMark: onMark,
            ),
        ],
      ),
    );
  }
}

class _RentalStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _RentalStatusPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: appFont(
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// อุปกรณ์หนึ่งชิ้น: ชื่อ + จำนวน และปุ่มสองสถานะ (แจกแล้ว → รับคืนแล้ว)
class _RentalItemRow extends StatelessWidget {
  final String bookingRef;
  final Map<String, dynamic> item;
  final Set<String> busy;
  final Future<void> Function(
    String bookingRef,
    String itemName,
    String action,
    bool done,
  )
  onMark;

  const _RentalItemRow({
    required this.bookingRef,
    required this.item,
    required this.busy,
    required this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    final name = textOf(item['name']);
    final quantity = int.tryParse(textOf(item['quantity'], '1')) ?? 1;
    final handedOut = item['handed_out'] == true;
    final returned = item['returned'] == true;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 2,
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface(context),
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.subtleSurface(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: Text(
                    'x$quantity',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _RentalToggle(
            label: 'แจกแล้ว',
            active: handedOut,
            busy: busy.contains('$bookingRef|$name|handout'),
            onTap: () => onMark(bookingRef, name, 'handout', !handedOut),
          ),
          const SizedBox(width: 6),
          _RentalToggle(
            label: 'รับคืน',
            active: returned,
            // ยังไม่แจกก็ยังรับคืนไม่ได้ (ฝั่ง API กันไว้อีกชั้น)
            enabled: handedOut,
            busy: busy.contains('$bookingRef|$name|return'),
            onTap: () => onMark(bookingRef, name, 'return', !returned),
          ),
        ],
      ),
    );
  }
}

class _RentalToggle extends StatelessWidget {
  final String label;
  final bool active;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  const _RentalToggle({
    required this.label,
    required this.active,
    required this.busy,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.primaryColor : AppTheme.mutedText(context);
    final disabled = !enabled && !active;

    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Material(
        color: active
            ? AppTheme.primaryColor.withValues(alpha: 0.10)
            : AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          onTap: (disabled || busy) ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(
                color: active
                    ? AppTheme.primaryColor.withValues(alpha: 0.45)
                    : AppTheme.border(context),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    active
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 14,
                    color: color,
                  ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
