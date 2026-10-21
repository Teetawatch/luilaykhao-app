import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/min_tap_target.dart';
import '../widgets/travel_widgets.dart';
import 'payment_screen.dart';

/// "เช่าอุปกรณ์เพิ่ม" — ลูกค้าเลือกเองหลังจองแล้วจ่ายในแอปได้เลย
///
/// เดิมลูกค้าทักแอดมินขอเต็นท์/ถุงนอนเพิ่มตอนใกล้วันเดินทาง แล้วแอดมินแก้ใบจองให้
/// หน้านี้ให้สั่งเองได้ถึง 2 วันก่อนเดินทาง กติกาทั้งหมด (ปิดรับเมื่อไร ใครสั่งได้)
/// มาจาก RentalOrderService ฝั่งหลังบ้าน
///
/// ของที่สั่งกลายเป็น "ยอดเพิ่มเติม" ของใบจอง แล้วจ่ายผ่าน [PaymentScreen] เดิม
/// (สลิปหรือเกตเวย์) — ก้อนที่ไม่จ่ายก่อนปิดรับระบบถอดออกให้เอง
class RentEquipmentScreen extends StatefulWidget {
  final String bookingRef;

  const RentEquipmentScreen({super.key, required this.bookingRef});

  @override
  State<RentEquipmentScreen> createState() => _RentEquipmentScreenState();
}

class _RentEquipmentScreenState extends State<RentEquipmentScreen> {
  static const int _maxQty = 20;

  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  bool _ordering = false;
  bool _cancelling = false;

  /// key ของอุปกรณ์ → จำนวนที่กำลังเลือก (ยังไม่ได้สั่ง)
  final Map<String, int> _quantities = {};

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
      final data = await context.read<AppProvider>().bookingRentals(
        widget.bookingRef,
      );
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'โหลดข้อมูลไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _catalog =>
      asList(_data?['catalog']).map(asMap).toList();

  bool get _open => _data?['open'] == true;

  /// ก้อนที่สั่งแล้วยังไม่จ่าย — มีได้ทีละก้อน
  Map<String, dynamic>? get _awaiting {
    for (final order in asList(_data?['orders']).map(asMap)) {
      if (textOf(order['status']) == 'awaiting_payment') return order;
    }
    return null;
  }

  num get _selectedTotal {
    num total = 0;
    for (final item in _catalog) {
      final qty = _quantities[textOf(item['key'])] ?? 0;
      total += (num.tryParse(textOf(item['price'])) ?? 0) * qty;
    }
    return total;
  }

  int get _selectedCount => _quantities.values.fold(0, (a, b) => a + b);

  void _setQty(String key, int qty) {
    HapticFeedback.selectionClick();
    setState(() {
      if (qty <= 0) {
        _quantities.remove(key);
      } else {
        _quantities[key] = qty.clamp(0, _maxQty);
      }
    });
  }

  Future<void> _order() async {
    if (_ordering || _selectedCount == 0) return;
    setState(() => _ordering = true);
    HapticFeedback.mediumImpact();
    try {
      final result = await context.read<AppProvider>().orderRentals(
        widget.bookingRef,
        Map.of(_quantities),
      );
      if (!mounted) return;
      setState(() {
        _quantities.clear();
        _data = asMap(result['overview']);
      });
      await _pay();
    } on ApiException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'สั่งเช่าไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  Future<void> _pay() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PaymentScreen(bookingRef: widget.bookingRef, extraOnly: true),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _cancel(Map<String, dynamic> order) async {
    if (_cancelling) return;
    final ok = await showConfirmDialog(
      context,
      title: 'ยกเลิกรายการเช่านี้?',
      message: 'อุปกรณ์ในรายการนี้จะถูกนำออกจากการจอง และไม่ต้องชำระยอดนี้',
      tone: ConfirmTone.danger,
      icon: Icons.remove_shopping_cart_outlined,
      confirmLabel: 'ยกเลิกรายการ',
      cancelLabel: 'เก็บไว้',
    );
    if (!ok || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final result = await context.read<AppProvider>().cancelRentalOrder(
        widget.bookingRef,
        (order['id'] as num).toInt(),
      );
      if (!mounted) return;
      setState(() => _data = asMap(result['overview']));
      AppSnack.success(context, 'ยกเลิกรายการเช่าแล้ว');
    } on ApiException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'ยกเลิกไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final awaiting = _awaiting;
    final canPick = data != null && _open && awaiting == null;

    Widget body;
    if (_loading && data == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && data == null) {
      body = _Message(
        icon: Icons.cloud_off_rounded,
        text: _error!,
        action: TextButton(onPressed: _load, child: const Text('ลองใหม่')),
      );
    } else {
      final rented = asList(data?['selected_rentals']).map(asMap).toList();
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _IntroCard(data: data ?? const {}),
            if (awaiting != null) ...[
              const SizedBox(height: 12),
              _AwaitingOrderCard(
                order: awaiting,
                cancelling: _cancelling,
                onPay: _pay,
                onCancel: () => _cancel(awaiting),
              ),
            ],
            if (rented.isNotEmpty) ...[
              const SizedBox(height: 20),
              const _SectionHeading('อุปกรณ์ในการจองนี้'),
              const SizedBox(height: 8),
              _RentedList(items: rented),
            ],
            if (canPick && _catalog.isNotEmpty) ...[
              const SizedBox(height: 20),
              const _SectionHeading('เลือกอุปกรณ์ที่ต้องการเช่าเพิ่ม'),
              const SizedBox(height: 8),
              for (final item in _catalog) ...[
                _CatalogTile(
                  item: item,
                  quantity: _quantities[textOf(item['key'])] ?? 0,
                  onChanged: (qty) => _setQty(textOf(item['key']), qty),
                  maxQty: _maxQty,
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(
          'เช่าอุปกรณ์เพิ่ม',
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: body,
      bottomNavigationBar: canPick && _selectedCount > 0
          ? Container(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                10 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                border: Border(
                  top: BorderSide(color: AppTheme.border(context)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'รวม $_selectedCount ชิ้น',
                          style: appFont(
                            fontSize: AppText.sizeLabel,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      ),
                      Text(
                        money(_selectedTotal),
                        style: appFont(
                          fontSize: AppText.sizeSubtitle,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  PrimaryCTAButton(
                    label: _ordering
                        ? 'กำลังสั่งเช่า...'
                        : 'สั่งเช่าและชำระเงิน',
                    icon: Icons.shopping_bag_rounded,
                    loading: _ordering,
                    onPressed: _order,
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class _IntroCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _IntroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final open = data['open'] == true;
    final lastDay = textOf(data['last_day_label']);
    final reason = textOf(data['closed_reason']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.tintOf(context, AppTheme.primaryColor),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              Icons.backpack_rounded,
              color: AppTheme.onTintOf(context, AppTheme.primaryColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  open && lastDay.isNotEmpty
                      ? 'เช่าได้ถึง $lastDay'
                      : 'ปิดรับเช่าอุปกรณ์ในแอป',
                  style: appFont(
                    fontSize: AppText.sizeSubtitle,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  open
                      ? 'เลือกแล้วชำระในแอปได้เลย ทีมงานเตรียมของให้พร้อมในวันเดินทาง '
                            '(ปิดรับ ${textOf(data['cutoff_days'], '2')} วันก่อนเดินทาง)'
                      : (reason.isEmpty ? 'สั่งเช่าเพิ่มไม่ได้แล้ว' : reason),
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    color: AppTheme.mutedText(context),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ก้อนที่สั่งแล้วรอจ่าย — ปุ่มจ่ายต่อ/ยกเลิก
class _AwaitingOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool cancelling;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  const _AwaitingOrderCard({
    required this.order,
    required this.cancelling,
    required this.onPay,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppTheme.warningColor;
    final items = asList(order['items']).map(asMap).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.isDark(context) ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'รอชำระค่าเช่า',
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              Text(
                money(order['amount']),
                style: appFont(
                  fontSize: AppText.sizeSubtitle,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${textOf(item['name'])} × ${textOf(item['quantity'])}',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'ยังไม่ชำระก่อนปิดรับ ระบบจะยกเลิกรายการนี้ให้อัตโนมัติ',
            style: appFont(
              fontSize: AppText.sizeCaption,
              color: AppTheme.mutedText(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: cancelling ? null : onCancel,
                  child: Text(cancelling ? 'กำลังยกเลิก...' : 'ยกเลิกรายการ'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: cancelling ? null : onPay,
                  child: const Text('ชำระเงิน'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ของที่อยู่ในใบจองแล้ว — ทั้งที่เช่าตอนจอง ที่แอดมินเพิ่มให้ และที่สั่งเพิ่มจากหน้านี้
class _RentedList extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _RentedList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppTheme.border(context)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      textOf(items[i]['name'], '-'),
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                  ),
                  Text(
                    '× ${textOf(items[i]['quantity'], '1')}',
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final int quantity;
  final int maxQty;
  final ValueChanged<int> onChanged;

  const _CatalogTile({
    required this.item,
    required this.quantity,
    required this.maxQty,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = quantity > 0;
    const accent = AppTheme.primaryColor;
    final imageUrl = textOf(item['image_url']);
    final description = textOf(item['description']);
    final price = num.tryParse(textOf(item['price'])) ?? 0;
    final parts = asList(item['parts'])
        .map(asMap)
        .map((p) => '${textOf(p['name'])} ${textOf(p['quantity'])}')
        .join(' · ');

    final placeholder = Container(
      width: 56,
      height: 56,
      color: AppTheme.tintOf(context, accent),
      child: Icon(
        Icons.backpack_rounded,
        size: 24,
        color: AppTheme.onTintOf(context, accent),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.selectedTint(context)
            : AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: selected ? accent : AppTheme.border(context),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: imageUrl.isEmpty
                ? placeholder
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    memCacheWidth: 168,
                    placeholder: (_, _) => placeholder,
                    errorWidget: (_, _, _) => placeholder,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textOf(item['name'], '-'),
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface(context),
                    height: 1.3,
                  ),
                ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                if (parts.isNotEmpty)
                  Text(
                    'ในชุดมี: $parts',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selected
                            ? '${money(price * quantity)} (${money(price)}/ชิ้น)'
                            : '${money(price)} / ชิ้น',
                        style: appFont(
                          fontSize: AppText.sizeLabel,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? AppTheme.onTintOf(context, accent)
                              : AppTheme.onSurface(context),
                        ),
                      ),
                    ),
                    _Stepper(
                      quantity: quantity,
                      accent: accent,
                      onDecrement: quantity > 0
                          ? () => onChanged(quantity - 1)
                          : null,
                      onIncrement: quantity < maxQty
                          ? () => onChanged(quantity + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int quantity;
  final Color accent;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const _Stepper({
    required this.quantity,
    required this.accent,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: Icons.remove_rounded,
          accent: accent,
          onTap: onDecrement,
        ),
        SizedBox(
          width: 30,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w800,
              color: quantity > 0
                  ? AppTheme.onSurface(context)
                  : AppTheme.mutedText(context),
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add_rounded,
          accent: accent,
          onTap: onIncrement,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  const _StepperButton({
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MinTapTarget(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: enabled
                ? accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusXs),
            border: Border.all(
              color: enabled
                  ? accent.withValues(alpha: 0.35)
                  : AppTheme.border(context),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled
                ? accent
                : AppTheme.mutedText(context).withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String text;

  const _SectionHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: appFont(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.mutedText(context),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppTheme.mutedText(context)),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: AppText.sizeBody,
                color: AppTheme.mutedText(context),
                height: 1.45,
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
