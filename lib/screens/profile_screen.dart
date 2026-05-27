import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../models/sos_alert.dart';
import '../providers/app_provider.dart';
import '../providers/tracking_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/support_shortcuts.dart';
import '../widgets/travel_widgets.dart';
import 'booking_lookup_screen.dart';
import 'document_wallet_screen.dart';
import 'notification_preferences_screen.dart';
import 'chat_screen.dart' show ChatScreen;
import 'staff_check_in_screen.dart' show StaffCheckInScreen;
import 'wishlist_screen.dart';
import 'login_screen.dart';
import 'payment_screen.dart';
import 'sos_alert_screen.dart';
import 'tracking_screen.dart';
import 'trip_detail_screen.dart' show TripDetailScreen;

part 'profile_edit.part.dart';
part 'profile_bookings.part.dart';
part 'profile_reviews.part.dart';
part 'profile_payment_methods.part.dart';
part 'profile_notifications.part.dart';
part 'profile_help.part.dart';
part 'profile_widgets.part.dart';
part 'profile_staff.part.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    if (!app.isLoggedIn) {
      return const LoginScreen(popOnSuccess: false);
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      if (app.canUseStaffCheckIn) ...[
                        const SizedBox(height: 24),
                        StaffDashboardSection(app: app),
                      ],
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'อรุณสวัสดิ์';
    if (hour < 17) return 'สวัสดีตอนบ่าย';
    return 'สวัสดีตอนเย็น';
  }

  @override
  Widget build(BuildContext context) {
    final name = _cleanText(user['name'], fallback: 'ลุยเลเขา');
    final avatar = ApiConfig.mediaUrl(_cleanText(user['avatar_url']));
    final location = _cleanLocation(user['location']);
    final email = _cleanText(user['email']);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.isDark(context)
              ? [AppTheme.surface(context), const Color(0xFF12352D)]
              : [const Color(0xFFFFFFFF), const Color(0xFFEAF7F1)],
        ),
        border: Border.all(color: AppTheme.border(context), width: 1),
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
                        '${_greeting()} 👋',
                        style: GoogleFonts.anuphan(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.mutedText(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.anuphan(
                          fontSize: 22,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.onSurface(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email.isNotEmpty
                            ? email
                            : 'พร้อมออกผจญภัยครั้งต่อไปไหม?',
                        style: GoogleFonts.anuphan(
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.mutedText(context),
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
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  _pushPremium(context, EditProfileScreen(initialUser: user)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.onSurface(context),
                side: BorderSide(color: AppTheme.border(context)),
                backgroundColor: AppTheme.surface(
                  context,
                ).withValues(alpha: 0.78),
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
        color: AppTheme.surface(context),
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
                errorWidget: (_, _, _) => ColoredBox(
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
                placeholder: (_, _) => ColoredBox(
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
    final trips = app.bookings.map(asMap).where((b) {
      final s = _cleanText(b['status']).toLowerCase();
      return s != 'cancelled' && s != 'refunded';
    }).length;
    final tier = _cleanText(loyalty['tier'] ?? loyalty['level']);
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
      decoration: _sectionDecoration(context: context),
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
              if (tier.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF047857)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tier,
                    style: GoogleFonts.anuphan(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
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
          color: AppTheme.subtleSurface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.border(context).withValues(alpha: 0.7),
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
                  color: AppTheme.onSurface(context),
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
                color: AppTheme.mutedText(context),
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
        onTap: () => _pushPremium(context, const BookingLookupScreen()),
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
        const _SectionHeading('ทางลัด'),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560 ? 4 : 2;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
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
      color: AppTheme.surface(context),
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
                        color: AppTheme.warningTint(context),
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
        _MenuItem(
          icon: Icons.wallet_rounded,
          label: 'Document Wallet',
          subtitle: 'ข้อมูลผู้เดินทางสำหรับ auto-fill',
          onTap: () => _pushPremium(context, const DocumentWalletScreen()),
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
          icon: Icons.favorite_border_rounded,
          label: 'ทริปที่ชอบ',
          onTap: () => _pushPremium(context, const WishlistScreen()),
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
    final app = context.watch<AppProvider>();

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
                  'แอปนี้ออกแบบมาให้ใช้งานได้ทันที ไม่จำเป็นต้องตั้งค่าเพิ่มเติม',
            ),
          ),
        ),
        _MenuItem(
          icon: Icons.language_outlined,
          label: 'ภาษา',
          trailing: app.locale.languageCode == 'en' ? 'English' : 'ภาษาไทย',
          onTap: () => _showLanguagePicker(context),
        ),
        _MenuItem(
          icon: Icons.notifications_none_outlined,
          label: 'กล่องแจ้งเตือน',
          onTap: () => _pushPremium(context, const NotificationsScreen()),
        ),
        _MenuItem(
          icon: Icons.tune,
          label: 'ตั้งค่าการแจ้งเตือน',
          onTap: () =>
              _pushPremium(context, const NotificationPreferencesScreen()),
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
          decoration: _sectionDecoration(context: context, radius: 22),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.65),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              Icon(item.icon, color: colorScheme.primary, size: 23),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anuphan(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (item.subtitle != null)
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.anuphan(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (item.trailing != null) ...[
                const SizedBox(width: 8),
                Text(
                  item.trailing!,
                  style: GoogleFonts.anuphan(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (item.trailingWidget != null) ...[
                const SizedBox(width: 8),
                item.trailingWidget!,
              ],
              if (item.showChevron) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  size: 22,
                ),
              ],
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

  Future<void> _confirmLogout(
    BuildContext context,
    VoidCallback onLogout,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'ออกจากระบบ',
          style: GoogleFonts.anuphan(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'คุณต้องการออกจากระบบใช่หรือไม่?',
          style: GoogleFonts.anuphan(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
    if (confirmed == true) onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _sectionDecoration(context: context, radius: 22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _AccountActionTile(
            icon: Icons.logout,
            label: 'ออกจากระบบ',
            color: AppTheme.errorColor,
            onTap: () => _confirmLogout(context, onLogout),
          ),
          Divider(
            height: 1,
            indent: 56,
            endIndent: 16,
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.65),
          ),
          _AccountActionTile(
            icon: Icons.delete_forever_outlined,
            label: 'ลบบัญชี',
            color: AppTheme.errorColor,
            onTap: () => _confirmDeleteAccount(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final app = context.read<AppProvider>();
    final requiresPassword = app.user?['has_password'] == true;

    // The dialog deletes the account on the server and shows a success view that
    // stays put until the user taps "ปิด" (returning true). Only then do we clear
    // the local session, so the confirmation never flashes past before the login
    // screen replaces this one.
    final acknowledged = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteAccountDialog(
        requiresPassword: requiresPassword,
        onConfirm: ({String? password}) =>
            app.deleteAccount(password: password),
      ),
    );

    if (acknowledged == true) {
      await app.finalizeAccountDeletion();
    }
  }
}

/// Confirmation dialog for permanent account deletion. Manages its own loading,
/// error and success state and, for password-based accounts, collects a password
/// for re-authentication. After deletion succeeds it switches to an explicit
/// success view so the user (and an App Review screen recording) sees a clear
/// confirmation before dismissing.
class _DeleteAccountDialog extends StatefulWidget {
  final bool requiresPassword;
  final Future<void> Function({String? password}) onConfirm;

  const _DeleteAccountDialog({
    required this.requiresPassword,
    required this.onConfirm,
  });

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final password = _passwordController.text;
    if (widget.requiresPassword && password.isEmpty) {
      setState(() => _error = 'กรุณากรอกรหัสผ่านเพื่อยืนยัน');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onConfirm(
        password: widget.requiresPassword ? password : null,
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _done = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('ApiException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildSuccess(context);
    return _buildConfirm(context);
  }

  Widget _buildSuccess(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppTheme.primaryColor,
            size: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ลบบัญชีเรียบร้อยแล้ว',
              style: GoogleFonts.anuphan(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      content: Text(
        'บัญชีและข้อมูลทั้งหมดของคุณถูกลบออกจากระบบอย่างถาวรเรียบร้อยแล้ว '
        'ขอบคุณที่ใช้บริการลุยเลเขา',
        style: GoogleFonts.anuphan(fontSize: 14, height: 1.5),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          child: Text(
            'ปิด',
            style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirm(BuildContext context) {
    return AlertDialog(
      title: Text(
        'ลบบัญชีถาวร',
        style: GoogleFonts.anuphan(fontWeight: FontWeight.w900),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'การลบบัญชีจะลบข้อมูลส่วนตัว ประวัติการจอง แต้มสะสม และรีวิวทั้งหมดอย่างถาวร '
            'การดำเนินการนี้ไม่สามารถย้อนกลับได้',
            style: GoogleFonts.anuphan(fontSize: 14, height: 1.5),
          ),
          if (widget.requiresPassword) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              enabled: !_loading,
              style: GoogleFonts.anuphan(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'ยืนยันด้วยรหัสผ่าน',
                labelStyle: GoogleFonts.anuphan(),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.anuphan(
                color: AppTheme.errorColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: Text('ยกเลิก', style: GoogleFonts.anuphan()),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'ลบบัญชี',
                  style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
                ),
        ),
      ],
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
