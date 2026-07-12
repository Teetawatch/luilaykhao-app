import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  static const _seenKey = 'onboarding_seen_v1';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) != true;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _index = 0;

  static const _slides = <_OnboardingSlide>[
    _OnboardingSlide(
      icon: Icons.travel_explore_rounded,
      title: 'ค้นพบทริปที่ใช่',
      body: 'รวมทริปดำน้ำ ทริปเดินป่า และเส้นทางผจญภัยทั่วไทย ไว้ในที่เดียว',
      gradient: [Color(0xFF059669), Color(0xFF34D399)],
    ),
    _OnboardingSlide(
      icon: Icons.event_seat_rounded,
      title: 'เลือกที่นั่งแบบเรียลไทม์',
      body: 'จองที่นั่งบนรถตู้ได้ทันที พร้อมล็อกที่นั่งชั่วคราวระหว่างชำระเงิน',
      gradient: [Color(0xFF0D9488), Color(0xFF2DD4BF)],
    ),
    _OnboardingSlide(
      icon: Icons.near_me_rounded,
      title: 'ติดตามรถแบบสดๆ',
      body: 'ดูตำแหน่งรถและเวลาที่จะถึงจุดรับของคุณได้แบบเรียลไทม์ตลอดการเดินทาง',
      gradient: [Color(0xFF0284C7), Color(0xFF38BDF8)],
    ),
  ];

  Future<void> _finish() async {
    await OnboardingScreen.markSeen();
    widget.onComplete();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;
    final accent = _slides[_index].gradient;
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accent.first.withValues(alpha: isDark ? 0.22 : 0.12),
              AppTheme.background(context).withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.55],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.mutedText(context),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                    child: Text(
                      'ข้าม',
                      style: appFont(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _SlideView(
                    slide: _slides[i],
                    controller: _pageController,
                    index: i,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 3.5),
                    width: active ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: active
                          ? LinearGradient(colors: accent)
                          : null,
                      color: active
                          ? null
                          : AppTheme.border(context).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: _PrimaryButton(
                  label: isLast ? 'เริ่มใช้งาน' : 'ถัดไป',
                  gradient: accent,
                  onTap: () {
                    if (isLast) {
                      _finish();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String body;
  final List<Color> gradient;
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.body,
    required this.gradient,
  });
}

class _SlideView extends StatelessWidget {
  final _OnboardingSlide slide;
  final PageController controller;
  final int index;

  const _SlideView({
    required this.slide,
    required this.controller,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // Parallax reveal driven by the page scroll offset.
        var delta = 0.0;
        if (controller.position.haveDimensions) {
          delta = (controller.page ?? index.toDouble()) - index;
        }
        final t = (1 - delta.abs()).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 36),
            child: Transform.scale(
              scale: 0.94 + 0.06 * t,
              child: child,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _HeroVisual(icon: slide.icon, gradient: slide.gradient),
            const SizedBox(height: 44),
            Text(
              slide.title,
              textAlign: TextAlign.center,
              style: appFont(
                color: AppTheme.onSurface(context),
                fontSize: 27,
                height: 1.2,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              slide.body,
              textAlign: TextAlign.center,
              style: appFont(
                color: AppTheme.mutedText(context),
                fontSize: 15.5,
                height: 1.65,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroVisual extends StatelessWidget {
  final IconData icon;
  final List<Color> gradient;

  const _HeroVisual({required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft ambient glow
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  gradient.last.withValues(alpha: 0.28),
                  gradient.last.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          // Rounded "app icon" style tile
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(38),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 58),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: appFont(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
