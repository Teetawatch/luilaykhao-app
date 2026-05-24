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
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7E5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CounterButton(
            icon: Icons.remove_rounded,
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
                  style: GoogleFonts.anuphan(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: _premiumText(context),
                  ),
                ),
              ),
            ),
          ),
          _CounterButton(
            icon: Icons.add_rounded,
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
  final List<dynamic> pickupPoints;

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
    this.pickupPoints = const [],
  });

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
          ...List.generate(passengers.length, (index) {
            return _TravelerCard(
              index: index,
              controllers: passengers[index],
              isLast: index == passengers.length - 1,
              seatId: index < selectedSeatIds.length
                  ? selectedSeatIds[index]
                  : null,
              pickupPoints: pickupPoints,
              onUseProfile: () => onUseProfile(index),
              onUseWallet: () => onUseWallet(index),
            );
          }),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: passengers.length > 1
                ? Padding(
                    key: const ValueKey('group-notes'),
                    padding: const EdgeInsets.only(top: 4),
                    child: _PremiumTextField(
                      controller: groupNotes,
                      label: 'หมายเหตุกลุ่ม',
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

  const PricingSummaryCard({
    super.key,
    required this.pricing,
    required this.promoController,
    required this.expanded,
    required this.onExpandedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'สรุปราคา',
      icon: Icons.receipt_long_rounded,
      child: Column(
        children: [
          _PremiumTextField(
            controller: promoController,
            label: 'โค้ดส่วนลด',
            hint: 'เช่น NEWLUILAY',
            icon: Icons.local_offer_rounded,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
          ),
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
          if (pricing.addonsTotal > 0) ...[
            _PriceRow(
              label: 'ตัวเลือกเสริม',
              value: money(pricing.addonsTotal),
              valueColor: const Color(0xFFB45309),
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
                _PriceRow(
                  label: 'ส่วนลด',
                  value: '-${money(pricing.discount)}',
                  valueColor: _softAccent,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onExpandedChanged,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(
                    expanded ? 'ซ่อนรายละเอียดราคา' : 'ดูรายละเอียดราคา',
                    style: GoogleFonts.anuphan(
                      color: _softAccent,
                      fontSize: 13,
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
            label: 'รวมทั้งหมด',
            value: money(pricing.total),
            isTotal: true,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'โค้ดส่วนลดจะถูกตรวจสอบเมื่อส่งข้อมูลการจอง',
              style: GoogleFonts.anuphan(
                color: _mutedTextColor(context),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddonSelectionSection extends StatelessWidget {
  final List<_AddonOption> addons;
  final Set<int> selectedIndexes;
  final int travelerCount;
  final void Function(int index, bool selected) onChanged;

  const AddonSelectionSection({
    super.key,
    required this.addons,
    required this.selectedIndexes,
    required this.travelerCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedTotal = addons
        .where((addon) => selectedIndexes.contains(addon.index))
        .fold<num>(0, (sum, addon) => sum + addon.totalFor(travelerCount));

    return _SectionShell(
      title: 'ตัวเลือกเสริม',
      icon: Icons.add_task_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selectedTotal > 0) ...[
            _PriceRow(
              label: 'รายการเสริมที่เลือก',
              value: money(selectedTotal),
              valueColor: const Color(0xFFB45309),
            ),
            const SizedBox(height: 12),
          ],
          ...addons.map((addon) {
            final selected = selectedIndexes.contains(addon.index);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onChanged(addon.index, !selected),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFFFBEB)
                        : AppTheme.fieldSurface(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFF59E0B)
                          : AppTheme.border(context),
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: selected,
                        activeColor: const Color(0xFFF59E0B),
                        onChanged: (value) =>
                            onChanged(addon.index, value ?? false),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              addon.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.anuphan(
                                color: AppTheme.onSurface(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${money(addon.price)} ${addon.priceTypeLabel}',
                              style: GoogleFonts.anuphan(
                                color: AppTheme.mutedText(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '+${money(addon.totalFor(travelerCount))}',
                        style: GoogleFonts.anuphan(
                          color: const Color(0xFFB45309),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class TrustSignalsSection extends StatelessWidget {
  const TrustSignalsSection({super.key});

  @override
  Widget build(BuildContext context) {
    const signals = [
      _TrustSignal(Icons.lock_rounded, 'ชำระเงินปลอดภัย'),
      _TrustSignal(Icons.task_alt_rounded, 'ยืนยันการจองทันที'),
      _TrustSignal(Icons.support_agent_rounded, 'ติดต่อทีมงาน 24 ชม.'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: signals.map((signal) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppTheme.selectedTint(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _softAccent.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(signal.icon, size: 15, color: _softAccent),
              const SizedBox(width: 6),
              Text(
                signal.label,
                style: GoogleFonts.anuphan(
                  color: AppTheme.isDark(context)
                      ? AppTheme.accentColor
                      : const Color(0xFF126B5B),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
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
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;
          final vPad = isNarrow ? 8.0 : 10.0;
          final hPad = isNarrow ? 12.0 : 14.0;
          final btnHeight = isNarrow ? 42.0 : 46.0;
          final backSize = isNarrow ? 38.0 : 42.0;
          final priceFontSize = isNarrow ? 15.0 : 17.0;
          final labelFontSize = isNarrow ? 10.0 : 11.0;
          final btnFontSize = isNarrow ? 12.0 : 13.0;
          final iconSize = isNarrow ? 15.0 : 16.0;

          return Container(
            padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              border: Border(top: BorderSide(color: AppTheme.border(context))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 16,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'รวมทั้งหมด',
                        style: GoogleFonts.anuphan(
                          color: _mutedTextColor(context),
                          fontSize: labelFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        money(total),
                        style: GoogleFonts.anuphan(
                          color: _premiumText(context),
                          fontSize: priceFontSize,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (canGoBack) ...[
                  SizedBox(
                    width: backSize,
                    height: backSize,
                    child: IconButton(
                      onPressed: isSubmitting ? null : onBack,
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: _fieldBackground(context),
                        foregroundColor: _premiumText(context),
                        disabledForegroundColor:
                            _mutedTextColor(context).withValues(alpha: 0.4),
                        shape: const CircleBorder(),
                      ),
                      icon: Icon(Icons.arrow_back_rounded, size: iconSize + 2),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  flex: 2,
                  child: SizedBox(
                    height: btnHeight,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onPressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: _softAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFC8D5D1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(btnHeight / 2),
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
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      primaryLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.anuphan(
                                        fontWeight: FontWeight.w800,
                                        fontSize: btnFontSize,
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
          );
        },
      ),
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
      decoration: _premiumDecoration(context, radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _softAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _softAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.anuphan(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _premiumText(context),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: AppTheme.border(context).withValues(alpha: 0.5),
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
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_seat_rounded, color: _softAccent, size: 16),
          const SizedBox(width: 6),
          Text(
            count > 0 ? '$count คน' : 'เลือกที่นั่ง',
            style: GoogleFonts.anuphan(
              color: _softAccent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TravelerCard extends StatelessWidget {
  final int index;
  final _PassengerControllers controllers;
  final bool isLast;
  final String? seatId;
  final List<dynamic> pickupPoints;
  final VoidCallback onUseProfile;
  final VoidCallback onUseWallet;

  const _TravelerCard({
    required this.index,
    required this.controllers,
    required this.isLast,
    this.seatId,
    this.pickupPoints = const [],
    required this.onUseProfile,
    required this.onUseWallet,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _premiumText(context),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.anuphan(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ผู้เดินทาง',
                  style: GoogleFonts.anuphan(
                    fontWeight: FontWeight.w800,
                    color: _premiumText(context),
                    fontSize: 15,
                  ),
                ),
              ),
              if (seatId != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _fieldBackground(context),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _cardBorder(context)),
                  ),
                  child: Text(
                    'ที่นั่ง $seatId',
                    style: GoogleFonts.anuphan(
                      color: _mutedTextColor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'profile') onUseProfile();
                  if (val == 'wallet') onUseWallet();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        const Icon(Icons.account_circle_outlined,
                            size: 18, color: _softAccent),
                        const SizedBox(width: 10),
                        Text('ดึงข้อมูลโปรไฟล์',
                            style: GoogleFonts.anuphan(
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'wallet',
                    child: Row(
                      children: [
                        const Icon(Icons.wallet_rounded,
                            size: 18, color: _softAccent),
                        const SizedBox(width: 10),
                        Text('กรอกจาก Wallet',
                            style: GoogleFonts.anuphan(
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _softAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_note_rounded,
                          size: 16, color: _softAccent),
                      const SizedBox(width: 4),
                      Text(
                        'กรอกจาก',
                        style: GoogleFonts.anuphan(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _softAccent,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded,
                          size: 16, color: _softAccent),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Per-passenger pickup point selector
          if (pickupPoints.isNotEmpty) ...[
            const SizedBox(height: 12),
            ValueListenableBuilder<int?>(
              valueListenable: controllers.pickupPointId,
              builder: (context, selectedId, _) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _fieldBackground(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _cardBorder(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 16, color: _softAccent),
                          const SizedBox(width: 6),
                          Text(
                            'จุดขึ้นรถ',
                            style: GoogleFonts.anuphan(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _premiumText(context),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '*',
                            style: GoogleFonts.anuphan(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: pickupPoints.map((pt) {
                          final ptMap = asMap(pt);
                          final ptId = int.tryParse(ptMap['id'].toString());
                          final isSelected = selectedId == ptId;
                          final location = ptMap['pickup_location'] as String? ?? '';
                          final price = _asNum(ptMap['price']);
                          return GestureDetector(
                            onTap: () => controllers.pickupPointId.value = ptId,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF059669).withValues(alpha: 0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF059669)
                                      : _cardBorder(context),
                                  width: isSelected ? 2 : 1,
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
                                        ? const Color(0xFF059669)
                                        : _mutedTextColor(context),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    location,
                                    style: GoogleFonts.anuphan(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? const Color(0xFF059669)
                                          : _premiumText(context),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    money(price),
                                    style: GoogleFonts.anuphan(
                                      fontSize: 11,
                                      color: _mutedTextColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (selectedId == null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '* กรุณาเลือกจุดขึ้นรถ',
                          style: GoogleFonts.anuphan(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 360;
              final titleDropdown = _PremiumDropdown<String>(
                key: ValueKey('title-$index-${controllers.title.text}'),
                label: 'คำนำหน้า',
                icon: Icons.badge_outlined,
                value: _titleValue(controllers.title.text),
                items: _titleOptions.map((title) {
                  return DropdownMenuItem<String>(
                    value: title,
                    child: Text(title, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                validator: _requiredValidator('กรุณาเลือกคำนำหน้า'),
                onChanged: (value) {
                  controllers.title.text = value ?? '';
                },
              );
              final nameField = _PremiumTextField(
                controller: controllers.name,
                label: 'ชื่อ-นามสกุล',
                hint: 'สมชาย ลุยเลยเขา',
                icon: Icons.person_rounded,
                validator: _requiredValidator('กรุณากรอกชื่อ-นามสกุล'),
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
              );

              if (isCompact) {
                return Column(
                  children: [
                    titleDropdown,
                    const SizedBox(height: 12),
                    nameField,
                  ],
                );
              }

              return Row(
                children: [
                  SizedBox(width: 124, child: titleDropdown),
                  const SizedBox(width: 12),
                  Expanded(child: nameField),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 390;
              final nicknameField = _PremiumTextField(
                controller: controllers.nickname,
                label: 'ชื่อเล่น',
                hint: 'ชื่อเล่น',
                icon: Icons.face_rounded,
                validator: _requiredValidator('กรุณากรอกชื่อเล่น'),
                textInputAction: TextInputAction.next,
              );
              final phoneField = _PremiumTextField(
                controller: controllers.phone,
                label: 'เบอร์โทรศัพท์',
                hint: '081-234-5678',
                icon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: _phoneValidator('กรุณากรอกเบอร์โทรศัพท์'),
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.next,
              );
              final emailField = _PremiumTextField(
                controller: controllers.email,
                label: 'อีเมลผู้โดยสาร',
                hint: 'name@example.com',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: _optionalEmailValidator,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
              );

              if (isCompact) {
                return Column(
                  children: [
                    nicknameField,
                    const SizedBox(height: 12),
                    phoneField,
                    const SizedBox(height: 12),
                    emailField,
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: nicknameField),
                      const SizedBox(width: 12),
                      Expanded(child: phoneField),
                    ],
                  ),
                  const SizedBox(height: 12),
                  emailField,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 390;
              final idCardField = _PremiumTextField(
                controller: controllers.idCard,
                label: 'เลขบัตรประชาชน (สำหรับประกัน)',
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
              );
              final bloodDropdown = _PremiumDropdown<String>(
                key: ValueKey('blood-$index-${controllers.bloodGroup.text}'),
                label: 'กรุ๊ปเลือด',
                icon: Icons.bloodtype_rounded,
                value: _bloodGroupValue(controllers.bloodGroup.text),
                items: _bloodGroupOptions.map((group) {
                  return DropdownMenuItem<String>(
                    value: group,
                    child: Text(group, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                validator: _requiredValidator('กรุณาเลือกกรุ๊ปเลือด'),
                onChanged: (value) {
                  controllers.bloodGroup.text = value ?? '';
                },
              );

              if (isCompact) {
                return Column(
                  children: [
                    idCardField,
                    const SizedBox(height: 12),
                    bloodDropdown,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: idCardField),
                  const SizedBox(width: 12),
                  SizedBox(width: 132, child: bloodDropdown),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _HalalFoodSelector(
            selected: controllers.halalFood,
            onChanged: (value) => controllers.halalFood.value = value,
          ),
          const SizedBox(height: 12),
          _PremiumTextField(
            controller: controllers.allergies,
            label: 'การแพ้อาหาร / อื่นๆ',
            hint: 'เช่น แพ้อาหารทะเล, ไม่ทานเนื้อ, แพ้ถั่ว',
            icon: Icons.restaurant_menu_rounded,
            maxLines: 2,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 12),
          _PremiumTextField(
            controller: controllers.healthNotes,
            label: 'โรคประจำตัว / หมายเหตุสุขภาพ',
            hint: 'ไม่มี',
            icon: Icons.health_and_safety_rounded,
            maxLines: 2,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 16),
          Text(
            'ผู้ติดต่อฉุกเฉิน',
            style: GoogleFonts.anuphan(
              color: _premiumText(context),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 390;
              final contactField = _PremiumTextField(
                controller: controllers.emergencyContact,
                label: 'ชื่อผู้ติดต่อ',
                hint: 'ชื่อผู้ติดต่อ',
                icon: Icons.contact_emergency_rounded,
                validator: _requiredValidator('กรุณากรอกชื่อผู้ติดต่อฉุกเฉิน'),
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
              );
              final phoneField = _PremiumTextField(
                controller: controllers.emergencyPhone,
                label: 'เบอร์ติดต่อฉุกเฉิน',
                hint: '089-xxx-xxxx',
                icon: Icons.phone_enabled_rounded,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: _phoneValidator('กรุณากรอกเบอร์ติดต่อฉุกเฉิน'),
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.next,
              );

              if (isCompact) {
                return Column(
                  children: [
                    contactField,
                    const SizedBox(height: 12),
                    phoneField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: contactField),
                  const SizedBox(width: 12),
                  Expanded(child: phoneField),
                ],
              );
            },
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Divider(height: 1, color: _cardBorder(context)),
            ),
        ],
      ),
    );
  }
}
