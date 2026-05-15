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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                statusText,
                                style: GoogleFonts.anuphan(
                                  color: Colors.white,
                                  fontSize: 11,
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
                  style: GoogleFonts.anuphan(
                    color: AppTheme.onSurface(context),
                    fontSize: 18,
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
                      text: dateText(schedule['departure_date']),
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
                    borderRadius: BorderRadius.circular(16),
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
                        style: GoogleFonts.anuphan(
                          color: AppTheme.mutedText(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        money(booking['total_amount']),
                        style: GoogleFonts.anuphan(
                          color: _accent,
                          fontSize: 18,
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

  const _PaymentTypeSection({
    required this.booking,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final count = _installmentCount(booking);
    final perInstallment = _installmentAmount(booking);

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
          const SizedBox(height: 10),
          _ChoiceTile(
            selected: value == 'installment',
            icon: Icons.calendar_month_rounded,
            title: 'ผ่อนชำระ $count งวด',
            subtitle:
                'งวดแรก ${money(perInstallment)} · ทุก ${_installmentInterval(booking)} วัน',
            onTap: () => onChanged('installment'),
          ),
          if (value == 'installment') ...[
            const SizedBox(height: 14),
            ..._installmentSchedule(booking).map(
              (row) => _InstallmentRow(row: row),
            ),
          ],
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
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _accent.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
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
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _displayPromptPayId,
            style: GoogleFonts.anuphan(
              color: AppTheme.onSurface(context),
              fontSize: 15,
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
                  borderRadius: BorderRadius.circular(22),
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
                style: GoogleFonts.anuphan(
                  fontSize: 13,
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
                      : DateFormat('d MMM yyyy', 'th_TH').format(date!),
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
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontSize: 12,
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

class _SlipUploadSection extends StatelessWidget {
  final XFile? image;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _SlipUploadSection({
    required this.image,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = image != null;
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
              _RequiredBadge(done: hasImage),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onPick,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: hasImage ? 280 : 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: hasImage ? Colors.black : AppTheme.fieldSurface(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: hasImage
                      ? _accent
                      : AppTheme.border(context),
                  width: hasImage ? 1.5 : 1,
                ),
              ),
              child: hasImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(21),
                          child: Image.file(
                            File(image!.path),
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: IconButton.filled(
                            onPressed: onRemove,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.errorColor,
                            ),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'พร้อมส่งตรวจสอบ',
                                  style: GoogleFonts.anuphan(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _accent.withValues(alpha: 0.20),
                            ),
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
                          style: GoogleFonts.anuphan(
                            color: AppTheme.onSurface(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'ต้องแนบทุกครั้งก่อนยืนยันการชำระเงิน',
                          style: GoogleFonts.anuphan(
                            color: AppTheme.mutedText(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Completed / check-in card
// ─────────────────────────────────────────────────────────────────────────────

