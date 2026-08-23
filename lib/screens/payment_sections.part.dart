part of 'payment_screen.dart';

class _BookingSummaryCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic> trip;
  final Map<String, dynamic> schedule;

  const _BookingSummaryCard({
    required this.booking,
    required this.trip,
    required this.schedule,
  });

  @override
  Widget build(BuildContext context) {
    final image = ApiConfig.mediaUrl(
      trip['thumbnail_image'] ?? trip['cover_image'],
    );
    final passengers = asList(booking['passengers']);
    final seats = asList(booking['seats']);
    final selectedAddons = asList(booking['selected_addons']).map(asMap).toList();
    final selectedRentals = asList(booking['selected_rentals']).map(asMap).toList();
    final pickupPoint = asMap(booking['pickup_point']);
    final pickupText = textOf(
      pickupPoint['pickup_location'] ??
          pickupPoint['region_label'] ??
          booking['pickup_region'],
      'ระบุก่อนเดินทาง',
    );
    final statusText = _statusLabel(textOf(booking['status']));
    final statusColor = _statusColor(textOf(booking['status']));

    return _SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Trip hero image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
            child: AspectRatio(
              aspectRatio: 16 / 8,
              child: image.isEmpty
                  ? Container(
                      color: AppTheme.subtleSurface(context),
                      child: const Icon(
                        Icons.landscape_rounded,
                        color: _accent,
                        size: 48,
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
                        // gradient overlay for status badge readability
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.90),
                                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                              ),
                              child: Text(
                                statusText,
                                style: appFont(
                                  color: Colors.white,
                                  fontSize: AppText.sizeCaption,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trip title + status (no image case)
                if (image.isEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _StatusBadge(
                      label: statusText,
                      color: statusColor,
                    ),
                  ),
                Text(
                  textOf(trip['title'], 'รายละเอียดการจอง'),
                  style: appFont(
                    color: AppTheme.onSurface(context),
                    fontSize: AppText.sizeTitle,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                // Info pills
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      context: context,
                      icon: Icons.confirmation_number_outlined,
                      text: textOf(booking['booking_ref']),
                    ),
                    _InfoPill(
                      context: context,
                      icon: Icons.calendar_today_rounded,
                      text: departureText(schedule),
                    ),
                    _InfoPill(
                      context: context,
                      icon: Icons.group_rounded,
                      text: '${passengers.length} ท่าน',
                    ),
                    if (seats.isNotEmpty)
                      _InfoPill(
                        context: context,
                        icon: Icons.airline_seat_recline_extra_rounded,
                        text: seats
                            .map((s) => textOf(asMap(s)['seat_id']))
                            .join(', '),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const _Divider(),
                const SizedBox(height: 12),
                _SummaryRow(
                  icon: Icons.location_on_outlined,
                  label: 'จุดขึ้นรถ',
                  value: pickupText,
                ),
                if (selectedAddons.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...selectedAddons.map((addon) {
                    final qty = textOf(addon['quantity'], '1');
                    final name = textOf(addon['name'], 'ตัวเลือกเสริม');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SummaryRow(
                        icon: Icons.add_task_rounded,
                        label: qty == '1' ? name : '$name ×$qty',
                        value: money(addon['total_price']),
                        valueColor: AppTheme.warningColor,
                      ),
                    );
                  }),
                ],
                if (selectedRentals.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...selectedRentals.map((rental) {
                    final qty = textOf(rental['quantity'], '1');
                    final name = textOf(rental['name'], 'อุปกรณ์เช่า');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SummaryRow(
                        icon: Icons.backpack_rounded,
                        label: qty == '1' ? name : '$name ×$qty',
                        value: money(rental['total_price']),
                        valueColor: const Color(0xFF0369A1),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withValues(
                      alpha: AppTheme.isDark(context) ? 0.15 : 0.07,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: _accent.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        color: _accent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'ยอดรวมทั้งหมด',
                        style: appFont(
                          color: AppTheme.mutedText(context),
                          fontWeight: FontWeight.w700,
                          fontSize: AppText.sizeLabel,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        money(booking['total_amount']),
                        style: appFont(
                          color: _accent,
                          fontSize: AppText.sizeTitle,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Payment type section
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentTypeSection extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String value;
  final ValueChanged<String> onChanged;

  /// จำนวนงวดที่ลูกค้าเลือกไว้ (null = ใช้ค่าที่เซิร์ฟเวอร์แนะนำ)
  final int? installmentCount;
  final ValueChanged<int> onInstallmentCountChanged;

  const _PaymentTypeSection({
    required this.booking,
    required this.value,
    required this.onChanged,
    required this.installmentCount,
    required this.onInstallmentCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final count = _installmentCount(booking, preferred: installmentCount);
    final perInstallment = _installmentAmount(booking, preferred: installmentCount);
    final countChoices = _availableInstallmentCounts(booking);
    final finalDue = _installmentFinalDueDate(booking, preferred: installmentCount);
    final leadDays = _installmentLeadDays(booking);
    final installmentOn = _installmentAvailable(booking);
    final installmentBlocked = _installmentNotAvailable(booking);
    final depositOn = _depositAvailable(booking);
    final deposit = _depositAmount(booking);
    final balance = _balanceAmount(booking);
    final splitOn = _splitAvailable(booking);
    final splitShare = _splitOwnShare(booking);
    final splitFriends = _splitPassengerCount(booking) - 1;
    final days = _daysUntilTrip(booking);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.credit_card_rounded,
            title: 'รูปแบบการชำระ',
          ),
          const SizedBox(height: 14),
          _ChoiceTile(
            selected: value == 'full',
            icon: Icons.payments_rounded,
            title: 'ชำระเต็มจำนวน',
            subtitle: 'ยอดชำระ ${money(booking['total_amount'])}',
            onTap: () => onChanged('full'),
          ),
          if (depositOn) ...[
            const SizedBox(height: 10),
            _ChoiceTile(
              selected: value == 'deposit',
              icon: Icons.savings_rounded,
              title: 'จ่ายมัดจำ ${money(deposit)}',
              subtitle: 'ส่วนที่เหลือ ${money(balance)} · ก่อนเดินทาง 15 วัน',
              onTap: () => onChanged('deposit'),
            ),
          ],
          // Show installment tile: enabled when available, disabled-with-banner when blocked
          if (installmentOn || installmentBlocked) ...[
            const SizedBox(height: 10),
            if (installmentBlocked)
              _DisabledInstallmentTile(days: days, leadDays: leadDays)
            else
              _ChoiceTile(
                selected: value == 'installment',
                icon: Icons.calendar_month_rounded,
                title: 'ผ่อนชำระ $count งวด',
                subtitle: finalDue.isEmpty
                    ? 'งวดละ ${money(perInstallment)}'
                    : 'งวดละ ${money(perInstallment)} · ปิดยอด ${dateText(finalDue)}',
                onTap: () => onChanged('installment'),
              ),
          ],
          // แบ่งจ่ายกับเพื่อน: เจ้าของจ่ายส่วนตัวเองตอนนี้ ที่นั่งยืนยันทันที
          // ส่วนของเพื่อนส่งลิงก์/แจ้งเตือนให้จ่ายเองภายหลัง
          if (splitOn) ...[
            const SizedBox(height: 10),
            _ChoiceTile(
              selected: value == 'split',
              icon: Icons.call_split_rounded,
              title: 'แบ่งจ่ายกับเพื่อน',
              subtitle:
                  'จ่ายส่วนของคุณ ${money(splitShare)} · เพื่อนอีก $splitFriends คนจ่ายส่วนตัวเอง',
              onTap: () => onChanged('split'),
            ),
          ],
          if (value == 'installment' && !installmentBlocked) ...[
            if (countChoices.length > 1) ...[
              const SizedBox(height: 14),
              _InstallmentCountPicker(
                choices: countChoices,
                selected: count,
                onSelected: onInstallmentCountChanged,
              ),
            ],
            const SizedBox(height: 14),
            ..._installmentSchedule(booking, preferred: installmentCount).map(
              (row) => _InstallmentRow(row: row),
            ),
            const SizedBox(height: 4),
            _InstallmentAutoNote(leadDays: leadDays),
          ],
          if (value == 'split') ...[
            const SizedBox(height: 14),
            _SplitBreakdown(booking: booking),
          ],
          if (value == 'deposit') ...[
            const SizedBox(height: 14),
            _DepositBreakdown(booking: booking),
            const SizedBox(height: 12),
            _DepositCancellationClause(booking: booking),
          ],
        ],
      ),
    );
  }
}

class _DisabledInstallmentTile extends StatelessWidget {
  final int days;
  final int leadDays;

  const _DisabledInstallmentTile({required this.days, required this.leadDays});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.border(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    size: 20,
                    color: AppTheme.mutedText(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'ผ่อนชำระ',
                            style: TextStyle(
                              fontSize: AppText.sizeSubtitle,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                            ),
                            child: const Text(
                              'ไม่พร้อมใช้',
                              style: TextStyle(
                                fontSize: AppText.sizeCaption,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ทริปนี้ใกล้เกินไปสำหรับการผ่อน',
                        style: TextStyle(
                          fontSize: AppText.sizeCaption,
                          color: AppTheme.border(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFFD97706),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ทริปจะเริ่มในอีก $days วัน และยอดผ่อนต้องปิดก่อนเดินทาง $leadDays วัน จึงเหลือเวลาไม่พอแบ่งงวด',
                    style: const TextStyle(
                      fontSize: AppText.sizeCaption,
                      color: Color(0xFF92400E),
                      height: 1.4,
                    ),
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

class _DepositBreakdown extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _DepositBreakdown({required this.booking});

  @override
  Widget build(BuildContext context) {
    final total = booking['total_amount'];
    final deposit = _depositAmount(booking);
    final balance = _balanceAmount(booking);
    final dueText = _balanceDueDateText(booking);
    final percent = _depositPercentApprox(booking);
    final tierDiscount = _depositTierDiscountPercent(booking);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _accent.withValues(
          alpha: AppTheme.isDark(context) ? 0.14 : 0.06,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: _accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DepositBreakdownRow(
            step: '1',
            label: 'ยอดรวมทั้งหมด',
            value: money(total),
            highlight: false,
          ),
          const SizedBox(height: 8),
          _DepositBreakdownRow(
            step: '2',
            label: 'ชำระมัดจำตอนนี้${percent > 0 ? ' (~$percent%)' : ''}',
            value: money(deposit),
            highlight: true,
          ),
          const SizedBox(height: 8),
          _DepositBreakdownRow(
            step: '3',
            label: 'ส่วนที่เหลือ · ภายใน $dueText',
            value: money(balance),
            highlight: false,
            warn: true,
          ),
          if (tierDiscount > 0) ...[
            const SizedBox(height: 10),
            Text(
              'ลดมัดจำให้แล้ว $tierDiscount% ตามระดับสมาชิกของคุณ',
              style: const TextStyle(
                fontFamily: 'anuphan',
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
                color: _accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// สรุปขั้นตอนการแบ่งจ่ายกับเพื่อน ก่อนเจ้าของกดชำระส่วนของตัวเอง
class _SplitBreakdown extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _SplitBreakdown({required this.booking});

  @override
  Widget build(BuildContext context) {
    final total = booking['total_amount'];
    final ownShare = _splitOwnShare(booking);
    final friends = _splitPassengerCount(booking) - 1;
    final remainder = _asNum(total) - ownShare;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _accent.withValues(
          alpha: AppTheme.isDark(context) ? 0.14 : 0.06,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: _accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DepositBreakdownRow(
            step: '1',
            label: 'ยอดรวมทั้งหมด',
            value: money(total),
            highlight: false,
          ),
          const SizedBox(height: 8),
          _DepositBreakdownRow(
            step: '2',
            label: 'ชำระส่วนของคุณตอนนี้ · ที่นั่งยืนยันทันที',
            value: money(ownShare),
            highlight: true,
          ),
          const SizedBox(height: 8),
          _DepositBreakdownRow(
            step: '3',
            label: 'เพื่อนอีก $friends คนจ่ายส่วนตัวเองผ่านแอป/ลิงก์',
            value: money(remainder),
            highlight: false,
            warn: true,
          ),
        ],
      ),
    );
  }
}

class _DepositBreakdownRow extends StatelessWidget {
  final String step;
  final String label;
  final String value;
  final bool highlight;
  final bool warn;

  const _DepositBreakdownRow({
    required this.step,
    required this.label,
    required this.value,
    required this.highlight,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = warn ? AppTheme.warningColor : _accent;
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: highlight ? _accent : accent.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: appFont(
              color: highlight ? Colors.white : accent,
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: appFont(
              color: AppTheme.mutedText(context),
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: appFont(
            color: highlight
                ? _accent
                : (warn ? AppTheme.warningColor : AppTheme.onSurface(context)),
            fontSize: highlight ? 16 : 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _DepositCancellationClause extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _DepositCancellationClause({required this.booking});

  @override
  Widget build(BuildContext context) {
    final dueText = _balanceDueDateText(booking);
    const danger = AppTheme.errorColor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: danger.withValues(
          alpha: AppTheme.isDark(context) ? 0.18 : 0.06,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: danger.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: danger,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(Icons.gavel_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เงื่อนไขสำคัญ · กรุณาอ่าน',
                  style: appFont(
                    color: danger,
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'กรณีขอยกเลิกการเดินทาง ทางทริปขอสงวนสิทธิ์ไม่คืนเงินมัดจำทุกกรณี '
                  'เนื่องจากมีการนำไปสำรองจ่ายค่าอุทยานและยานพาหนะล่วงหน้า',
                  style: appFont(
                    color: AppTheme.onSurface(context),
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: danger.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, color: danger, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'ต้องชำระยอดส่วนที่เหลือก่อนเดินทาง 15 วัน (ภายใน $dueText)',
                          style: appFont(
                            color: AppTheme.onSurface(context),
                            fontSize: AppText.sizeCaption,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Payment method section
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentMethodSection extends StatelessWidget {
  final String value;
  final num amount;
  final String qrPayload;
  final GlobalKey qrKey;
  final bool downloadingQr;
  final ValueChanged<String> onChanged;
  final VoidCallback onDownloadQr;
  final VoidCallback onCopyAmount;
  final VoidCallback onCopyAccount;

  const _PaymentMethodSection({
    required this.value,
    required this.amount,
    required this.qrPayload,
    required this.qrKey,
    required this.downloadingQr,
    required this.onChanged,
    required this.onDownloadQr,
    required this.onCopyAmount,
    required this.onCopyAccount,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.account_balance_wallet_rounded,
            title: 'ช่องทางชำระเงิน',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ChoiceTile(
                  selected: value == 'promptpay',
                  icon: Icons.qr_code_2_rounded,
                  title: 'QR PromptPay',
                  subtitle: 'สแกนจ่ายผ่านแอปธนาคาร',
                  compact: true,
                  onTap: () => onChanged('promptpay'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoiceTile(
                  selected: value == 'mobile_banking',
                  icon: Icons.account_balance_rounded,
                  title: 'โอนธนาคาร',
                  subtitle: 'โอนและระบุเวลาโอน',
                  compact: true,
                  onTap: () => onChanged('mobile_banking'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (value == 'promptpay')
            _PromptPayPanel(
              qrPayload: qrPayload,
              qrKey: qrKey,
              downloadingQr: downloadingQr,
              onDownload: onDownloadQr,
            )
          else
            const _BankTransferPanel(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CopyButton(
                  icon: Icons.content_copy_rounded,
                  label: 'คัดลอกยอด ${money(amount)}',
                  onPressed: onCopyAmount,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CopyButton(
                  icon: Icons.numbers_rounded,
                  label: value == 'promptpay'
                      ? 'คัดลอกพร้อมเพย์'
                      : 'คัดลอกบัญชี',
                  onPressed: onCopyAccount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromptPayPanel extends StatelessWidget {
  final String qrPayload;
  final GlobalKey qrKey;
  final bool downloadingQr;
  final VoidCallback onDownload;

  const _PromptPayPanel({
    required this.qrPayload,
    required this.qrKey,
    required this.downloadingQr,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          RepaintBoundary(
            key: qrKey,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                border: Border.all(
                  color: _accent.withValues(alpha: 0.18),
                ),
              ),
              child: QrImageView(
                data: qrPayload,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'พร้อมเพย์ / e-Wallet',
            style: appFont(
              color: AppTheme.mutedText(context),
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _displayPromptPayId,
            style: appFont(
              color: AppTheme.onSurface(context),
              fontSize: AppText.sizeSubtitle,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 220,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: downloadingQr ? null : onDownload,
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: BorderSide(color: _accent.withValues(alpha: 0.30)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              icon: downloadingQr
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _accent,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 20),
              label: Text(
                downloadingQr ? 'กำลังดาวน์โหลด' : 'ดาวน์โหลด QR CODE',
                style: appFont(
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankTransferPanel extends StatelessWidget {
  const _BankTransferPanel();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _BankInfoRow(label: 'ธนาคาร', value: 'กสิกรไทย (KBANK)'),
        SizedBox(height: 8),
        _BankInfoRow(label: 'ชื่อบัญชี', value: 'นายธีร์ธวัช พิพัฒน์เดชธน'),
        SizedBox(height: 8),
        _BankInfoRow(label: 'เลขที่บัญชี', value: _bankAccount),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transfer time section
// ─────────────────────────────────────────────────────────────────────────────

class _TransferTimeSection extends StatelessWidget {
  final DateTime? date;
  final TimeOfDay? time;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  const _TransferTimeSection({
    required this.date,
    required this.time,
    required this.onPickDate,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.receipt_long_rounded,
            title: 'ข้อมูลจากสลิป',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  icon: Icons.calendar_today_rounded,
                  label: 'วันที่โอน',
                  value: date == null
                      ? 'เลือกวันที่'
                      : thaiDateShort(date!),
                  filled: date != null,
                  onTap: onPickDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickerTile(
                  icon: Icons.schedule_rounded,
                  label: 'เวลาที่โอน',
                  value: time == null ? 'เลือกเวลา' : time!.format(context),
                  filled: time != null,
                  onTap: onPickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'กรอกวันและเวลาตามสลิปโอนเงิน เพื่อให้ทีมงานตรวจสอบได้รวดเร็ว',
            style: appFont(
              color: AppTheme.mutedText(context),
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slip upload section
// ─────────────────────────────────────────────────────────────────────────────

class _SlipUploadSection extends StatefulWidget {
  final XFile? image;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _SlipUploadSection({
    required this.image,
    required this.onPick,
    required this.onRemove,
  });

  @override
  State<_SlipUploadSection> createState() => _SlipUploadSectionState();
}

class _SlipUploadSectionState extends State<_SlipUploadSection> {
  // Slips come in every shape (bank app screenshot, cropped photo, receipt
  // scan). We read the real pixel size so the preview box can take the image's
  // own aspect ratio instead of letterboxing it inside a fixed frame.
  static const double _minPreview = 200;
  static const double _maxPreview = 380;

  String? _measuredPath;
  double? _ratio;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  @override
  void didUpdateWidget(covariant _SlipUploadSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image?.path != oldWidget.image?.path) _measure();
  }

  Future<void> _measure() async {
    final path = widget.image?.path;
    if (path == _measuredPath) return;
    _measuredPath = path;
    _ratio = null;
    if (path == null) return;
    try {
      final decoded = await decodeImageFromList(await File(path).readAsBytes());
      if (!mounted || widget.image?.path != path) return;
      setState(() => _ratio = decoded.width / decoded.height);
      decoded.dispose();
    } catch (_) {
      // Fall back to the default frame height; the image still renders.
    }
  }

  void _openFullScreen(String path) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(
                  icon: Icons.upload_file_rounded,
                  title: 'แนบรูปภาพสลิป',
                ),
              ),
              _RequiredBadge(done: image != null),
            ],
          ),
          const SizedBox(height: 14),
          if (image == null) _buildEmpty(context) else _buildPreview(context, image),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      onTap: widget.onPick,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.fieldSurface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: _accent.withValues(alpha: 0.20)),
              ),
              child: const Icon(
                Icons.cloud_upload_rounded,
                color: _accent,
                size: 30,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'แตะเพื่อแนบรูปภาพสลิป',
              style: appFont(
                color: AppTheme.onSurface(context),
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'ต้องแนบทุกครั้งก่อนยืนยันการชำระเงิน',
              style: appFont(
                color: AppTheme.mutedText(context),
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context, XFile image) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final ratio = _ratio;
            final natural = ratio == null || ratio <= 0
                ? _maxPreview
                : constraints.maxWidth / ratio;
            final height = natural.clamp(_minPreview, _maxPreview);
            // A tall slip gets cropped from the top rather than shrunk into a
            // thin strip with empty bars either side.
            final cropped = natural > _maxPreview;
            return GestureDetector(
              onTap: () => _openFullScreen(image.path),
              child: Container(
                height: height,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppTheme.fieldSurface(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: _accent.withValues(alpha: 0.45)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.file(
                        File(image.path),
                        fit: cropped ? BoxFit.cover : BoxFit.contain,
                        alignment: cropped
                            ? Alignment.topCenter
                            : Alignment.center,
                        errorBuilder: (_, _, _) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image_rounded,
                                size: 28,
                                color: AppTheme.mutedText(context),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'เปิดรูปสลิปไม่ได้ ลองแนบใหม่อีกครั้ง',
                                style: appFont(
                                  color: AppTheme.mutedText(context),
                                  fontSize: AppText.sizeCaption,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.slate900.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.zoom_in_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'ดูเต็มจอ',
                              style: appFont(
                                color: Colors.white,
                                fontSize: AppText.sizeCaption,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: _accent, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'แนบสลิปแล้ว พร้อมส่งตรวจสอบ',
                style: appFont(
                  color: _accent,
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SlipAction(
                icon: Icons.autorenew_rounded,
                label: 'เปลี่ยนรูป',
                onTap: widget.onPick,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SlipAction(
                icon: Icons.delete_outline_rounded,
                label: 'ลบรูป',
                danger: true,
                onTap: widget.onRemove,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SlipAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback onTap;

  const _SlipAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppTheme.errorColor : AppTheme.onSurface(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: danger
              ? AppTheme.dangerTint(context)
              : AppTheme.fieldSurface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: danger
                ? AppTheme.errorColor.withValues(alpha: 0.25)
                : AppTheme.border(context),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  color: color,
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Completed / check-in card
// ─────────────────────────────────────────────────────────────────────────────

