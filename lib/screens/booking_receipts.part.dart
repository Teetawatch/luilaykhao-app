part of 'customer_app_screen.dart';

/// ใบเสร็จดิจิทัลของการจอง
///
/// ใบเสร็จออกอัตโนมัติตอนยืนยันการชำระ และแนบไปกับอีเมลอยู่แล้ว — แต่ลูกค้าที่
/// ต้องใช้ใบเสร็จมักต้องใช้ตอนที่หาอีเมลฉบับนั้นไม่เจอ (เบิกบริษัท, ยื่นภาษี)
/// ส่วนนี้จึงเป็นทางที่สอง ไม่ใช่เอกสารคนละใบ: ปุ่มพาไปที่ PDF/หน้าตรวจสอบ
/// ตัวเดียวกับในอีเมล
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
    // ไม่ใช่ทุกคนในคณะที่มีสิทธิ์ดูใบเสร็จ (เฉพาะผู้จอง) — เพื่อนที่เปิดใบจอง
    // เดียวกันจะได้ 403 ซึ่งแปลว่า "ไม่มีอะไรให้แสดง" ไม่ใช่ข้อผิดพลาด
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
                child: _ReceiptCard(receipt: receipt, onOpen: _open),
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

  const _ReceiptCard({required this.receipt, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final number = textOf(receipt['receipt_no']);
    final label = textOf(receipt['kind_label']);
    final pdfUrl = textOf(receipt['pdf_url']);
    final verifyUrl = textOf(receipt['verify_url']);
    final issuedAt = DateTime.tryParse(textOf(receipt['issued_at']))?.toLocal();

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
                    const SizedBox(height: 2),
                    Text(
                      [
                        number,
                        if (issuedAt != null) 'ออกเมื่อ ${thaiDateShort(issuedAt)}',
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
        ],
      ),
    );
  }
}
