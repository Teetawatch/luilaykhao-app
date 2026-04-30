import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';
import 'booking_lookup_screen.dart';
import 'login_screen.dart';
import 'payment_screen.dart';
import 'tracking_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    if (!app.isLoggedIn) {
      return const LoginScreen();
    }

    final user = app.user ?? {};
    final loyalty = app.loyalty ?? {};

    return ProfilePage(user: user, app: app, loyalty: loyalty);
  }
}

class ProfilePage extends StatelessWidget {
  final Map<String, dynamic> user;
  final AppProvider app;
  final Map<String, dynamic> loyalty;

  const ProfilePage({
    super.key,
    required this.user,
    required this.app,
    required this.loyalty,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await Future.wait([
              app.refreshMe(),
              app.loadAccountData(),
              app.loadMyReviews(),
            ]);
          } catch (e) {
            if (context.mounted) _showError(context, e);
          }
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            const TravelSliverAppBar(title: 'โปรไฟล์', showBackButton: false),
            SliverToBoxAdapter(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 128),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProfileHeader(user: user),
                      const SizedBox(height: 16),
                      ProfileStatsSection(app: app, loyalty: loyalty),
                      const SizedBox(height: 16),
                      QuickActionsSection(app: app),
                      const SizedBox(height: 24),
                      AccountMenu(user: user),
                      const SizedBox(height: 20),
                      const TravelMenu(),
                      const SizedBox(height: 20),
                      const SettingsMenu(),
                      const SizedBox(height: 20),
                      const SupportMenu(),
                      const SizedBox(height: 24),
                      LogoutSection(onLogout: app.logout),
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

class ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> user;

  const ProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final name = _cleanText(user['name'], fallback: 'ลุยเลเขา');
    final avatar = ApiConfig.mediaUrl(_cleanText(user['avatar_url']));
    final location = _cleanLocation(user['location']);
    final isVerified = _truthy(
      user['verified'] ??
          user['is_verified'] ??
          user['email_verified'] ??
          user['phone_verified'],
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFEAF7F1)],
        ),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(imageUrl: avatar, name: name),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'สวัสดี, $name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.anuphan(
                          fontSize: 24,
                          height: 1.16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textMain,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'พร้อมออกผจญภัยครั้งต่อไปไหม?',
                        style: GoogleFonts.anuphan(
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (location != null) ...[
            const SizedBox(height: 16),
            _IdentityPill(
              icon: Icons.location_on_outlined,
              label: location,
              color: AppTheme.primaryColor,
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _IdentityPill(
                icon: isVerified
                    ? Icons.verified_user_outlined
                    : Icons.shield_outlined,
                label: isVerified ? 'ยืนยันตัวตนแล้ว' : 'รอยืนยันตัวตน',
                color: isVerified
                    ? AppTheme.primaryColor
                    : AppTheme.warningColor,
              ),
              _IdentityPill(
                icon: Icons.lock_outline,
                label: 'บัญชีส่วนตัว',
                color: AppTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  _pushPremium(context, EditProfileScreen(initialUser: user)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textMain,
                side: BorderSide(
                  color: AppTheme.outlineColor.withValues(alpha: 0.9),
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.78),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(
                'แก้ไขโปรไฟล์',
                style: GoogleFonts.anuphan(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String imageUrl;
  final String name;

  const _Avatar({required this.imageUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'ล' : name.trim().characters.first;

    return Container(
      width: 88,
      height: 88,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl.isEmpty
            ? ColoredBox(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.primaryColor,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => ColoredBox(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.anuphan(
                        color: AppTheme.primaryColor,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                placeholder: (_, __) => ColoredBox(
                  color: AppTheme.outlineColor.withValues(alpha: 0.45),
                ),
              ),
      ),
    );
  }
}

class ProfileStatsSection extends StatelessWidget {
  final AppProvider app;
  final Map<String, dynamic> loyalty;

  const ProfileStatsSection({
    super.key,
    required this.app,
    required this.loyalty,
  });

  @override
  Widget build(BuildContext context) {
    final trips = app.bookings.length;
    final points = _numberValue(loyalty['points']);
    final nextLevelPoints = _numberValue(
      loyalty['next_level_points'],
      fallback: 1000,
    );
    final progress = nextLevelPoints <= 0
        ? 0.0
        : (points / nextLevelPoints).clamp(0.0, 1.0).toDouble();
    final remaining = (nextLevelPoints - points).clamp(0, nextLevelPoints);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _sectionDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'สมาชิกลุยเลเขา',
                  style: GoogleFonts.anuphan(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'สะสมรางวัล',
                  style: GoogleFonts.anuphan(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatMetric(
                  icon: Icons.flight_takeoff_rounded,
                  value: trips.toString(),
                  label: 'ทริปทั้งหมด',
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatMetric(
                  icon: Icons.stars_rounded,
                  value: _formatCompact(points),
                  label: 'แต้มสะสม',
                  color: AppTheme.warningColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              color: AppTheme.primaryColor,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            remaining == 0
                ? 'พร้อมปลดล็อกสิทธิพิเศษถัดไป'
                : 'อีก ${_formatCompact(remaining)} แต้ม ถึงระดับถัดไป',
            style: GoogleFonts.anuphan(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - opacity)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.outlineColor.withValues(alpha: 0.7),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: GoogleFonts.anuphan(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textMain,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.anuphan(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickActionsSection extends StatelessWidget {
  final AppProvider app;

  const QuickActionsSection({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final upcomingCount = app.bookings
        .map(asMap)
        .where(_isUpcomingBooking)
        .length;

    final actions = [
      _QuickAction(
        icon: Icons.confirmation_number_outlined,
        label: 'การจองของฉัน',
        badge: app.bookings.isEmpty ? null : app.bookings.length.toString(),
        onTap: () => _pushPremium(
          context,
          const ProfileBookingsScreen(title: 'การจองของฉัน'),
        ),
      ),
      _QuickAction(
        icon: Icons.event_available_outlined,
        label: 'ทริปที่กำลังจะถึง',
        badge: upcomingCount == 0 ? null : upcomingCount.toString(),
        onTap: () => _pushPremium(
          context,
          const ProfileBookingsScreen(
            title: 'ทริปที่กำลังจะถึง',
            filter: BookingFilter.upcoming,
          ),
        ),
      ),
      _QuickAction(
        icon: Icons.directions_bus_filled_outlined,
        label: 'ติดตามรถ',
        onTap: () => _pushPremium(context, const TrackingScreen()),
      ),
      _QuickAction(
        icon: Icons.rate_review_outlined,
        label: 'รีวิวของฉัน',
        onTap: () => _pushPremium(context, const MyReviewsScreen()),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading('ทางลัด'),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560 ? 4 : 2;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 106,
              ),
              itemBuilder: (context, index) {
                return _QuickActionTile(action: actions[index]);
              },
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;

  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      shadowColor: Colors.black.withValues(alpha: 0.08),
      elevation: 1,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: AppTheme.primaryColor.withValues(alpha: 0.06),
        highlightColor: AppTheme.primaryColor.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      action.icon,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  if (action.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        action.badge!,
                        style: GoogleFonts.anuphan(
                          color: AppTheme.warningColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                action.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.anuphan(
                  fontSize: 14,
                  height: 1.25,
                  color: AppTheme.textMain,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AccountMenu extends StatelessWidget {
  final Map<String, dynamic> user;

  const AccountMenu({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return MenuSection(
      title: 'บัญชี',
      items: [
        _MenuItem(
          icon: Icons.person_outline,
          label: 'ข้อมูลส่วนตัว',
          onTap: () =>
              _pushPremium(context, EditProfileScreen(initialUser: user)),
        ),
        _MenuItem(
          icon: Icons.payments_outlined,
          label: 'วิธีการชำระเงิน',
          onTap: () => _pushPremium(context, const PaymentMethodsScreen()),
        ),
      ],
    );
  }
}

class TravelMenu extends StatelessWidget {
  const TravelMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuSection(
      title: 'การเดินทางของฉัน',
      items: [
        _MenuItem(
          icon: Icons.confirmation_number_outlined,
          label: 'การจองของฉัน',
          onTap: () => _pushPremium(
            context,
            const ProfileBookingsScreen(title: 'การจองของฉัน'),
          ),
        ),
        _MenuItem(
          icon: Icons.history_outlined,
          label: 'ประวัติการเดินทาง',
          onTap: () => _pushPremium(
            context,
            const ProfileBookingsScreen(
              title: 'ประวัติการเดินทาง',
              filter: BookingFilter.past,
            ),
          ),
        ),
        _MenuItem(
          icon: Icons.reviews_outlined,
          label: 'รีวิวของฉัน',
          onTap: () => _pushPremium(context, const MyReviewsScreen()),
        ),
      ],
    );
  }
}

class SettingsMenu extends StatelessWidget {
  const SettingsMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuSection(
      title: 'การตั้งค่า',
      items: [
        _MenuItem(
          icon: Icons.tune_outlined,
          label: 'ตั้งค่าแอป',
          onTap: () => _pushPremium(
            context,
            const SimpleInfoScreen(
              title: 'ตั้งค่าแอป',
              icon: Icons.tune_outlined,
              body:
                  'การตั้งค่าหลักของแอปใช้ค่าที่เหมาะกับการจองและติดตามรถแบบเรียลไทม์อยู่แล้ว',
            ),
          ),
        ),
        _MenuItem(
          icon: Icons.language_outlined,
          label: 'ภาษา',
          trailing: 'ไทย',
          onTap: () => _pushPremium(
            context,
            const SimpleInfoScreen(
              title: 'ภาษา',
              icon: Icons.language_outlined,
              body:
                  'ตอนนี้แอปรองรับภาษาไทยเป็นหลัก เพื่อให้ข้อมูลการจองและการเดินทางชัดเจนที่สุด',
            ),
          ),
        ),
        _MenuItem(
          icon: Icons.notifications_none_outlined,
          label: 'การแจ้งเตือน',
          onTap: () => _pushPremium(context, const NotificationsScreen()),
        ),
      ],
    );
  }
}

class SupportMenu extends StatelessWidget {
  const SupportMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuSection(
      title: 'ช่วยเหลือ',
      items: [
        _MenuItem(
          icon: Icons.help_outline,
          label: 'ศูนย์ช่วยเหลือ',
          onTap: () => _pushPremium(context, const HelpCenterScreen()),
        ),
        _MenuItem(
          icon: Icons.chat_bubble_outline,
          label: 'ติดต่อเรา',
          onTap: () => _pushPremium(context, const ContactUsScreen()),
        ),
      ],
    );
  }
}

class MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const MenuSection({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title),
        const SizedBox(height: 8),
        Container(
          decoration: _sectionDecoration(radius: 22),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _MenuTile(item: items[index]),
                if (index < items.length - 1)
                  Divider(
                    height: 1,
                    indent: 64,
                    endIndent: 16,
                    color: AppTheme.outlineColor.withValues(alpha: 0.65),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final _MenuItem item;

  const _MenuTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        splashColor: AppTheme.primaryColor.withValues(alpha: 0.05),
        highlightColor: AppTheme.primaryColor.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(item.icon, color: AppTheme.primaryColor, size: 23),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.anuphan(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
              if (item.trailing != null) ...[
                const SizedBox(width: 8),
                Text(
                  item.trailing!,
                  style: GoogleFonts.anuphan(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: Colors.grey[300], size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class LogoutSection extends StatelessWidget {
  final VoidCallback onLogout;

  const LogoutSection({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _sectionDecoration(radius: 22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _AccountActionTile(
            icon: Icons.logout,
            label: 'ออกจากระบบ',
            color: AppTheme.errorColor,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _AccountActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AccountActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.anuphan(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[300], size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

enum BookingFilter { all, upcoming, past }

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
      backgroundColor: Colors.white,
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
      backgroundColor: const Color(0xFFF8F8F8),
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
                            controller: _emergencyContact,
                            label: 'ผู้ติดต่อฉุกเฉิน',
                            icon: Icons.contact_emergency_outlined,
                          ),
                          _ProfileTextField(
                            controller: _emergencyPhone,
                            label: 'เบอร์ฉุกเฉิน',
                            icon: Icons.phone_in_talk_outlined,
                            keyboardType: TextInputType.phone,
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

class ProfileBookingsScreen extends StatefulWidget {
  final String title;
  final BookingFilter filter;

  const ProfileBookingsScreen({
    super.key,
    required this.title,
    this.filter = BookingFilter.all,
  });

  @override
  State<ProfileBookingsScreen> createState() => _ProfileBookingsScreenState();
}

class _ProfileBookingsScreenState extends State<ProfileBookingsScreen> {
  Future<void> _refresh() => context.read<AppProvider>().loadAccountData();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final bookings = app.bookings.map(asMap).where((booking) {
      return switch (widget.filter) {
        BookingFilter.upcoming => _isUpcomingBooking(booking),
        BookingFilter.past => _isPastBooking(booking),
        BookingFilter.all => true,
      };
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            TravelSliverAppBar(title: widget.title),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: bookings.isEmpty
                    ? _EmptyProfileState(
                        icon: Icons.confirmation_number_outlined,
                        title: 'ยังไม่มีรายการ',
                        body:
                            'เมื่อมีการจอง ระบบจะแสดงข้อมูลล่าสุดจาก Laravel ที่หน้านี้',
                      )
                    : Column(
                        children: [
                          for (final booking in bookings) ...[
                            _BookingSummaryCard(
                              booking: booking,
                              onRefresh: _refresh,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingSummaryCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Future<void> Function() onRefresh;

  const _BookingSummaryCard({required this.booking, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final ref = _cleanText(booking['booking_ref'], fallback: '-');
    final status = _cleanText(booking['status']);
    final schedule = asMap(booking['schedule']);
    final trip = asMap(schedule['trip']);
    final title = _cleanText(trip['title'], fallback: 'ทริปของคุณ');
    final date = _travelDateText(booking);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _sectionDecoration(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.anuphan(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 12),
          _InfoLine(icon: Icons.confirmation_number_outlined, text: ref),
          const SizedBox(height: 8),
          _InfoLine(icon: Icons.event_outlined, text: date),
          const SizedBox(height: 8),
          _InfoLine(
            icon: Icons.payments_outlined,
            text: 'ยอดรวม ${money(booking['total_amount'])}',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status == 'pending')
                _SmallActionButton(
                  icon: Icons.payment_outlined,
                  label: 'ชำระเงิน',
                  onTap: () =>
                      _pushPremium(context, PaymentScreen(bookingRef: ref)),
                ),
              _SmallActionButton(
                icon: Icons.route_outlined,
                label: 'ติดตามรถ',
                onTap: () => _pushPremium(context, const BookingLookupScreen()),
              ),
              if (status == 'pending' || status == 'confirmed')
                _SmallActionButton(
                  icon: Icons.cancel_outlined,
                  label: 'ยกเลิก',
                  color: AppTheme.errorColor,
                  onTap: () =>
                      _confirmCancelBooking(context, booking, onRefresh),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await context.read<AppProvider>().loadMyReviews();
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final reviews = app.myReviews.map(asMap).toList();
    final reviewedBookingIds = reviews
        .map((review) => int.tryParse(_cleanText(review['booking_id'])))
        .whereType<int>()
        .toSet();
    final reviewableBookings = app.bookings
        .map(asMap)
        .where((booking) => _cleanText(booking['status']) == 'confirmed')
        .where((booking) {
          final id = int.tryParse(_cleanText(booking['id']));
          return id != null && !reviewedBookingIds.contains(id);
        })
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const TravelSliverAppBar(title: 'รีวิวของฉัน'),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (reviewableBookings.isNotEmpty) ...[
                            _SectionHeading('เขียนรีวิว'),
                            const SizedBox(height: 8),
                            for (final booking in reviewableBookings) ...[
                              _ReviewableBookingCard(
                                booking: booking,
                                onSubmitted: _load,
                              ),
                              const SizedBox(height: 12),
                            ],
                            const SizedBox(height: 12),
                          ],
                          _SectionHeading('รีวิวที่ผ่านมา'),
                          const SizedBox(height: 8),
                          if (reviews.isEmpty)
                            _EmptyProfileState(
                              icon: Icons.rate_review_outlined,
                              title: 'ยังไม่มีรีวิว',
                              body:
                                  'หลังจบทริป คุณสามารถส่งรีวิวจากรายการจองที่ยืนยันแล้ว',
                            )
                          else
                            for (final review in reviews) ...[
                              _ReviewCard(review: review),
                              const SizedBox(height: 12),
                            ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: CustomScrollView(
        slivers: [
          const TravelSliverAppBar(title: 'วิธีการชำระเงิน'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                children: const [
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
                        'หลังโอนเงินแล้ว กรุณาแนบสลิปในหน้าชำระเงิน ระบบ Laravel จะบันทึกหลักฐานไว้กับเลขการจอง',
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

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _saving = false;

  Future<void> _markAllRead() async {
    setState(() => _saving = true);
    try {
      await context.read<AppProvider>().markAllNotificationsRead();
      if (mounted) _showSuccess(context, 'อ่านการแจ้งเตือนทั้งหมดแล้ว');
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<AppProvider>().notifications.map(asMap);
    final unread = notifications
        .where((item) => item['is_read'] != true)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: CustomScrollView(
        slivers: [
          const TravelSliverAppBar(title: 'การแจ้งเตือน'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FormCard(
                    title: 'สถานะการแจ้งเตือน',
                    subtitle: 'เชื่อมต่อกับข้อมูลแจ้งเตือนจาก Laravel',
                    children: [
                      _InfoLine(
                        icon: Icons.notifications_active_outlined,
                        text: 'ยังไม่ได้อ่าน $unread รายการ',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _saving ? null : _markAllRead,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.done_all_outlined),
                        label: const Text('ทำเครื่องหมายว่าอ่านทั้งหมด'),
                      ),
                    ],
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

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: CustomScrollView(
        slivers: [
          const TravelSliverAppBar(title: 'ศูนย์ช่วยเหลือ'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                children: [
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
                    title: 'ติดต่อทีมงาน',
                    body: 'ส่งข้อความถึงทีมงานผ่านระบบ Laravel',
                    onTap: () => _pushPremium(context, const ContactUsScreen()),
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
      _showError(
        context,
        'กรุณาเพิ่มชื่อและเบอร์โทรศัพท์ในโปรไฟล์ก่อนติดต่อทีมงาน',
      );
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
      backgroundColor: const Color(0xFFF8F8F8),
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
                        subtitle: 'ระบบจะส่งข้อมูลนี้ไปยัง Laravel contacts',
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
      backgroundColor: const Color(0xFFF8F8F8),
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

class _IdentityPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _IdentityPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.anuphan(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;

  const _SectionHeading(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.anuphan(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: AppTheme.textMain,
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _FormCard({required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _sectionDecoration(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.anuphan(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppTheme.textMain,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: GoogleFonts.anuphan(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _EditableProfilePhoto extends StatelessWidget {
  final String name;
  final String imageUrl;
  final String? localImagePath;
  final VoidCallback onPick;

  const _EditableProfilePhoto({
    required this.name,
    required this.imageUrl,
    required this.localImagePath,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'ล' : name.trim().characters.first;

    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 112,
                height: 112,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: localImagePath != null
                      ? Image.file(File(localImagePath!), fit: BoxFit.cover)
                      : imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => ColoredBox(
                            color: AppTheme.outlineColor.withValues(
                              alpha: 0.45,
                            ),
                          ),
                          errorWidget: (_, __, ___) =>
                              _AvatarInitial(initial: initial),
                        )
                      : _AvatarInitial(initial: initial),
                ),
              ),
              Positioned(
                right: -2,
                bottom: 4,
                child: Material(
                  color: AppTheme.primaryColor,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: InkWell(
                    onTap: onPick,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: const Text('เปลี่ยนรูปโปรไฟล์'),
          ),
        ],
      ),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  final String initial;

  const _AvatarInitial({required this.initial});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.anuphan(
            color: AppTheme.primaryColor,
            fontSize: 38,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _AvatarSourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AvatarSourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F8F7),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.anuphan(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[300]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool obscureText;
  final String? Function(String?)? validator;

  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.obscureText = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: const Color(0xFFF7F8F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      style: GoogleFonts.anuphan(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.textMain,
      ),
    );
  }
}

class _EmptyProfileState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyProfileState({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _sectionDecoration(radius: 22),
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppTheme.primaryColor),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.anuphan(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.anuphan(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.anuphan(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'confirmed' => AppTheme.primaryColor,
      'pending' => AppTheme.warningColor,
      'cancelled' || 'refunded' => AppTheme.errorColor,
      _ => AppTheme.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: GoogleFonts.anuphan(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _SmallActionButton({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.primaryColor;
    return ActionChip(
      avatar: Icon(icon, size: 17, color: effectiveColor),
      label: Text(label),
      onPressed: onTap,
      labelStyle: GoogleFonts.anuphan(
        color: effectiveColor,
        fontWeight: FontWeight.w800,
      ),
      backgroundColor: effectiveColor.withValues(alpha: 0.08),
      side: BorderSide(color: effectiveColor.withValues(alpha: 0.14)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _ReviewableBookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Future<void> Function() onSubmitted;

  const _ReviewableBookingCard({
    required this.booking,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final schedule = asMap(booking['schedule']);
    final trip = asMap(schedule['trip']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _sectionDecoration(radius: 22),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _cleanText(trip['title'], fallback: 'ทริปของคุณ'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.anuphan(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _travelDateText(booking),
                  style: GoogleFonts.anuphan(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => _showReviewDialog(context, booking, onSubmitted),
            child: const Text('รีวิว'),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final rating = _numberValue(review['rating']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _sectionDecoration(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _cleanText(review['trip_title'], fallback: 'ทริปของคุณ'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.anuphan(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < rating ? Icons.star_rounded : Icons.star_border,
                    color: AppTheme.warningColor,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          if (_cleanText(review['comment']).isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _cleanText(review['comment']),
              style: GoogleFonts.anuphan(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PaymentMethodCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _sectionDecoration(radius: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.anuphan(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: GoogleFonts.anuphan(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
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

class _HelpTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  const _HelpTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _sectionDecoration(radius: 22),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.anuphan(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: GoogleFonts.anuphan(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[300]),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    this.badge,
    required this.onTap,
  });
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
  });
}

BoxDecoration _sectionDecoration({double radius = 24}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppTheme.outlineColor.withValues(alpha: 0.55)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.035),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

String _cleanText(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _cleanLocation(dynamic value) {
  final location = _cleanText(value);
  if (location.isEmpty) return null;

  const placeholders = {
    'San Francisco, CA',
    'San Francisco',
    'CA',
    'Unknown',
    'ไม่ระบุ',
  };

  return placeholders.contains(location) ? null : location;
}

String? _nullableText(TextEditingController controller) {
  final text = controller.text.trim();
  return text.isEmpty ? null : text;
}

String? Function(String?) _required(String message) {
  return (value) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  };
}

bool _truthy(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase().trim() ?? '';
  return text == '1' || text == 'true' || text == 'yes' || text == 'verified';
}

int _numberValue(dynamic value, {int fallback = 0}) {
  final number = num.tryParse(value?.toString() ?? '');
  return number?.round() ?? fallback;
}

String _formatCompact(int value) {
  if (value >= 1000000) {
    final compact = value / 1000000;
    return '${compact.toStringAsFixed(compact >= 10 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    final compact = value / 1000;
    return '${compact.toStringAsFixed(compact >= 10 ? 0 : 1)}k';
  }
  return value.toString();
}

bool _isUpcomingBooking(Map<String, dynamic> booking) {
  final status = _cleanText(booking['status']).toLowerCase();
  if (status == 'cancelled' || status == 'refunded' || status == 'completed') {
    return false;
  }

  final schedule = asMap(booking['schedule']);
  final rawDate = _cleanText(schedule['departure_date']);
  final date = DateTime.tryParse(rawDate);
  if (date == null) {
    return status == 'pending' || status == 'confirmed';
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return !DateTime(date.year, date.month, date.day).isBefore(today);
}

bool _isPastBooking(Map<String, dynamic> booking) {
  final status = _cleanText(booking['status']).toLowerCase();
  if (status == 'completed') return true;
  if (status == 'cancelled' || status == 'refunded') return false;

  final schedule = asMap(booking['schedule']);
  final rawReturn = _cleanText(
    schedule['return_date'],
    fallback: _cleanText(schedule['departure_date']),
  );
  final date = DateTime.tryParse(rawReturn);
  if (date == null) return false;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(date.year, date.month, date.day).isBefore(today);
}

String _travelDateText(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  final start = dateText(schedule['departure_date']);
  final end = dateText(schedule['return_date']);
  if (start == '-') return 'รอระบุวันเดินทาง';
  if (end == '-' || end == start) return start;
  return '$start - $end';
}

String _statusLabel(String status) {
  return switch (status) {
    'confirmed' => 'ยืนยันแล้ว',
    'pending' => 'รอชำระ',
    'cancelled' => 'ยกเลิก',
    'refunded' => 'คืนเงินแล้ว',
    'completed' => 'จบทริป',
    _ => status.isEmpty ? 'ไม่ระบุ' : status,
  };
}

Future<void> _confirmCancelBooking(
  BuildContext context,
  Map<String, dynamic> booking,
  Future<void> Function() onRefresh,
) async {
  final reason = TextEditingController();
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ยกเลิกการจอง',
                style: GoogleFonts.anuphan(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 12),
              _ProfileTextField(
                controller: reason,
                label: 'เหตุผลการยกเลิก',
                icon: Icons.edit_note_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                ),
                child: const Text('ยืนยันการยกเลิก'),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (confirmed != true || !context.mounted) {
    reason.dispose();
    return;
  }

  try {
    await context.read<AppProvider>().cancelBooking(
      _cleanText(booking['booking_ref']),
      reason.text.trim().isEmpty ? 'ยกเลิกจากแอป' : reason.text.trim(),
    );
    reason.dispose();
    if (!context.mounted) return;
    await onRefresh();
    if (context.mounted) _showSuccess(context, 'ยกเลิกการจองแล้ว');
  } catch (e) {
    reason.dispose();
    if (context.mounted) _showError(context, e);
  }
}

Future<void> _showReviewDialog(
  BuildContext context,
  Map<String, dynamic> booking,
  Future<void> Function() onSubmitted,
) async {
  final comment = TextEditingController();
  var rating = 5;

  final submitted = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('เขียนรีวิว'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      onPressed: () => setState(() => rating = index + 1),
                      icon: Icon(
                        index < rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ),
                ),
                TextField(
                  controller: comment,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'เล่าประสบการณ์ของคุณ',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ส่งรีวิว'),
              ),
            ],
          );
        },
      );
    },
  );

  if (submitted != true || !context.mounted) {
    comment.dispose();
    return;
  }

  try {
    await context.read<AppProvider>().submitReview(
      bookingId: int.parse(_cleanText(booking['id'])),
      rating: rating,
      comment: comment.text.trim(),
    );
    comment.dispose();
    if (!context.mounted) return;
    await onSubmitted();
    if (context.mounted) _showSuccess(context, 'ส่งรีวิวเรียบร้อยแล้ว');
  } catch (e) {
    comment.dispose();
    if (context.mounted) _showError(context, e);
  }
}

void _pushPremium(BuildContext context, Widget screen) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, animation, __) => screen,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

void _showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

void _showError(BuildContext context, Object error) {
  final message = error is ApiException ? error.message : error.toString();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppTheme.errorColor,
    ),
  );
}
