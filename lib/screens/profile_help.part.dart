part of 'profile_screen.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: CustomScrollView(
        slivers: [
          const TravelSliverAppBar(title: 'ศูนย์ช่วยเหลือ'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                children: [
                  const SupportShortcuts(),
                  const SizedBox(height: 16),
                  _HelpTile(
                    icon: Icons.confirmation_number_outlined,
                    title: 'ตรวจสอบการจอง',
                    body: 'ค้นหาการจองและติดตามสถานะรถจากเลขการจอง',
                    onTap: () =>
                        _pushPremium(context, const BookingLookupScreen()),
                  ),
                  const SizedBox(height: 12),
                  _HelpTile(
                    icon: Icons.payment_outlined,
                    title: 'การชำระเงิน',
                    body: 'แนบสลิปและตรวจสอบยอดชำระจากหน้าการจองของฉัน',
                    onTap: () => _pushPremium(
                      context,
                      const ProfileBookingsScreen(title: 'การจองของฉัน'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _HelpTile(
                    icon: Icons.support_agent_outlined,
                    title: 'แชทกับทีมงาน',
                    body: 'พิมพ์คุยกับทีมงานลุยเลเขาได้เลย เราจะตอบกลับโดยเร็วที่สุด',
                    badge: context.watch<AppProvider>().supportUnread,
                    onTap: () =>
                        _pushPremium(context, const SupportChatScreen()),
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

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final app = context.read<AppProvider>();
    final user = app.user ?? {};
    final name = _cleanText(user['name']);
    final phone = _cleanText(user['phone']);
    if (name.isEmpty || phone.isEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('ข้อมูลไม่ครบ', style: appFont(fontWeight: FontWeight.w900)),
          content: Text(
            'กรุณาเพิ่มชื่อและเบอร์โทรศัพท์ในโปรไฟล์ก่อนติดต่อทีมงาน',
            style: appFont(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ปิด')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('แก้ไขโปรไฟล์'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        _pushPremium(context, EditProfileScreen(initialUser: app.user ?? {}));
      }
      return;
    }

    final payload = {
      'name': name,
      'phone': phone,
      'email': _cleanText(user['email']),
      'subject': _subject.text.trim(),
      'message': _message.text.trim(),
    };

    setState(() => _sending = true);
    try {
      await app.sendContact(payload);
      if (!mounted) return;
      _showSuccess(context, 'ส่งข้อความเรียบร้อยแล้ว');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user ?? {};

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            const TravelSliverAppBar(title: 'ติดต่อเรา'),
            SliverToBoxAdapter(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FormCard(
                        title: 'ข้อมูลติดต่อ',
                        subtitle: 'ข้อมูลนี้จะถูกส่งพร้อมคำถามของคุณ',
                        children: [
                          _InfoLine(
                            icon: Icons.person_outline,
                            text: _cleanText(user['name'], fallback: 'ลูกค้า'),
                          ),
                          const SizedBox(height: 8),
                          _InfoLine(
                            icon: Icons.phone_outlined,
                            text: _cleanText(
                              user['phone'],
                              fallback: 'ยังไม่มีเบอร์โทรศัพท์',
                            ),
                          ),
                          const SizedBox(height: 8),
                          _InfoLine(
                            icon: Icons.email_outlined,
                            text: _cleanText(
                              user['email'],
                              fallback: 'ยังไม่มีอีเมล',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _FormCard(
                        title: 'รายละเอียด',
                        children: [
                          _ProfileTextField(
                            controller: _subject,
                            label: 'หัวข้อ',
                            icon: Icons.subject_outlined,
                            validator: _required('กรุณากรอกหัวข้อ'),
                          ),
                          _ProfileTextField(
                            controller: _message,
                            label: 'ข้อความ',
                            icon: Icons.message_outlined,
                            maxLines: 5,
                            validator: _required('กรุณากรอกข้อความ'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(_sending ? 'กำลังส่ง...' : 'ส่งข้อความ'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SimpleInfoScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String body;

  const SimpleInfoScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: CustomScrollView(
        slivers: [
          TravelSliverAppBar(title: title),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: _EmptyProfileState(icon: icon, title: title, body: body),
            ),
          ),
        ],
      ),
    );
  }
}
