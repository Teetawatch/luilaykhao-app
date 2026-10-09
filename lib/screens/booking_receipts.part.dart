part of 'customer_app_screen.dart';

/// ใบเสร็จดิจิทัลของการจอง
///
/// ใบเสร็จออกอัตโนมัติตอนยืนยันการชำระ และแนบไปกับอีเมลอยู่แล้ว — แต่ลูกค้าที่
/// ต้องใช้ใบเสร็จมักต้องใช้ตอนที่หาอีเมลฉบับนั้นไม่เจอ (เบิกบริษัท, ยื่นภาษี)
/// ส่วนนี้จึงเป็นทางที่สอง ไม่ใช่เอกสารคนละใบ: ปุ่มพาไปที่ PDF/หน้าตรวจสอบ
/// ตัวเดียวกับในอีเมล
///
/// จองหลายคน: ใต้ใบรวมมี "ใบเสร็จแยกรายคน" ของทุกคน (ยอดหารเท่ากัน) ให้ผู้จอง
/// ส่งลิงก์ต่อให้เพื่อนที่ต้องใช้ใบในชื่อตัวเอง เพื่อนที่ผูกบัญชีไว้เปิดใบจอง
/// เดียวกันจะเห็นเฉพาะใบในชื่อตัวเอง (backend เป็นคนกรอง)
///
/// โหลดเองและเงียบสนิทเมื่อยังไม่มีใบเสร็จ (จองแล้วแต่ยังไม่จ่าย, สลิปยังรอ
/// ตรวจ) — ไม่ขึ้นหัวข้อว่างเปล่าให้ลูกค้าสงสัยว่าใบเสร็จหายไปไหน
class BookingReceiptsSection extends StatefulWidget {
  final String bookingRef;

  const BookingReceiptsSection({super.key, required this.bookingRef});

  @override
  State<BookingReceiptsSection> createState() => _BookingReceiptsSectionState();
}

class _BookingReceiptsSectionState extends State<BookingReceiptsSection> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    // คนที่ไม่ได้ผูกกับผู้เดินทางคนไหนในการจองจะได้ 403 ซึ่งแปลว่า "ไม่มีอะไร
    // ให้แสดง" ไม่ใช่ข้อผิดพลาด
    return context
        .read<AppProvider>()
        .bookingReceipts(widget.bookingRef)
        .catchError((_) => const <Map<String, dynamic>>[]);
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _share(Map<String, dynamic> receipt) async {
    final url = textOf(receipt['pdf_url']).isNotEmpty
        ? textOf(receipt['pdf_url'])
        : textOf(receipt['verify_url']);
    if (url.isEmpty) return;
    final name = textOf(receipt['holder_name']);
    await SharePlus.instance.share(
      ShareParams(
        text: name.isEmpty
            ? 'ใบเสร็จค่าทริป ${textOf(receipt['receipt_no'])}\n$url'
            : 'ใบเสร็จค่าทริปในชื่อ $name (${textOf(receipt['receipt_no'])})\n$url',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        final receipts = snap.data ?? const <Map<String, dynamic>>[];
        if (receipts.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const _SheetSectionTitle(
              icon: Icons.receipt_long_rounded,
              title: 'ใบเสร็จ',
            ),
            const SizedBox(height: 10),
            ...receipts.map(
              (receipt) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ReceiptCard(
                  receipt: receipt,
                  onOpen: _open,
                  onShare: _share,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Map<String, dynamic> receipt;
  final Future<void> Function(String url) onOpen;
  final Future<void> Function(Map<String, dynamic> receipt) onShare;

  const _ReceiptCard({
    required this.receipt,
    required this.onOpen,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final number = textOf(receipt['receipt_no']);
    final label = textOf(receipt['kind_label']);
    final pdfUrl = textOf(receipt['pdf_url']);
    final verifyUrl = textOf(receipt['verify_url']);
    final issuedAt = DateTime.tryParse(textOf(receipt['issued_at']))?.toLocal();
    final isPersonal = receipt['is_personal'] == true;
    final holderName = textOf(receipt['holder_name']);
    final personal = asList(receipt['personal']).map(asMap).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.isNotEmpty ? label : 'ใบเสร็จรับเงิน',
                      style: appFont(
                        fontSize: AppText.sizeBody,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    if (isPersonal && holderName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'ในชื่อ $holderName',
                        style: appFont(
                          fontSize: AppText.sizeLabel,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      [
                        number,
                        if (issuedAt != null)
                          'ออกเมื่อ ${thaiDateShort(issuedAt)}',
                      ].where((t) => t.isNotEmpty).join(' · '),
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                money(receipt['amount']),
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (pdfUrl.isNotEmpty)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onOpen(pdfUrl),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: Text(
                      'ดาวน์โหลด PDF',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (pdfUrl.isNotEmpty && verifyUrl.isNotEmpty)
                const SizedBox(width: 8),
              if (verifyUrl.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onOpen(verifyUrl),
                    icon: const Icon(Icons.verified_outlined, size: 18),
                    label: Text(
                      'หน้าตรวจสอบ',
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (personal.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'ใบเสร็จแยกรายคน',
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'ส่งให้เพื่อนที่ต้องใช้ใบเสร็จในชื่อตัวเองได้เลย',
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w500,
                color: AppTheme.mutedText(context),
              ),
            ),
            const SizedBox(height: 4),
            for (final item in personal)
              _PersonalReceiptRow(
                receipt: item,
                onOpen: onOpen,
                onShare: onShare,
              ),
          ],
        ],
      ),
    );
  }
}

/// ใบแยกของผู้เดินทางหนึ่งคน — แตะเปิด PDF, ปุ่มแชร์ส่งลิงก์ให้เจ้าตัว
class _PersonalReceiptRow extends StatelessWidget {
  final Map<String, dynamic> receipt;
  final Future<void> Function(String url) onOpen;
  final Future<void> Function(Map<String, dynamic> receipt) onShare;

  const _PersonalReceiptRow({
    required this.receipt,
    required this.onOpen,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final name = textOf(receipt['holder_name']);
    final pdfUrl = textOf(receipt['pdf_url']);
    final url = pdfUrl.isNotEmpty ? pdfUrl : textOf(receipt['verify_url']);

    return InkWell(
      onTap: url.isEmpty ? null : () => onOpen(url),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 18,
              color: AppTheme.mutedText(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name.isNotEmpty ? name : textOf(receipt['receipt_no']),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ),
            Text(
              money(receipt['amount']),
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface(context),
              ),
            ),
            IconButton(
              tooltip: 'ส่งใบเสร็จให้ $name',
              visualDensity: VisualDensity.compact,
              onPressed: url.isEmpty ? null : () => onShare(receipt),
              icon: const Icon(
                Icons.ios_share_rounded,
                size: 18,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
