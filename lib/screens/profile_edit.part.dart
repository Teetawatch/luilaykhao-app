part of 'profile_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> initialUser;

  const EditProfileScreen({super.key, required this.initialUser});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _title;
  late final TextEditingController _nickname;
  late final TextEditingController _idCard;
  late final TextEditingController _bloodGroup;
  late final TextEditingController _emergencyContact;
  late final TextEditingController _emergencyPhone;
  late final TextEditingController _allergies;
  late final TextEditingController _healthNotes;
  late final TextEditingController _password;
  late final TextEditingController _passwordConfirmation;
  final _imagePicker = ImagePicker();
  String? _avatarImagePath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.initialUser;
    _name = TextEditingController(text: _cleanText(user['name']));
    _phone = TextEditingController(text: _cleanText(user['phone']));
    _title = TextEditingController(text: _cleanText(user['title']));
    _nickname = TextEditingController(text: _cleanText(user['nickname']));
    _idCard = TextEditingController(text: _cleanText(user['id_card']));
    _bloodGroup = TextEditingController(text: _cleanText(user['blood_group']));
    _emergencyContact = TextEditingController(
      text: _cleanText(user['emergency_contact']),
    );
    _emergencyPhone = TextEditingController(
      text: _cleanText(user['emergency_phone']),
    );
    _allergies = TextEditingController(text: _cleanText(user['allergies']));
    _healthNotes = TextEditingController(
      text: _cleanText(user['health_notes']),
    );
    _password = TextEditingController();
    _passwordConfirmation = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _title.dispose();
    _nickname.dispose();
    _idCard.dispose();
    _bloodGroup.dispose();
    _emergencyContact.dispose();
    _emergencyPhone.dispose();
    _allergies.dispose();
    _healthNotes.dispose();
    _password.dispose();
    _passwordConfirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'phone': _nullableText(_phone),
      'title': _nullableText(_title),
      'nickname': _nullableText(_nickname),
      'id_card': _nullableText(_idCard),
      'blood_group': _nullableText(_bloodGroup),
      'emergency_contact': _nullableText(_emergencyContact),
      'emergency_phone': _nullableText(_emergencyPhone),
      'allergies': _nullableText(_allergies),
      'health_notes': _nullableText(_healthNotes),
    };

    if (_password.text.trim().isNotEmpty) {
      payload['password'] = _password.text.trim();
      payload['password_confirmation'] = _passwordConfirmation.text.trim();
    }

    setState(() => _saving = true);
    try {
      await context.read<AppProvider>().updateProfile(
        payload,
        avatarImagePath: _avatarImagePath,
      );
      if (!mounted) return;
      _showSuccess(context, 'บันทึกโปรไฟล์เรียบร้อยแล้ว');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showAvatarSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AvatarSourceTile(
                  icon: Icons.photo_library_outlined,
                  title: 'เลือกรูปจากคลังภาพ',
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const SizedBox(height: 8),
                _AvatarSourceTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'ถ่ายรูปใหม่',
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1200,
      );
      if (image == null || !mounted) return;
      setState(() => _avatarImagePath = image.path);
    } catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            const TravelSliverAppBar(title: 'แก้ไขโปรไฟล์'),
            SliverToBoxAdapter(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FormCard(
                        title: 'ข้อมูลส่วนตัว',
                        children: [
                          _EditableProfilePhoto(
                            name: _name.text.trim().isEmpty
                                ? _cleanText(
                                    widget.initialUser['name'],
                                    fallback: 'ลุยเลเขา',
                                  )
                                : _name.text.trim(),
                            imageUrl: ApiConfig.mediaUrl(
                              _cleanText(widget.initialUser['avatar_url']),
                            ),
                            localImagePath: _avatarImagePath,
                            onPick: _showAvatarSourceSheet,
                          ),
                          _ProfileTextField(
                            controller: _name,
                            label: 'ชื่อ-นามสกุล',
                            icon: Icons.person_outline,
                            validator: _required('กรุณากรอกชื่อ-นามสกุล'),
                          ),
                          _ProfileTextField(
                            controller: _phone,
                            label: 'เบอร์โทรศัพท์',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return null;
                              return text.length == 10
                                  ? null
                                  : 'กรุณากรอกเบอร์โทรศัพท์ 10 หลัก';
                            },
                          ),
                          _ProfileTextField(
                            controller: _title,
                            label: 'คำนำหน้า',
                            icon: Icons.badge_outlined,
                          ),
                          _ProfileTextField(
                            controller: _nickname,
                            label: 'ชื่อเล่น',
                            icon: Icons.sentiment_satisfied_alt_outlined,
                          ),
                          _ProfileTextField(
                            controller: _idCard,
                            label: 'เลขบัตรประชาชน',
                            icon: Icons.credit_card_outlined,
                            keyboardType: TextInputType.number,
                            maxLength: 13,
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return null;
                              return text.length == 13
                                  ? null
                                  : 'กรุณากรอกเลขบัตรประชาชน 13 หลัก';
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _FormCard(
                        title: 'ข้อมูลการเดินทาง',
                        children: [
                          _ProfileTextField(
                            controller: _bloodGroup,
                            label: 'กรุ๊ปเลือด',
                            icon: Icons.bloodtype_outlined,
                          ),
                          _ProfileTextField(
                            controller: _allergies,
                            label: 'อาหาร/ยาที่แพ้',
                            icon: Icons.warning_amber_outlined,
                            maxLines: 2,
                          ),
                          _ProfileTextField(
                            controller: _healthNotes,
                            label: 'หมายเหตุสุขภาพ',
                            icon: Icons.medical_information_outlined,
                            maxLines: 3,
                          ),
                          _ProfileTextField(
                            controller: _emergencyContact,
                            label: 'ผู้ติดต่อฉุกเฉิน',
                            icon: Icons.contact_emergency_outlined,
                            validator: _required(
                              'กรุณากรอกชื่อผู้ติดต่อฉุกเฉิน',
                            ),
                          ),
                          _ProfileTextField(
                            controller: _emergencyPhone,
                            label: 'เบอร์ฉุกเฉิน',
                            icon: Icons.phone_in_talk_outlined,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return 'กรุณากรอกเบอร์ฉุกเฉิน';
                              return text.length == 10
                                  ? null
                                  : 'กรุณากรอกเบอร์ฉุกเฉิน 10 หลัก';
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _FormCard(
                        title: 'เปลี่ยนรหัสผ่าน',
                        subtitle: 'ปล่อยว่างไว้หากไม่ต้องการเปลี่ยน',
                        children: [
                          _ProfileTextField(
                            controller: _password,
                            label: 'รหัสผ่านใหม่',
                            icon: Icons.lock_outline,
                            obscureText: true,
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return null;
                              return text.length >= 6
                                  ? null
                                  : 'รหัสผ่านอย่างน้อย 6 ตัวอักษร';
                            },
                          ),
                          _ProfileTextField(
                            controller: _passwordConfirmation,
                            label: 'ยืนยันรหัสผ่านใหม่',
                            icon: Icons.lock_reset_outlined,
                            obscureText: true,
                            validator: (value) {
                              if (_password.text.trim().isEmpty) return null;
                              return value?.trim() == _password.text.trim()
                                  ? null
                                  : 'รหัสผ่านไม่ตรงกัน';
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _saving ? 'กำลังบันทึก...' : 'บันทึกโปรไฟล์',
                        ),
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
