part of 'trip_detail_screen.dart';

class TravelSliverAppBar extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool isLoading;
  final bool isCollapsed;
  final double expandedHeight;
  final bool isFavorite;
  final bool isAlertOn;
  final VoidCallback onSharePressed;
  final VoidCallback onFavoritePressed;
  final VoidCallback onAlertPressed;

  /// แท็บที่กำลังอยู่ และตัวจัดการกดแท็บ — null = หน้านี้ไม่มีแท็บ (ตอนโหลด)
  final int? activeTab;
  final ValueChanged<int>? onTabSelected;

  /// กลุ่มไหนมีเนื้อหาให้ดู — กลุ่มที่ว่างจะไม่ถูกแสดงเป็นแท็บ
  final List<bool>? tabHasContent;

  const TravelSliverAppBar({
    super.key,
    required this.trip,
    required this.isLoading,
    required this.isCollapsed,
    required this.expandedHeight,
    required this.isFavorite,
    required this.isAlertOn,
    required this.onSharePressed,
    required this.onFavoritePressed,
    required this.onAlertPressed,
    this.activeTab,
    this.onTabSelected,
    this.tabHasContent,
  });

  @override
  Widget build(BuildContext context) {
    final title = _tripTitle(trip);

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: expandedHeight,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isCollapsed
          ? AppTheme.surface(context)
          : Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      // A hairline under the collapsed bar separates it from the content that
      // scrolls beneath, the way Airbnb / Klook headers do.
      shape: isCollapsed
          ? Border(
              bottom: BorderSide(color: AppTheme.border(context), width: 0.5),
            )
          : null,
      // Left-aligned so the collapsed title flows from the back button and
      // ellipsizes gracefully, instead of being squeezed into a narrow centred
      // slot between the leading button and the actions.
      title: AnimatedOpacity(
        opacity: isCollapsed ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.appBarTitleStyle(context),
        ),
      ),
      centerTitle: false,
      titleSpacing: 8,
      leadingWidth: 58,
      leading: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: FloatingActionIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'ย้อนกลับ',
          isCollapsed: isCollapsed,
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      actions: [
        FloatingActionIconButton(
          icon: Icons.ios_share_rounded,
          tooltip: 'แชร์ทริปนี้',
          isCollapsed: isCollapsed,
          onPressed: onSharePressed,
        ),
        const SizedBox(width: 10),
        FloatingActionIconButton(
          icon: isAlertOn
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          tooltip: isAlertOn ? 'ปิดแจ้งเตือนทริปนี้' : 'เปิดแจ้งเตือนทริปนี้',
          isCollapsed: isCollapsed,
          foregroundColor: isAlertOn ? const Color(0xFFF59E0B) : null,
          onPressed: onAlertPressed,
        ),
        const SizedBox(width: 10),
        FloatingActionIconButton(
          icon: isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          tooltip: isFavorite ? 'นำออกจากทริปที่ชอบ' : 'บันทึกเป็นทริปที่ชอบ',
          isCollapsed: isCollapsed,
          foregroundColor: isFavorite ? const Color(0xFFE11D48) : null,
          onPressed: onFavoritePressed,
        ),
        const SizedBox(width: 14),
      ],
      // แท็บนำทางอยู่ในช่อง bottom ของ AppBar ไม่ใช่ sliver แยก เพราะ sliver
      // ที่ pin ทีหลังจะไปเกาะขอบบนสุดของ viewport แล้วโดน app bar วาดทับ
      // ช่องนี้ถูกจองไว้ตลอด แต่โปร่งใสตอนแถบยังกาง จึงเห็นเป็นรูปปกเต็มๆ
      bottom: activeTab == null
          ? null
          : TripSectionTabs(
              activeIndex: activeTab!,
              visible: isCollapsed,
              hasContent: tabHasContent,
              onSelected: onTabSelected ?? (_) {},
            ),
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: HeroCoverImage(trip: trip, isLoading: isLoading),
          ),
          _ContentTopCap(hasTabs: activeTab != null),
        ],
      ),
    );
  }
}

/// แท็บกระโดดไปแต่ละกลุ่มเนื้อหา โผล่มาตอนแถบรูปหุบจนเหลือ toolbar
///
/// จองที่ในความสูงของ app bar ไว้ตลอดแม้ตอนยังมองไม่เห็น เพราะถ้าความสูงของ
/// ช่อง bottom เปลี่ยนกลางคัน minExtent ของ sliver จะเปลี่ยนตาม แล้วเนื้อหา
/// จะกระตุกตอนเลื่อน
class TripSectionTabs extends StatelessWidget implements PreferredSizeWidget {
  final int activeIndex;
  final bool visible;
  final ValueChanged<int> onSelected;

  /// กลุ่มไหนมีเนื้อหา — null = ถือว่ามีครบทุกกลุ่ม
  final List<bool>? hasContent;

  const TripSectionTabs({
    super.key,
    required this.activeIndex,
    required this.visible,
    required this.onSelected,
    this.hasContent,
  });

  @override
  Size get preferredSize => const Size.fromHeight(_tabBarHeight);

  bool _shows(int i) => hasContent == null || hasContent![i];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        // Material เพื่อให้ระลอกน้ำตอนกดแท็บมีพื้นของตัวเองให้วาด
        child: Material(
          color: AppTheme.surface(context),
          child: SizedBox(
            height: _tabBarHeight,
            child: Row(
              children: [
                // แท็บที่เหลือขยายเต็มความกว้างเสมอ ไม่ทิ้งช่องว่างของแท็บที่
                // ถูกซ่อน
                for (var i = 0; i < _tabLabels.length; i++)
                  if (_shows(i))
                    Expanded(
                      child: _SectionTab(
                        label: _tabLabels[i],
                        isActive: i == activeIndex,
                        onTap: () => onSelected(i),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SectionTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.onSurface(context) : _mutedText;

    return Semantics(
      button: true,
      selected: isActive,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ),
            // ขีดใต้แท็บที่เลือก — วาดค้างไว้ทั้งแถวด้วยสีโปร่งเพื่อไม่ให้
            // ตัวอักษรขยับขึ้นลงตอนสลับแท็บ
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2.5,
              color: isActive ? _softAccent : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

/// รอยต่อระหว่างรูปปกกับการ์ดเนื้อหา — เฉดที่ปลายรูป, ขอบโค้ง และขีดจับ
///
/// อยู่ใน [TravelSliverAppBar] ไม่ใช่ใน sliver ของเนื้อหา เพราะ viewport วาด
/// sliver แรกทับ sliver ที่ตามมา — โค้งที่ติดอยู่กับเนื้อหาจะถูกรูปปกบังจนหมด
/// เหลือเป็นขอบตรง ตัวมันเกาะขอบล่างของแถบ ซึ่งเป็นตำแหน่งเดียวกับหัวการ์ดพอดี
/// ตราบใดที่แถบยังไม่หุบสุด แล้วจางหายไปในช่วง [_contentOverlap] สุดท้ายก่อน
/// เนื้อหาจะเริ่มเลื่อนลอดใต้ toolbar
class _ContentTopCap extends StatelessWidget {
  /// แถบแท็บกินความสูงของ app bar ตอนหุบสุดด้วย ต้องบวกเข้าไปในจุดที่ขอบโค้ง
  /// ต้องจางหมดพอดี ไม่งั้นมันจะค้างทับเนื้อหาที่เลื่อนลอดใต้แท็บ
  final bool hasTabs;

  const _ContentTopCap({required this.hasTabs});

  @override
  Widget build(BuildContext context) {
    final collapsedHeight =
        kToolbarHeight +
        MediaQuery.paddingOf(context).top +
        (hasTabs ? _tabBarHeight : 0);
    final background = AppTheme.background(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final opacity =
            ((constraints.maxHeight - collapsedHeight) / _contentOverlap)
                .clamp(0.0, 1.0);
        if (opacity == 0) return const SizedBox.shrink();

        return Align(
          alignment: Alignment.bottomCenter,
          child: Opacity(
            opacity: opacity,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // เฉดจางลงหาสีการ์ด ไล่ต่อเนื่องลงไปจนถึงขอบล่างสุดของแถบ
                // (ส่วนล่างสุดโดนขอบโค้งทับ เหลือโผล่เฉพาะเนื้อรูปตรงมุม)
                SizedBox(
                  width: double.infinity,
                  height: _heroVeilHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          background.withValues(alpha: 0),
                          background.withValues(alpha: _heroVeilOpacity * 0.3),
                          background.withValues(alpha: _heroVeilOpacity),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  key: const Key('tripDetailContentCap'),
                  width: double.infinity,
                  height: _contentOverlap,
                  child: CustomPaint(
                    painter: _SquircleCapPainter(background),
                    child: const _CardGrabHandle(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ขีดจับบนหัวการ์ด บอกว่าแผงนี้เลื่อนขึ้นได้ — ภาษาเดียวกับ bottom sheet
class _CardGrabHandle extends StatelessWidget {
  const _CardGrabHandle();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.onSurface(context).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
        ),
      ),
    );
  }
}

/// หัวการ์ดที่มุมบนเป็น superellipse แบบมุมหน้าต่าง iOS แทนส่วนโค้งวงกลม
///
/// วงกลมเข้าหาขอบตรงด้วยความโค้งที่ตัดจบทันที ตาจึงจับได้ว่าโค้งจบตรงไหน ส่วน
/// superellipse (u^n + v^n = 1) ค่อยๆ คลี่ออกไปตามขอบจนอ่านเป็นเส้นเดียว
///
/// วัดเทียบกับวงกลมรัศมี 32 ที่กล่องโค้ง 48×40 และ n = 2.6 แล้ว เส้นนี้อยู่นอก
/// วงกลมทุกจุด (y=8 → x 12.7 เทียบ 10.8, y=16 → 5.3 เทียบ 4.3) จึงไม่ได้โค้ง
/// น้อยลงเลย ได้แต่ความนุ่มตรงหัวท้ายเพิ่มมา
///
/// โค้งกินแนวตั้งเท่าความสูงของหัวการ์ดพอดี ขอบล่างจึงเต็มความกว้าง ต่อกับ
/// การ์ดเนื้อหาข้างล่างได้สนิท
class _SquircleCapPainter extends CustomPainter {
  final Color color;

  const _SquircleCapPainter(this.color);

  /// 2 = วงรีพอดี ยิ่งมากยิ่งเหลี่ยม
  static const double _exponent = 2.6;

  /// เดินเส้นด้วย θ ไม่ใช่พิกัดตรงๆ เพราะพิกัดตรงๆ จะทิ้งจุดห่างกัน 20px
  /// ตรงที่โค้งบรรจบขอบบนจนเห็นเป็นเหลี่ยม แบบนี้ช่วงห่างสูงสุดเหลือ ~4px
  static const int _steps = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final spread = math.min(_contentCornerSpread, size.width / 2);
    final path = Path()..moveTo(0, size.height);

    // มุมซ้ายบน ไล่จากขอบซ้ายขึ้นไปบรรจบขอบบน
    for (var i = 1; i <= _steps; i++) {
      final p = _corner(i / _steps, spread, size.height);
      path.lineTo(p.dx, p.dy);
    }
    // มุมขวาบน ไล่กลับทางเดิม (ลากเส้นตรงช่วงกลางขอบบนให้เองระหว่างทาง)
    for (var i = _steps; i >= 1; i--) {
      final p = _corner(i / _steps, spread, size.height);
      path.lineTo(size.width - p.dx, p.dy);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  /// จุดบนมุมโค้งที่ [t] ∈ [0,1] — 0 คือปลายล่างที่ชนขอบข้าง 1 คือปลายบน
  /// ที่ชนขอบบน
  Offset _corner(double t, double spread, double height) {
    final theta = t * math.pi / 2;
    final u = math.pow(math.cos(theta), 2 / _exponent).toDouble();
    final v = math.pow(math.sin(theta), 2 / _exponent).toDouble();
    return Offset(spread * (1 - u), height * (1 - v));
  }

  @override
  bool shouldRepaint(_SquircleCapPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A single, static cover image for the trip — no swiping, no counters.
/// The bottom dissolves into the page background so the detail card below
/// blends in cleanly, in the spirit of Apple's photo-led layouts.
class HeroCoverImage extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool isLoading;

  const HeroCoverImage({
    super.key,
    required this.trip,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final images = _galleryImages(trip);
    final imageUrl = images.isNotEmpty ? images.first : '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── cover image only ───────────────────────────────────────
        Container(
          color: AppTheme.border(context),
          child: isLoading
              ? const Skeleton(radius: 0)
              : imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const Skeleton(radius: 0),
                  errorWidget: (_, _, _) => const _GalleryImageFallback(),
                )
              : const _GalleryImageFallback(),
        ),

        // ── top scrim for control legibility only ─────────────────
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.42),
                Colors.transparent,
              ],
              stops: const [0.0, 0.38],
            ),
          ),
        ),
      ],
    );
  }
}

class _GalleryImageFallback extends StatelessWidget {
  const _GalleryImageFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.border(context),
      child: const Center(
        child: Icon(Icons.landscape_rounded, color: _softAccent, size: 64),
      ),
    );
  }
}

class FloatingActionIconButton extends StatefulWidget {
  final IconData icon;
  /// Spoken by TalkBack/VoiceOver and shown on long-press. These buttons are
  /// icon-only over a photo, so without it they announce as just "button".
  final String tooltip;
  final bool isCollapsed;
  final Color? foregroundColor;
  final VoidCallback onPressed;

  const FloatingActionIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.isCollapsed,
    this.foregroundColor,
    required this.onPressed,
  });

  @override
  State<FloatingActionIconButton> createState() =>
      _FloatingActionIconButtonState();
}

class _FloatingActionIconButtonState extends State<FloatingActionIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Over the photo: a flat solid white disc with a dark icon — no shadow, no
    // glow, just clean colour. Once the bar collapses to a solid surface, the
    // disc drops away, leaving a bare icon on the clean white bar.
    final overImage = !widget.isCollapsed;
    final foreground =
        widget.foregroundColor ??
        (overImage ? const Color(0xFF1E293B) : AppTheme.onSurface(context));

    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapCancel: () => setState(() => _isPressed = false),
        onTapUp: (_) => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.9 : 1,
          duration: const Duration(milliseconds: 110),
          child: MinTapTarget(child: Container(
            width: 40,
            height: 40,
            decoration: overImage
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.surface(context),
                  )
                : null,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onPressed();
                },
                child: Center(
                  child: Icon(widget.icon, size: 20, color: foreground),
                ),
              ),
            ),
          )),
        ),
      ),
    );
  }
}
