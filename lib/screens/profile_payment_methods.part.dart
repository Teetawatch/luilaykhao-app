part of 'profile_screen.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: const CustomScrollView(
        slivers: [
          TravelSliverAppBar(title: 'วิธีการชำระเงิน'),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                children: [
                  _PaymentMethodCard(
                    icon: Icons.qr_code_2_outlined,
                    title: 'QR PromptPay',
                    body:
                        'เลือกชำระเงินจากรายการจอง ระบบจะสร้าง QR ตามยอดชำระจริงและให้แนบสลิปเพื่อยืนยัน',
                  ),
                  SizedBox(height: 12),
                  _PaymentMethodCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'แนบสลิปโอนเงิน',
                    body:
                        'หลังโอนเงินแล้ว กรุณาแนบสลิปในหน้าชำระเงิน ระบบจะบันทึกหลักฐานไว้กับเลขการจอง',
                  ),
                  SizedBox(height: 12),
                  _PaymentMethodCard(
                    icon: Icons.payments_outlined,
                    title: 'ผ่อนชำระ',
                    body:
                        'ถ้ารายการจองรองรับ ระบบจะแสดงตัวเลือกแบ่งชำระในหน้าชำระเงินอัตโนมัติ',
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

