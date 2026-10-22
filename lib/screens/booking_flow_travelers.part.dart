part of 'booking_flow_screen.dart';

class TravelerCounter extends StatelessWidget {
  final int count;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const TravelerCounter({
    super.key,
    required this.count,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _fieldBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CounterButton(
            icon: Icons.remove_rounded,
            tooltip: 'ลดจำนวนผู้เดินทาง',
            onPressed: count == 1 ? null : onRemove,
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: SizedBox(
              key: ValueKey(count),
              width: 42,
              child: Center(
                child: Text(
                  '$count',
                  style: appFont(
                    fontWeight: FontWeight.w800,
                    fontSize: AppText.sizeTitle,
                    color: _premiumText(context),
                  ),
                ),
              ),
            ),
          ),
          _CounterButton(
            icon: Icons.add_rounded,
            tooltip: 'เพิ่มจำนวนผู้เดินทาง',
            onPressed: onAdd,
            isPrimary: true,
          ),
        ],
      ),
    );
  }
}

class TravelerFormSection extends StatelessWidget {
  final List<_PassengerControllers> passengers;
  final TextEditingController groupNotes;
  final bool isSeatSelectionMode;
  final List<String> selectedSeatIds;
  final VoidCallback onAddPassenger;
  final VoidCallback onRemovePassenger;
  final ValueChanged<int> onUseProfile;
  final ValueChanged<int> onUseWallet;
  final ValueChanged<int> onUseSavedTraveller;
  final List<dynamic> pickupPoints;
  /// เอกสารเดินทางที่ต้องถาม (passport | passport_or_border_pass | on_site)
  /// null = ทริปในประเทศ ไม่มีกล่องเอกสารเดินทาง
  final String? travelDocumentMode;
  /// วันหมดอายุพาสปอร์ตที่เร็วที่สุดที่ยังใช้เดินทางรอบนี้ได้ (วันเดินทาง + 6 เดือน)
  final DateTime? minPassportExpiry;
  /// เอกสารที่ทริปนี้ขอให้แนบ — แอดมินตั้งไว้บนทริป ว่างได้ (ไม่ต้องแนบอะไร)
  final List<dynamic> documentRequirements;

  /// บัตรประชาชนหน้า/หลัง — ขอเพิ่มเฉพาะคนที่เลือก Border Pass
  final List<dynamic> borderPassDocuments;

  const TravelerFormSection({
    super.key,
    required this.passengers,
    required this.groupNotes,
    required this.isSeatSelectionMode,
    required this.selectedSeatIds,
    required this.onAddPassenger,
    required this.onRemovePassenger,
    required this.onUseProfile,
    required this.onUseWallet,
    required this.onUseSavedTraveller,
    this.pickupPoints = const [],
    this.travelDocumentMode,
    this.minPassportExpiry,
    this.documentRequirements = const [],
    this.borderPassDocuments = const [],
  });

  /// พับคนที่กรอกเสร็จ แล้วกางคนถัดไปและเลื่อนไปหา — กรอกทีละคนเป็นจังหวะ
  void _advance(BuildContext context, int index) {
    FocusScope.of(context).unfocus();
    passengers[index].expanded.value = false;
    final target = index + 1 < passengers.length
        ? passengers[index + 1]
        : passengers[index];
    if (target != passengers[index]) target.expanded.value = true;
    // รอให้การ์ดที่พับหดเสร็จก่อน ไม่งั้นตำแหน่งที่เลื่อนไปจะคลาดตอนมันหด
    Future.delayed(const Duration(milliseconds: 230), () {
      final ctx = target.cardKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'ข้อมูลผู้เดินทาง',
      icon: Icons.people_alt_rounded,
      trailing: isSeatSelectionMode
          ? _SeatDrivenTravelerCount(count: selectedSeatIds.length)
          : TravelerCounter(
              count: passengers.length,
              onAdd: onAddPassenger,
              onRemove: onRemovePassenger,
            ),
      child: Column(
        children: [
          for (var index = 0; index < passengers.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            _TravelerCard(
              key: ObjectKey(passengers[index]),
              index: index,
              total: passengers.length,
              controllers: passengers[index],
              seatId: index < selectedSeatIds.length
                  ? selectedSeatIds[index]
                  : null,
              pickupPoints: pickupPoints,
              travelDocumentMode: travelDocumentMode,
              minPassportExpiry: minPassportExpiry,
              documentRequirements: documentRequirements,
              borderPassDocuments: borderPassDocuments,
              onUseProfile: () => onUseProfile(index),
              onUseWallet: () => onUseWallet(index),
              onUseSavedTraveller: () => onUseSavedTraveller(index),
              onDone: () => _advance(context, index),
            ),
          ],
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: passengers.length > 1
                ? Padding(
                    key: const ValueKey('group-notes'),
                    padding: const EdgeInsets.only(top: 16),
                    child: _PremiumTextField(
                      controller: groupNotes,
                      label: 'หมายเหตุถึงทีมงาน (ไม่บังคับ)',
                      hint: 'เช่น ขอที่นั่งใกล้กัน',
                      icon: Icons.notes_rounded,
                      maxLines: 2,
                      textInputAction: TextInputAction.newline,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('empty-notes')),
          ),
        ],
      ),
    );
  }
}

class PricingSummaryCard extends StatelessWidget {
  final _PricingQuote pricing;
  final TextEditingController promoController;
  final bool expanded;
  final VoidCallback onExpandedChanged;
  final Map<String, dynamic>? appliedPromo;
  final bool promoLoading;
  final String? promoError;
  final VoidCallback onApplyPromo;
  final VoidCallback onRemovePromo;
  // ประเภทรถที่เลือก — ยอดรวมอยู่ในค่าที่นั่งแล้ว บรรทัดนี้บอกว่ามาจากอะไร
  final String vehicleLabel;
  final num vehicleAdjustment;
  // บัตรของขวัญ — onChooseVoucher เป็น null = ช่องนี้ใช้บัตรไม่ได้ (ซ่อนปุ่ม)
  final SelectedGiftVoucher? appliedVoucher;
  final VoidCallback? onChooseVoucher;
  final VoidCallback? onRemoveVoucher;

  const PricingSummaryCard({
    super.key,
    required this.pricing,
    required this.promoController,
    required this.expanded,
    required this.onExpandedChanged,
    required this.appliedPromo,
    required this.promoLoading,
    required this.promoError,
    required this.onApplyPromo,
    required this.onRemovePromo,
    this.vehicleLabel = '',
    this.vehicleAdjustment = 0,
    this.appliedVoucher,
    this.onChooseVoucher,
    this.onRemoveVoucher,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'สรุปราคา',
      icon: Icons.receipt_long_rounded,
      child: Column(
        children: [
          _PromoField(
            controller: promoController,
            appliedPromo: appliedPromo,
            discount: pricing.discount,
            loading: promoLoading,
            error: promoError,
            onApply: onApplyPromo,
            onRemove: onRemovePromo,
          ),
          if (onChooseVoucher != null) ...[
            const SizedBox(height: 10),
            _GiftVoucherRow(
              voucher: appliedVoucher,
              covered: pricing.voucher,
              onChoose: onChooseVoucher!,
              onRemove: onRemoveVoucher,
            ),
          ],
          const SizedBox(height: 16),
          if (!pricing.hasVariedPrices) ...[
            _PriceRow(
              label: 'ราคาต่อท่าน',
              value: money(pricing.pricePerTraveler),
            ),
            const SizedBox(height: 10),
            _PriceRow(
              label: 'จำนวนผู้เดินทาง',
              value: '${pricing.travelerCount} คน',
            ),
            const SizedBox(height: 10),
          ],
          _PriceRow(
            label: pricing.hasVariedPrices
                ? 'ค่าที่นั่ง (${pricing.travelerCount} คน)'
                : 'ราคาทริป',
            value: money(pricing.tripSubtotal),
          ),
          const SizedBox(height: 10),
          // ส่วนต่างของรถถูกบวกในค่าที่นั่งไปแล้ว บรรทัดนี้จึงบอกที่มา ไม่ใช่ยอดเพิ่ม
          if (vehicleLabel.isNotEmpty && vehicleAdjustment != 0) ...[
            _PriceRow(
              label: 'รวมค่า$vehicleLabel',
              value:
                  '${vehicleAdjustment > 0 ? '+' : '-'}${money(vehicleAdjustment.abs())} × ${pricing.travelerCount}',
              valueColor: _mutedTextColor(context),
            ),
            const SizedBox(height: 10),
          ],
          if (pricing.addonsTotal > 0) ...[
            _PriceRow(
              label: 'ตัวเลือกเสริม',
              value: money(pricing.addonsTotal),
            ),
            const SizedBox(height: 10),
          ],
          if (pricing.rentalsTotal > 0) ...[
            _PriceRow(
              label: 'ค่าเช่าอุปกรณ์',
              value: money(pricing.rentalsTotal),
            ),
            const SizedBox(height: 10),
          ],
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                _PriceRow(label: 'ค่าบริการ', value: money(pricing.serviceFee)),
                const SizedBox(height: 10),
              ],
            ),
          ),
          // Discount stays visible (not tucked behind "ดูรายละเอียด") so the
          // applied saving is obvious right here, before payment.
          if (pricing.discount > 0) ...[
            _PriceRow(
              label: 'ส่วนลด${appliedPromo != null ? ' (${textOf(appliedPromo!['code'])})' : ''}',
              value: '-${money(pricing.discount)}',
              valueColor: _softAccent,
            ),
            const SizedBox(height: 10),
          ],
          if (pricing.voucher > 0) ...[
            _PriceRow(
              label: 'บัตรของขวัญ (${appliedVoucher?.displayCode ?? ''})',
              value: '-${money(pricing.voucher)}',
              valueColor: _softAccent,
            ),
            const SizedBox(height: 10),
          ],
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            onTap: onExpandedChanged,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(
                    expanded ? 'ซ่อนรายละเอียดราคา' : 'ดูรายละเอียดราคา',
                    style: appFont(
                      color: _softAccent,
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _softAccent,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 24, color: _cardBorder(context)),
          _PriceRow(
            label: pricing.voucher > 0 ? 'ยอดที่ต้องชำระ' : 'รวมทั้งหมด',
            value: money(pricing.total),
            amount: pricing.total,
            isTotal: true,
          ),
          if (pricing.voucher > 0 && pricing.total <= 0) ...[
            const SizedBox(height: 8),
            Text(
              'บัตรของขวัญจ่ายครบแล้ว กดยืนยันการจองได้เลย ไม่ต้องโอนเงินเพิ่ม',
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w700,
                color: _softAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// แถว "ใช้บัตรของขวัญ" — ยังไม่เลือก = ปุ่มเปิดตัวเลือก, เลือกแล้ว = รหัส + ยอดที่หัก
class _GiftVoucherRow extends StatelessWidget {
  final SelectedGiftVoucher? voucher;
  final num covered;
  final VoidCallback onChoose;
  final VoidCallback? onRemove;

  const _GiftVoucherRow({
    required this.voucher,
    required this.covered,
    required this.onChoose,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    if (v == null) {
      return OutlinedButton.icon(
        onPressed: () {
          HapticFeedback.selectionClick();
          onChoose();
        },
        icon: const Icon(Icons.card_giftcard_rounded, size: 18),
        label: const Text('ใช้บัตรของขวัญ'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
        ),
      );
    }

    final left = v.balance - covered;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppTheme.selectedTint(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.card_giftcard_rounded,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'บัตรของขวัญ ${v.displayCode}',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                Text(
                  left > 0
                      ? 'หัก ${money(covered)} · เหลือในบัตร ${money(left)}'
                      : 'หัก ${money(covered)} (ใช้ครบยอดบัตร)',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'เอาบัตรออก',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

/// Discount-code entry that validates inline: shows the applied code + savings
/// (with a remove action) once accepted, or an input + "ใช้โค้ด" button and an
/// error message before that. The discount + net total update immediately.
class _PromoField extends StatelessWidget {
  final TextEditingController controller;
  final Map<String, dynamic>? appliedPromo;
  final num discount;
  final bool loading;
  final String? error;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  const _PromoField({
    required this.controller,
    required this.appliedPromo,
    required this.discount,
    required this.loading,
    required this.error,
    required this.onApply,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (appliedPromo != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _softAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: _softAccent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: _softAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ใช้โค้ด ${textOf(appliedPromo!['code'])} แล้ว',
                    style: appFont(
                      color: _softAccent,
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ส่วนลด ${money(discount)}',
                    style: appFont(
                      color: _softAccent,
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: _mutedTextColor(context),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ป้ายอยู่นอกแถว ช่องกับปุ่มจึงสูงเท่ากันพอดี (เดิมปุ่มไปเสมอกับป้ายด้านบน)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('โค้ดส่วนลด', style: _labelStyle(context)),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onApply(),
                  decoration: _fieldDecoration(
                    context: context,
                    icon: Icons.local_offer_rounded,
                    hint: 'เช่น NEWLUILAY',
                  ),
                  style: appFont(
                    color: _premiumText(context),
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: loading ? null : onApply,
                style: FilledButton.styleFrom(
                  backgroundColor: _softAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'ใช้โค้ด',
                        style: appFont(
                          color: Colors.white,
                          fontSize: AppText.sizeBody,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 15, color: AppTheme.errorColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  error!,
                  style: appFont(
                    color: AppTheme.errorColor,
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Optional add-ons picker. Each item has its own quantity stepper because a
/// group rarely wants the same thing: 4 people can travel together but only 2
/// of them rent a mat.
class AddonSelectionSection extends StatelessWidget {
  final List<_AddonOption> addons;
  final Map<int, int> quantities;
  final int travelerCount;
  final void Function(int index, int quantity) onChanged;

  const AddonSelectionSection({
    super.key,
    required this.addons,
    required this.quantities,
    required this.travelerCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedTotal = addons.fold<num>(
      0,
      (sum, addon) => sum + addon.price * (quantities[addon.index] ?? 0),
    );

    return _SectionShell(
      title: 'ตัวเลือกเสริม',
      icon: Icons.add_task_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'เลือกจำนวนได้ตามต้องการ ไม่ต้องเท่าจำนวนผู้เดินทาง',
              style: appFont(
                color: AppTheme.mutedText(context),
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...addons.map((addon) {
            final qty = quantities[addon.index] ?? 0;
            final maxQty = addon.maxQuantityFor(travelerCount);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ExtraItemTile(
                name: addon.name,
                priceLabel: '${money(addon.price)} · ${addon.priceTypeLabel}',
                lineTotal: addon.price * qty,
                imageUrl: addon.imageUrl,
                fallbackIcon: Icons.add_task_rounded,
                quantity: qty,
                onDecrement: qty > 0
                    ? () => onChanged(addon.index, qty - 1)
                    : null,
                onIncrement: qty < maxQty
                    ? () => onChanged(addon.index, qty + 1)
                    : null,
              ),
            );
          }),
          if (selectedTotal > 0) ...[
            const SizedBox(height: 2),
            _PriceRow(
              label: 'รวมตัวเลือกเสริม',
              value: money(selectedTotal),
            ),
          ],
        ],
      ),
    );
  }
}

/// Equipment rental picker — each item has a quantity stepper (rent 2 sleeping
/// bags, 1 trekking pole, …).
class RentalSelectionSection extends StatelessWidget {
  static const int _maxQty = 20;

  final List<_RentalOption> rentals;
  final Map<int, int> quantities;
  final void Function(int index, int quantity) onChanged;

  const RentalSelectionSection({
    super.key,
    required this.rentals,
    required this.quantities,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedTotal = rentals.fold<num>(
      0,
      (sum, r) => sum + r.price * (quantities[r.index] ?? 0),
    );

    return _SectionShell(
      title: 'เช่าอุปกรณ์',
      icon: Icons.backpack_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...rentals.map((rental) {
            final qty = quantities[rental.index] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ExtraItemTile(
                name: rental.name,
                description: rental.description,
                priceLabel: '${money(rental.price)} · ต่อชิ้น',
                lineTotal: rental.price * qty,
                imageUrl: rental.imageUrl,
                fallbackIcon: Icons.backpack_rounded,
                quantity: qty,
                onDecrement: qty > 0
                    ? () => onChanged(rental.index, qty - 1)
                    : null,
                onIncrement: qty < _maxQty
                    ? () => onChanged(rental.index, qty + 1)
                    : null,
              ),
            );
          }),
          if (selectedTotal > 0) ...[
            const SizedBox(height: 2),
            _PriceRow(
              label: 'รวมค่าเช่าอุปกรณ์',
              value: money(selectedTotal),
            ),
          ],
        ],
      ),
    );
  }
}

/// รายการเสริม / อุปกรณ์เช่าหนึ่งชิ้น — ยังไม่เลือกมีแค่ปุ่ม "เพิ่ม" ชื่อจึงได้
/// ที่เต็มบรรทัด เลือกแล้วตัวปรับจำนวนกับยอดรวมของชิ้นนั้นลงไปอยู่แถวล่าง
class _ExtraItemTile extends StatelessWidget {
  final String name;
  final String description;
  final String priceLabel;
  final num lineTotal;
  final String imageUrl;
  final IconData fallbackIcon;
  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const _ExtraItemTile({
    required this.name,
    this.description = '',
    required this.priceLabel,
    required this.lineTotal,
    required this.imageUrl,
    required this.fallbackIcon,
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final selected = quantity > 0;
    final hasImage = imageUrl.isNotEmpty;
    // การ์ดที่เลือกพื้นเป็นสีเขียวอ่อนแล้ว — กล่องไอคอนสลับเป็นพื้นขาวไม่ให้จมหาย
    final placeholder = Container(
      width: 48,
      height: 48,
      color: selected
          ? AppTheme.surface(context)
          : AppTheme.tintOf(context, _softAccent),
      child: Icon(
        fallbackIcon,
        size: 22,
        color: AppTheme.onTintOf(context, _softAccent),
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
          color: selected ? _softAccent : _cardBorder(context),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: hasImage
                    ? () => _openAddonImage(context, imageUrl)
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          memCacheWidth: 144,
                          placeholder: (_, _) => placeholder,
                          errorWidget: (_, _, _) => placeholder,
                        )
                      : placeholder,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        color: _premiumText(context),
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    if (description.isNotEmpty)
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          color: _mutedTextColor(context),
                          fontSize: AppText.sizeCaption,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      priceLabel,
                      style: appFont(
                        color: _mutedTextColor(context),
                        fontSize: AppText.sizeCaption,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (!selected) ...[
                const SizedBox(width: 8),
                _AddPillButton(onTap: onIncrement),
              ],
            ],
          ),
          if (selected) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '+${money(lineTotal)}',
                    style: appFont(
                      color: AppTheme.onTintOf(context, _softAccent),
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _QuantityStepper(
                  quantity: quantity,
                  accent: _softAccent,
                  onDecrement: onDecrement,
                  onIncrement: onIncrement,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AddPillButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddPillButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: enabled
                  ? _softAccent.withValues(alpha: 0.5)
                  : _cardBorder(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_rounded,
                size: 16,
                color: enabled ? _softAccent : _mutedTextColor(context),
              ),
              const SizedBox(width: 4),
              Text(
                'เพิ่ม',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w800,
                  color: enabled ? _softAccent : _mutedTextColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact − [n] + control used by the rental picker.
/// กล่อง "เอกสารที่ต้องแนบ" ของผู้เดินทางหนึ่งคน
///
/// เก็บแค่ path ในเครื่อง — ยังไม่มี booking_ref ให้ผูกไฟล์ด้วยจนกว่าการจอง
/// จะถูกสร้าง [_BookingCheckoutPageState._uploadDocuments] เป็นคนส่งขึ้นทีหลัง
class _TravelerDocumentBox extends StatelessWidget {
  final List<dynamic> requirements;
  final ValueNotifier<Map<String, List<String>>> documents;

  const _TravelerDocumentBox({
    required this.requirements,
    required this.documents,
  });

  /// บัตรประชาชนของ Border Pass มีได้ด้านละไฟล์เดียว — เลือกใหม่ = แทนที่
  void _add(String key, String path, {bool single = false}) {
    final next = Map<String, List<String>>.from(documents.value);
    next[key] = single ? [path] : [...(next[key] ?? const []), path];
    documents.value = next;
  }

  void _remove(String key, int index) {
    final next = Map<String, List<String>>.from(documents.value);
    final files = [...(next[key] ?? const <String>[])];
    if (index < 0 || index >= files.length) return;
    files.removeAt(index);
    next[key] = files;
    documents.value = next;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: _cardBorder(context)),
      ),
      child: ValueListenableBuilder<Map<String, List<String>>>(
        valueListenable: documents,
        builder: (context, picked, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.attach_file_rounded,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'เอกสารที่ต้องแนบ',
                          style: appFont(
                            fontSize: AppText.sizeLabel,
                            fontWeight: FontWeight.w800,
                            color: _premiumText(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'แนบเป็นรูปถ่ายหรือไฟล์ PDF ก็ได้ '
                          'ไม่เกิน ${DocumentAttachField.maxSizeMb} MB ต่อไฟล์',
                          style: appFont(
                            fontSize: AppText.sizeCaption,
                            color: _mutedTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              for (final raw in requirements) ...[
                const SizedBox(height: 14),
                Builder(
                  builder: (context) {
                    final requirement = asMap(raw);
                    final key = textOf(requirement['key']);
                    final files = picked[key] ?? const <String>[];

                    return DocumentAttachField(
                      requirement: requirement,
                      fileNames: files
                          .map((path) => path.split('/').last)
                          .toList(),
                      onPicked: (path) => _add(
                        key,
                        path,
                        single: requirement['for'] == 'border_pass',
                      ),
                      onRemove: (index) => _remove(key, index),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final Color accent;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const _QuantityStepper({
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
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap!();
            }
          : null,
      child: MinTapTarget(child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? accent.withValues(alpha: 0.12) : Colors.transparent,
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
          color: enabled ? accent : AppTheme.mutedText(context).withValues(alpha: 0.4),
        ),
      )),
    );
  }
}

class TrustSignalsSection extends StatelessWidget {
  const TrustSignalsSection({super.key});

  @override
  Widget build(BuildContext context) {
    const signals = [
      _TrustSignal(Icons.lock_rounded, 'ชำระเงินปลอดภัย'),
      _TrustSignal(Icons.bolt_rounded, 'ยืนยันทันที'),
      _TrustSignal(Icons.support_agent_rounded, 'ทีมงาน 24 ชม.'),
    ];

    // Quiet, Apple-style reassurance footnote: muted icon + label, no chips or
    // tinted backgrounds, centered, wrapping gracefully on narrow screens.
    final color = AppTheme.mutedText(context);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 18,
      runSpacing: 8,
      children: signals.map((signal) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(signal.icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              signal.label,
              style: appFont(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: AppText.sizeCaption,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class StickyCheckoutBar extends StatelessWidget {
  final num total;
  final bool isSubmitting;
  final bool canGoBack;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onBack;
  final VoidCallback? onPressed;

  const StickyCheckoutBar({
    super.key,
    required this.total,
    required this.isSubmitting,
    required this.canGoBack,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onBack,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // The home-indicator inset is padded *inside* the bar rather than wrapping
    // it in a SafeArea — a SafeArea would lift the whole bar off the screen
    // edge and leave a strip of page background showing underneath it, which
    // reads as a floating panel instead of a grounded checkout bar.
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final vPad = isNarrow ? 10.0 : 12.0;
        final hPad = isNarrow ? 14.0 : 16.0;
        // Match the app's primary CTA language (54h / radius 16) rather than
        // the smaller pill this bar used to draw.
        final btnHeight = isNarrow ? 48.0 : 52.0;
        final priceFontSize = isNarrow ? 17.0 : 19.0;
        final labelFontSize = isNarrow ? 11.0 : 12.0;
        final btnFontSize = isNarrow ? 14.0 : 15.0;
        final iconSize = isNarrow ? 17.0 : 18.0;

        return Container(
          padding: EdgeInsets.fromLTRB(
            hPad,
            vPad,
            hPad,
            vPad + (safeBottom > 0 ? safeBottom : vPad),
          ),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            border: Border(top: BorderSide(color: AppTheme.border(context))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Total reads as its own line so the CTA below can run full
              // width — long Thai step labels no longer get ellipsised.
              Row(
                children: [
                  Text(
                    'รวมทั้งหมด',
                    style: appFont(
                      color: _mutedTextColor(context),
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  CountUpText(
                    value: total,
                    format: money,
                    style: appFont(
                      color: _premiumText(context),
                      fontSize: priceFontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isNarrow ? 8 : 10),
              Row(
                children: [
                  if (canGoBack) ...[
                    SizedBox(
                      width: btnHeight,
                      height: btnHeight,
                      child: IconButton(
                        onPressed: isSubmitting ? null : onBack,
                        tooltip: 'ย้อนกลับ',
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          backgroundColor: _fieldBackground(context),
                          foregroundColor: _premiumText(context),
                          disabledForegroundColor:
                              _mutedTextColor(context).withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                        icon: Icon(Icons.arrow_back_rounded, size: iconSize + 2),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: btnHeight,
                      child: FilledButton(
                        onPressed: onPressed,
                        style: FilledButton.styleFrom(
                          backgroundColor: _softAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppTheme.border(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: isNarrow ? 12 : 16,
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: isSubmitting
                              ? const SizedBox(
                                  key: ValueKey('loading'),
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  key: ValueKey(primaryLabel),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(primaryIcon, size: iconSize),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        primaryLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: appFont(
                                          fontWeight: FontWeight.w800,
                                          fontSize: btnFontSize,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _SectionShell({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _premiumDecoration(context, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _softAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, color: _softAccent, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: appFont(
                    fontSize: AppText.sizeTitle,
                    fontWeight: FontWeight.w800,
                    color: _premiumText(context),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 0.5,
            color: AppTheme.border(context).withValues(alpha: 0.45),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SeatDrivenTravelerCount extends StatelessWidget {
  final int count;

  const _SeatDrivenTravelerCount({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _softAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_seat_rounded, color: _softAccent, size: 16),
          const SizedBox(width: 6),
          Text(
            count > 0 ? '$count คน' : 'เลือกที่นั่ง',
            style: appFont(
              color: _softAccent,
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// การ์ดผู้เดินทางหนึ่งคน — พับ/กางได้ หัวการ์ดบอกชื่อและจำนวนช่องที่ยังขาด
/// เพื่อให้กลุ่มหลายคนไม่ต้องเลื่อนผ่านฟอร์มยาวทุกคนในคราวเดียว
///
/// การ์ดที่พับยังเก็บช่องไว้ในฟอร์ม (Visibility.maintainState) ตัวตรวจของฟอร์ม
/// จึงยังทำงานครบทุกคน หน้าจอเป็นคนกางการ์ดที่ไม่ผ่านให้เห็นเอง
class _TravelerCard extends StatelessWidget {
  final int index;
  final int total;
  final _PassengerControllers controllers;
  final String? seatId;
  final List<dynamic> pickupPoints;
  final String? travelDocumentMode;
  final DateTime? minPassportExpiry;
  final List<dynamic> documentRequirements;
  final List<dynamic> borderPassDocuments;
  final VoidCallback onUseProfile;
  final VoidCallback onUseWallet;
  final VoidCallback onUseSavedTraveller;
  final VoidCallback onDone;

  const _TravelerCard({
    super.key,
    required this.index,
    required this.total,
    required this.controllers,
    this.seatId,
    this.pickupPoints = const [],
    this.travelDocumentMode,
    this.minPassportExpiry,
    this.documentRequirements = const [],
    this.borderPassDocuments = const [],
    required this.onUseProfile,
    required this.onUseWallet,
    required this.onUseSavedTraveller,
    required this.onDone,
  });

  /// คนเดียวไม่มีอะไรให้พับ — ฟอร์มเปิดค้างไว้เสมอ
  bool get _collapsible => total > 1;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controllers.expanded,
      builder: (context, expanded, _) {
        final open = expanded || !_collapsible;
        return AnimatedContainer(
          key: controllers.cardKey,
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: open && _collapsible
                  ? _softAccent.withValues(alpha: 0.45)
                  : _cardBorder(context),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TravelerCardHeader(
                index: index,
                controllers: controllers,
                seatId: seatId,
                open: open,
                collapsible: _collapsible,
                needsPickup: pickupPoints.isNotEmpty,
                travelDocumentMode: travelDocumentMode,
                minPassportExpiry: minPassportExpiry,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Visibility(
                  visible: open,
                  maintainState: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                    child: _buildBody(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final showPickup = pickupPoints.length > 1 ||
        (pickupPoints.isNotEmpty && controllers.pickupPointId.value == null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: _cardBorder(context)),
        const SizedBox(height: 14),
        _QuickFillRow(
          onUseSavedTraveller: onUseSavedTraveller,
          onUseProfile: onUseProfile,
          onUseWallet: onUseWallet,
        ),
        if (showPickup) ...[
          const SizedBox(height: 16),
          _PassengerPickupChips(
            pickupPoints: pickupPoints,
            selected: controllers.pickupPointId,
          ),
        ],
        const _FormGroupLabel(
          icon: Icons.badge_rounded,
          text: 'ข้อมูลส่วนตัว',
        ),
        _ChoiceChipsField(
          label: 'คำนำหน้า',
          controller: controllers.title,
          options: _titleOptions,
          normalize: _titleValue,
          errorText: 'กรุณาเลือกคำนำหน้า',
        ),
        const SizedBox(height: 12),
        _PremiumTextField(
          controller: controllers.name,
          label: 'ชื่อ-นามสกุล (ภาษาไทยตามบัตรประชาชน)',
          hint: 'สมชาย ลุยเลยเขา',
          icon: Icons.person_rounded,
          validator: _thaiNameValidator,
          autofillHints: const [AutofillHints.name],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        _FieldPair(
          first: _PremiumTextField(
            controller: controllers.nickname,
            label: 'ชื่อเล่น',
            hint: 'เช่น ต้น',
            icon: Icons.face_rounded,
            validator: _requiredValidator('กรุณากรอกชื่อเล่น'),
            textInputAction: TextInputAction.next,
          ),
          second: _PremiumTextField(
            controller: controllers.phone,
            label: 'เบอร์โทรศัพท์',
            hint: '0812345678',
            icon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: _phoneValidator('กรุณากรอกเบอร์โทรศัพท์'),
            autofillHints: const [AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 12),
        _PremiumTextField(
          controller: controllers.email,
          label: 'อีเมล (ไม่บังคับ)',
          hint: 'name@example.com',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: _optionalEmailValidator,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        _FieldPair(
          first: _PremiumTextField(
            controller: controllers.idCard,
            label: 'เลขบัตรประชาชน (ใช้ทำประกัน)',
            hint: 'เลข 13 หลัก',
            icon: Icons.credit_card_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(13),
            ],
            validator: _exactDigitsValidator(
              requiredMessage: 'กรุณากรอกเลขบัตรประชาชน',
              lengthMessage: 'เลขบัตรประชาชนต้องมี 13 หลัก',
              length: 13,
            ),
            textInputAction: TextInputAction.next,
          ),
          second: _PremiumDatePicker(
            value: controllers.birthDate,
            label: 'วันเกิด',
            icon: Icons.cake_rounded,
            validator: (date) =>
                date == null ? 'กรุณาเลือกวัน/เดือน/ปีเกิด' : null,
          ),
        ),
        // เอกสารเดินทาง — ข้อมูลชุดนี้เอาไปออกตั๋วเครื่องบินตรง ๆ สะกดผิด
        // แม้ตัวเดียวคือขึ้นเครื่องไม่ได้ จึงแยกกล่องให้เห็นชัดว่าคนละชุดกัน
        if (travelDocumentMode == _docsOnSite) ...[
          const SizedBox(height: 16),
          const _OnSiteDocumentNote(),
        ] else if (travelDocumentMode != null) ...[
          const SizedBox(height: 16),
          _PassportBox(
            controllers: controllers,
            minPassportExpiry: minPassportExpiry,
            offersBorderPass: travelDocumentMode == _docsPassportOrBorderPass,
          ),
        ],
        const _FormGroupLabel(
          icon: Icons.health_and_safety_rounded,
          text: 'สุขภาพและอาหาร',
        ),
        _ChoiceChipsField(
          label: 'กรุ๊ปเลือด',
          controller: controllers.bloodGroup,
          options: _bloodGroupOptions,
          normalize: _bloodGroupValue,
          errorText: 'กรุณาเลือกกรุ๊ปเลือด',
        ),
        const SizedBox(height: 12),
        _HalalSwitchRow(selected: controllers.halalFood),
        const SizedBox(height: 12),
        _PremiumTextField(
          controller: controllers.allergies,
          label: 'แพ้อาหาร / ข้อจำกัดอาหาร (ไม่บังคับ)',
          hint: 'เช่น แพ้อาหารทะเล, ไม่ทานเนื้อ, แพ้ถั่ว',
          icon: Icons.restaurant_menu_rounded,
          maxLines: 2,
          textInputAction: TextInputAction.newline,
        ),
        const SizedBox(height: 12),
        _PremiumTextField(
          controller: controllers.healthNotes,
          label: 'โรคประจำตัว / หมายเหตุสุขภาพ (ไม่บังคับ)',
          hint: 'เช่น หอบหืด พกยาพ่นติดตัว',
          icon: Icons.medical_information_rounded,
          maxLines: 2,
          textInputAction: TextInputAction.newline,
        ),
        // เอกสารแนบที่ทริปขอ — รายการและข้อความ "ใช้สำหรับ..." มาจากที่แอดมิน
        // ตั้งไว้บนทริป ไฟล์ถูกเก็บไว้ในหน้าจอก่อน แล้วส่งขึ้นหลังสร้างการจอง
        // บัตรประชาชนของ Border Pass ขึ้นเมื่อคนนี้เลือก Border Pass เท่านั้น
        ListenableBuilder(
          listenable: controllers.travelDocument,
          builder: (context, _) {
            final requirements = [
              ...documentRequirements,
              if (controllers.choseBorderPass(travelDocumentMode))
                ...borderPassDocuments,
            ];
            if (requirements.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _TravelerDocumentBox(
                requirements: requirements,
                documents: controllers.documents,
              ),
            );
          },
        ),
        const _FormGroupLabel(
          icon: Icons.contact_emergency_rounded,
          text: 'ผู้ติดต่อฉุกเฉิน',
        ),
        _FieldPair(
          first: _PremiumTextField(
            controller: controllers.emergencyContact,
            label: 'ชื่อผู้ติดต่อ',
            hint: 'เช่น คุณแม่ สมศรี',
            icon: Icons.person_outline_rounded,
            validator: _requiredValidator('กรุณากรอกชื่อผู้ติดต่อฉุกเฉิน'),
            autofillHints: const [AutofillHints.name],
            textInputAction: TextInputAction.next,
          ),
          second: _PremiumTextField(
            controller: controllers.emergencyPhone,
            label: 'เบอร์ติดต่อฉุกเฉิน',
            hint: '0891234567',
            icon: Icons.phone_enabled_rounded,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: _phoneValidator('กรุณากรอกเบอร์ติดต่อฉุกเฉิน'),
            autofillHints: const [AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.done,
          ),
        ),
        if (_collapsible) ...[
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              onDone();
            },
            icon: Icon(
              index < total - 1
                  ? Icons.arrow_downward_rounded
                  : Icons.check_rounded,
              size: 18,
            ),
            label: Text(
              index < total - 1
                  ? 'ถัดไป · ผู้เดินทางคนที่ ${index + 2}'
                  : 'เรียบร้อย',
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _softAccent,
              minimumSize: const Size.fromHeight(46),
              side: BorderSide(color: _softAccent.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TravelerCardHeader extends StatelessWidget {
  final int index;
  final _PassengerControllers controllers;
  final String? seatId;
  final bool open;
  final bool collapsible;
  final bool needsPickup;
  final String? travelDocumentMode;
  final DateTime? minPassportExpiry;

  const _TravelerCardHeader({
    required this.index,
    required this.controllers,
    required this.seatId,
    required this.open,
    required this.collapsible,
    required this.needsPickup,
    required this.travelDocumentMode,
    required this.minPassportExpiry,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controllers.changes,
      builder: (context, _) {
        final missing = controllers.missingCount(
          documentMode: travelDocumentMode,
          needsPickup: needsPickup,
          minPassportExpiry: minPassportExpiry,
        );
        final complete = missing == 0;
        final blank = controllers.isBlank;
        final name = controllers.name.text.trim();

        final (String status, Color statusColor) = complete
            ? ('ข้อมูลครบแล้ว', _softAccent)
            : blank
            ? (
                collapsible && !open ? 'แตะเพื่อกรอกข้อมูล' : 'ยังไม่ได้กรอก',
                _mutedTextColor(context),
              )
            : ('ยังขาดอีก $missing ช่อง', AppTheme.warningColor);

        return Semantics(
          button: collapsible,
          expanded: collapsible ? open : null,
          child: InkWell(
            onTap: collapsible
                ? () {
                    HapticFeedback.selectionClick();
                    controllers.expanded.value = !open;
                  }
                : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: complete
                          ? _softAccent
                          : AppTheme.tintOf(context, _softAccent),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: complete
                          ? const Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: Colors.white,
                            )
                          : Text(
                              '${index + 1}',
                              style: appFont(
                                color: AppTheme.onTintOf(context, _softAccent),
                                fontWeight: FontWeight.w800,
                                fontSize: AppText.sizeBody,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'ผู้เดินทางคนที่ ${index + 1}' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appFont(
                            fontWeight: FontWeight.w800,
                            color: _premiumText(context),
                            fontSize: AppText.sizeBody,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appFont(
                            fontWeight: FontWeight.w700,
                            color: complete || !blank
                                ? AppTheme.onTintOf(context, statusColor)
                                : statusColor,
                            fontSize: AppText.sizeCaption,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (seatId != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _fieldBackground(context),
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        border: Border.all(color: _cardBorder(context)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_seat_rounded,
                            size: 13,
                            color: _mutedTextColor(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            seatId!,
                            style: appFont(
                              color: _premiumText(context),
                              fontSize: AppText.sizeCaption,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (collapsible) ...[
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _mutedTextColor(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ปุ่มกรอกเร็ว — เดิมซ่อนอยู่ในเมนู "กรอกจาก" ที่คนส่วนใหญ่ไม่เคยกด
/// สมุดผู้ร่วมเดินทางอยู่ซ้ายสุด เป็นทางที่ใช้บ่อยที่สุดเมื่อจองให้คนอื่น
class _QuickFillRow extends StatelessWidget {
  final VoidCallback onUseSavedTraveller;
  final VoidCallback onUseProfile;
  final VoidCallback onUseWallet;

  const _QuickFillRow({
    required this.onUseSavedTraveller,
    required this.onUseProfile,
    required this.onUseWallet,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'กรอกเร็วจากข้อมูลที่บันทึกไว้',
          style: appFont(
            fontSize: AppText.sizeCaption,
            fontWeight: FontWeight.w700,
            color: _mutedTextColor(context),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QuickFillChip(
              icon: Icons.people_alt_rounded,
              label: 'สมุดผู้ร่วมเดินทาง',
              onTap: onUseSavedTraveller,
            ),
            _QuickFillChip(
              icon: Icons.account_circle_rounded,
              label: 'โปรไฟล์ของฉัน',
              onTap: onUseProfile,
            ),
            _QuickFillChip(
              icon: Icons.wallet_rounded,
              label: 'Wallet',
              onTap: onUseWallet,
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickFillChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickFillChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.tintOf(context, _softAccent),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: AppTheme.onTintOf(context, _softAccent),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onTintOf(context, _softAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// หัวข้อกลุ่มช่องในการ์ด — แบ่งฟอร์มยาวเป็นก้อนที่อ่านทีละเรื่อง
class _FormGroupLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FormGroupLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _softAccent),
          const SizedBox(width: 8),
          Text(
            text,
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w800,
              color: _premiumText(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(height: 1, color: _cardBorder(context))),
        ],
      ),
    );
  }
}

/// สองช่องเคียงกันเมื่อจอกว้างพอ (แท็บเล็ต) — จอโทรศัพท์เรียงลงมาทีละช่อง
/// เพราะช่องครึ่งจอบนมือถือเหลือที่ให้พิมพ์แค่ไม่กี่ตัว
class _FieldPair extends StatelessWidget {
  final Widget first;
  final Widget second;

  const _FieldPair({required this.first, required this.second});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 12), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

/// ตัวเลือกไม่กี่ค่า (คำนำหน้า / กรุ๊ปเลือด) เป็นปุ่มแตะเดียว แทน dropdown
/// ที่ต้องกดสองครั้ง ค่าจริงยังอยู่ใน controller เดิม การเติมจากโปรไฟล์จึงใช้ได้
/// เหมือนเดิม และยังเป็น FormField ที่ฟอร์มตรวจได้
class _ChoiceChipsField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final List<String> options;
  final String? Function(String) normalize;
  final String errorText;

  const _ChoiceChipsField({
    required this.label,
    required this.controller,
    required this.options,
    required this.normalize,
    required this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final current = normalize(controller.text);
        return FormField<String>(
          // สร้างใหม่เมื่อค่าเปลี่ยน — ข้อความเตือนเดิมหายทันทีที่เลือก
          key: ValueKey('$label-$current'),
          initialValue: current,
          validator: (_) => normalize(controller.text) == null ? errorText : null,
          builder: (field) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _labelStyle(context)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < options.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _ChoiceChip(
                          label: options[i],
                          selected: options[i] == current,
                          error: field.hasError,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.text = options[i];
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                if (field.hasError) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      field.errorText!,
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: AppTheme.errorColor,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool error;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.error,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? _softAccent : _fieldBackground(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: selected
                    ? _softAccent
                    : error
                    ? AppTheme.errorColor
                    : _cardBorder(context),
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _premiumText(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ฮาลาลเป็นคำถามใช่/ไม่ใช่ — สวิตช์บรรทัดเดียวพอ ไม่ต้องใช้ปุ่มใหญ่สองปุ่ม
class _HalalSwitchRow extends StatelessWidget {
  final ValueNotifier<bool> selected;

  const _HalalSwitchRow({required this.selected});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: selected,
      builder: (context, wantsHalal, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              selected.value = !wantsHalal;
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              decoration: BoxDecoration(
                color: _fieldBackground(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: _cardBorder(context)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.restaurant_rounded,
                    size: 19,
                    color: _mutedTextColor(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ต้องการอาหารฮาลาล',
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w700,
                        color: _premiumText(context),
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: wantsHalal,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      selected.value = value;
                    },
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

/// จุดขึ้นรถรายคน — ค่าเริ่มต้นคือจุดของการจอง เปลี่ยนเฉพาะคนที่ขึ้นคนละที่
class _PassengerPickupChips extends StatelessWidget {
  final List<dynamic> pickupPoints;
  final ValueNotifier<int?> selected;

  const _PassengerPickupChips({
    required this.pickupPoints,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: selected,
      builder: (context, selectedId, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('จุดขึ้นรถของคนนี้', style: _labelStyle(context)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: pickupPoints.map((raw) {
                final point = asMap(raw);
                final id = int.tryParse(point['id'].toString());
                final isSelected = id != null && id == selectedId;
                final time = textOf(point['pickup_time']).trim();
                final price = _asNum(point['price']);
                final meta = [
                  if (time.isNotEmpty) time,
                  if (price > 0) money(price),
                ].join(' · ');
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      selected.value = id;
                    },
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.selectedTint(context)
                            : _fieldBackground(context),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                          color: isSelected ? _softAccent : _cardBorder(context),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 16,
                            color: isSelected
                                ? _softAccent
                                : _mutedTextColor(context),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                text: _pickupLocationLabel(point),
                                children: [
                                  if (meta.isNotEmpty)
                                    TextSpan(
                                      text: '  $meta',
                                      style: appFont(
                                        fontWeight: FontWeight.w600,
                                        color: _mutedTextColor(context),
                                      ),
                                    ),
                                ],
                              ),
                              style: appFont(
                                fontSize: AppText.sizeLabel,
                                fontWeight: FontWeight.w700,
                                color: _premiumText(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (selectedId == null) ...[
              const SizedBox(height: 6),
              Text(
                'กรุณาเลือกจุดขึ้นรถ',
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.errorColor,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// กล่องเอกสารเดินทางของทริปต่างประเทศ — กรอบสีเตือนให้รู้ว่าต้องตรงหน้าพาสปอร์ต
///
/// ทริปที่ให้เลือก Border Pass ถามก่อนว่ามีพาสปอร์ตไหม แล้วค่อยกางช่องพาสปอร์ต
/// ให้คนที่ตอบว่ามี — ช่องที่ไม่ได้วาดก็ไม่ถูกตรวจ คนเลือก Border Pass จึงผ่านได้
class _PassportBox extends StatelessWidget {
  final _PassengerControllers controllers;
  final DateTime? minPassportExpiry;
  final bool offersBorderPass;

  const _PassportBox({
    required this.controllers,
    required this.minPassportExpiry,
    this.offersBorderPass = false,
  });

  @override
  Widget build(BuildContext context) {
    return _DocumentTintBox(
      icon: offersBorderPass
          ? Icons.badge_rounded
          : Icons.flight_takeoff_rounded,
      title: 'เอกสารเดินทาง',
      subtitle: offersBorderPass
          ? 'ทริปนี้ใช้พาสปอร์ต หรือ Border Pass ก็ได้'
          : 'กรอกให้ตรงกับหน้าพาสปอร์ตทุกตัวอักษร เพราะใช้ออกตั๋วเครื่องบิน',
      children: [
        if (!offersBorderPass)
          _passportFields()
        else ...[
          _ChoiceChipsField(
            label: 'มีพาสปอร์ตไหม',
            controller: controllers.travelDocument,
            options: const [_docPassportLabel, _docBorderPassLabel],
            normalize: _travelDocumentLabel,
            errorText: 'กรุณาเลือกว่ามีพาสปอร์ต หรือให้ทีมงานทำ Border Pass',
          ),
          ListenableBuilder(
            listenable: controllers.travelDocument,
            builder: (context, _) {
              return switch (_travelDocumentValue(
                controllers.travelDocument.text,
              )) {
                'passport' => Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _passportFields(),
                ),
                'border_pass' => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'ทีมงานยื่นทำ Border Pass จากเลขบัตรประชาชนด้านบน '
                    'วันเดินทางพกบัตรประชาชนตัวจริงมาด้วย',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: _mutedTextColor(context),
                    ),
                  ),
                ),
                _ => const SizedBox.shrink(),
              };
            },
          ),
        ],
      ],
    );
  }

  Widget _passportFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PremiumTextField(
          controller: controllers.nameEn,
          label: 'ชื่อ-สกุลภาษาอังกฤษ (ตามพาสปอร์ต)',
          hint: 'SOMCHAI JAIDEE',
          icon: Icons.badge_rounded,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z\s.'-]")),
            _UpperCaseFormatter(),
          ],
          validator: _requiredValidator(
            'กรุณากรอกชื่อ-สกุลภาษาอังกฤษตามพาสปอร์ต',
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        _PremiumTextField(
          controller: controllers.passportNo,
          label: 'เลขที่พาสปอร์ต',
          hint: 'AA1234567',
          icon: Icons.menu_book_rounded,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(20),
            _UpperCaseFormatter(),
          ],
          validator: (value) {
            final text = (value ?? '').trim();
            if (text.isEmpty) return 'กรุณากรอกเลขที่พาสปอร์ต';
            if (text.length < 5) return 'เลขที่พาสปอร์ตไม่ถูกต้อง';
            return null;
          },
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        _PremiumDatePicker(
          value: controllers.passportExpiresAt,
          label: 'วันหมดอายุพาสปอร์ต',
          icon: Icons.event_available_rounded,
          future: true,
          firstDate: minPassportExpiry,
          helpText: 'เลือกวันหมดอายุพาสปอร์ต',
          hint: 'แตะเพื่อเลือกวันหมดอายุ',
          validator: (date) {
            if (date == null) return 'กรุณาระบุวันหมดอายุพาสปอร์ต';
            final minimum = minPassportExpiry;
            if (minimum != null && date.isBefore(minimum)) {
              return 'พาสปอร์ตต้องเหลืออายุอย่างน้อย 6 เดือนนับจากวันเดินทาง';
            }
            return null;
          },
        ),
      ],
    );
  }
}

/// ทริปที่ทีมงานตรวจเอกสารฉบับจริงหน้างาน — ไม่มีช่องให้กรอก บอกให้รู้ว่าต้องพกมา
class _OnSiteDocumentNote extends StatelessWidget {
  const _OnSiteDocumentNote();

  @override
  Widget build(BuildContext context) {
    return const _DocumentTintBox(
      icon: Icons.badge_rounded,
      title: 'เอกสารเดินทาง',
      subtitle:
          'ไม่ต้องกรอกล่วงหน้า วันเดินทางนำเอกสารเดินทางฉบับจริงมาแสดงกับทีมงาน',
      children: [],
    );
  }
}

class _DocumentTintBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _DocumentTintBox({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final tone = AppTheme.onTintOf(context, AppTheme.warningColor);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningTint(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: tone),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w800,
                        color: _premiumText(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: appFont(
                        fontSize: AppText.sizeCaption,
                        color: _mutedTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...children,
          ],
        ],
      ),
    );
  }
}

/// ซื้อเป็นของขวัญ 🎁 — เปิดโหมดนี้แล้วข้ามฟอร์มผู้เดินทางทั้งหมด
/// ผู้ให้กรอกแค่ชื่อผู้รับ + คำอวยพร ข้อมูลผู้เดินทางจริงจะถูกเติมจาก
/// โปรไฟล์ของผู้รับตอนกดรับของขวัญในแอป
class GiftModeSection extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final TextEditingController recipientName;
  final TextEditingController fromName;
  final TextEditingController message;
  final int travelerCount;
  final bool isSeatSelectionMode;
  final VoidCallback onAddTraveler;
  final VoidCallback onRemoveTraveler;

  const GiftModeSection({
    super.key,
    required this.enabled,
    required this.onChanged,
    required this.recipientName,
    required this.fromName,
    required this.message,
    required this.travelerCount,
    required this.isSeatSelectionMode,
    required this.onAddTraveler,
    required this.onRemoveTraveler,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'ซื้อเป็นของขวัญ',
      icon: Icons.card_giftcard_rounded,
      trailing: Switch.adaptive(
        value: enabled,
        activeTrackColor: _softAccent,
        onChanged: (value) {
          HapticFeedback.selectionClick();
          onChanged(value);
        },
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: !enabled
            ? Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ซื้อทริปนี้ให้แฟน เพื่อน หรือคนพิเศษ — ชำระเงินแล้วรับโค้ดของขวัญส่งต่อให้ผู้รับกดรับในแอป',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    height: 1.6,
                    color: _mutedTextColor(context),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PremiumTextField(
                    controller: recipientName,
                    label: 'ชื่อผู้รับของขวัญ',
                    hint: 'เช่น น้องมายด์',
                    icon: Icons.favorite_rounded,
                    textCapitalization: TextCapitalization.words,
                    validator: _requiredValidator('กรุณากรอกชื่อผู้รับของขวัญ'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'จำนวนผู้เดินทาง',
                          style: _labelStyle(context),
                        ),
                      ),
                      if (isSeatSelectionMode)
                        _SeatDrivenTravelerCount(count: travelerCount)
                      else
                        TravelerCounter(
                          count: travelerCount,
                          onAdd: onAddTraveler,
                          onRemove: onRemoveTraveler,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PremiumTextField(
                    controller: fromName,
                    label: 'จากผู้ให้',
                    hint: 'ชื่อที่จะแสดงบนการ์ดของขวัญ',
                    icon: Icons.person_outline_rounded,
                    textCapitalization: TextCapitalization.words,
                    validator: _requiredValidator('กรุณากรอกชื่อผู้ให้'),
                  ),
                  const SizedBox(height: 16),
                  _PremiumTextField(
                    controller: message,
                    label: 'ข้อความถึงผู้รับ (ไม่บังคับ)',
                    hint: 'เช่น สุขสันต์วันเกิดนะ ขอให้เที่ยวให้สนุก!',
                    icon: Icons.mail_outline_rounded,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _softAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: _softAccent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'ไม่ต้องกรอกข้อมูลผู้เดินทาง — เมื่อผู้รับกดรับของขวัญ '
                      'ระบบจะดึงข้อมูลจากโปรไฟล์ของผู้รับให้อัตโนมัติ '
                      'หลังชำระเงินคุณจะได้โค้ดของขวัญไว้ส่งให้ผู้รับ',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        height: 1.6,
                        color: _premiumText(context),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
