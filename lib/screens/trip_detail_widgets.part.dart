part of 'trip_detail_screen.dart';

class _PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _PremiumCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: AppTheme.cardDecoration(
        context,
        radius: 20,
        borderColor: AppTheme.border(context).withValues(alpha: 0.55),
        shadowOpacity: 0.04,
      ),
      child: child,
    );
  }
}

/// แผ่นไอคอนสี่เหลี่ยมมนหลังไอคอน ใช้ร่วมกันทุกที่ในหน้าทริป
///
/// เดิมเขียนซ้ำอยู่ 4 ที่ด้วย 4 ขนาด (36/19, 36/19, 34/18, 32/16) และคนละสูตรสี
/// — บางที่ไล่เฉด บางที่ทึบ ทำให้แผ่นไอคอนที่ควรอ่านเป็นของชนิดเดียวกันดูไม่
/// เท่ากัน เหลือสองขนาดตามลำดับชั้น: [headerSize] สำหรับหัวข้อ section และ
/// [rowSize] สำหรับแถวย่อยข้างใน
class _IconPlate extends StatelessWidget {
  static const double headerSize = 36;
  static const double rowSize = 32;

  final IconData icon;
  final double size;

  /// ปล่อยว่าง = สีกลาง ใส่สีเฉพาะตอนที่สีนั้นมีความหมาย
  final Color? accent;

  const _IconPlate({
    required this.icon,
    this.size = headerSize,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final tint = accent;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint == null
            ? (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppTheme.subtleSurface(context))
            : tint.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Icon(
        icon,
        // ไอคอนกินราวครึ่งหนึ่งของแผ่นในทุกขนาด
        size: size * 0.53,
        color: tint ?? AppTheme.mutedText(context),
      ),
    );
  }
}

/// การ์ด section ที่พับเก็บได้ ใช้กับเนื้อหาอ้างอิงที่ต้องมีให้ครบแต่ไม่ควรกิน
/// ที่ตอนกำลังตัดสินใจ (เงื่อนไข เอกสาร สิ่งที่รวม ฯลฯ)
///
/// ต่างจาก [_PremiumCard] + [_SectionHeader] ตรงที่หัวข้อเป็นส่วนหนึ่งของ shell
/// จึงกดพับได้ทั้งแถบ และคุมสีเน้นได้ทีละใบ — section ที่เป็นคำเตือนจะได้ใช้สี
/// ของตัวเองโดยไม่ต้องเขียน header เองใหม่ทั้งก้อนแบบที่ MustKnowSection เคยทำ
class _SectionShell extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  /// พับได้ไหม — false = การ์ดธรรมดาที่กางค้างไว้
  final bool collapsible;

  /// ตอนเปิดหน้ามาให้กางไว้เลยไหม ใช้กับเรื่องที่ต้องเห็นก่อนจอง (วีซ่า คำเตือน)
  final bool initiallyExpanded;

  /// สีเน้นของหัวข้อ — ปล่อยว่างได้ จะใช้สีตัวอักษรปกติ ไม่ใช่สีแบรนด์
  /// (ตั้งใจ: ถ้าทุก section เน้นหมด ก็เท่ากับไม่มีอะไรเน้น)
  final Color? accent;

  const _SectionShell({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
    this.collapsible = false,
    this.initiallyExpanded = false,
    this.accent,
  });

  @override
  State<_SectionShell> createState() => _SectionShellState();
}

class _SectionShellState extends State<_SectionShell> {
  late bool _expanded = !widget.collapsible || widget.initiallyExpanded;

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final accent = widget.accent;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(20, 18, widget.collapsible ? 12 : 20, 18),
      child: Row(
        children: [
          _IconPlate(icon: widget.icon, accent: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeSubtitle,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : _premiumText,
                    height: 1.25,
                    letterSpacing: -0.2,
                  ),
                ),
                if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: _mutedText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.collapsible)
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 24,
                color: AppTheme.mutedText(context),
              ),
            ),
        ],
      ),
    );

    // Material ไม่ใช่ Container เพราะหัวข้อกดได้ — ถ้าพื้นการ์ดเป็น Container
    // ทึบ ระลอกน้ำของ InkWell จะไปวาดบน Material ของ Scaffold ที่อยู่ข้างหลัง
    // แล้วถูกพื้นการ์ดบังจนมองไม่เห็นว่ากดติด
    return Material(
      color: AppTheme.surface(context),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.collapsible)
            Semantics(
              button: true,
              expanded: _expanded,
              child: InkWell(onTap: _toggle, child: header),
            )
          else
            header,
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: widget.child,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

/// หัวข้อของ section ที่เนื้อหาเต็มความกว้าง (แกลเลอรี รีวิว) จึงครอบด้วย
/// [_SectionShell] ไม่ได้เพราะ shell ใส่ระยะขอบให้ลูกเสมอ
///
/// หน้าตาแถวหัวข้อต้องเหมือน [_SectionShell] เป๊ะ — ขนาดแผ่นไอคอน สี ระยะห่าง
/// และน้ำหนักตัวอักษร ไม่งั้นเลื่อนลงมาจะเจอสอง "ภาษา" สลับกันทั้งที่เป็น
/// หัวข้อเหมือนกัน
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  /// สีเน้น — ปล่อยว่างได้ จะได้แผ่นไอคอนสีกลางเหมือน section ส่วนใหญ่
  /// เก็บสีไว้ให้เฉพาะเรื่องที่มีความหมาย (คำเตือน เอกสาร) ถ้าเน้นทุกหัวข้อ
  /// ก็เท่ากับไม่ได้เน้นอะไรเลย
  final Color? accent;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _IconPlate(icon: icon, accent: accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  // 16 ไม่ใช่ 18 — ให้ตรงกับ _SectionShell และไม่ไปแย่งน้ำหนัก
                  // กับชื่อทริปที่เป็นหัวจริงของหน้า
                  fontSize: AppText.sizeSubtitle,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : _premiumText,
                  height: 1.25,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    color: _mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;

  /// สีไอคอน — ปล่อยว่าง = สีกลาง ใส่สีเฉพาะตอนที่สีนั้นมีความหมายจริง
  /// (เขียว = รวมให้แล้ว, แดง = ต้องจ่ายเพิ่ม, น้ำเงิน = เรื่องเอกสาร)
  final Color? iconColor;
  final Color? iconBackground;

  const _FeatureRow({
    required this.icon,
    required this.title,
    this.description,
    this.iconColor,
    this.iconBackground,
  });

  @override
  Widget build(BuildContext context) {
    if (title.trim().isEmpty) return const SizedBox.shrink();
    final isDark = AppTheme.isDark(context);
    final tint = iconColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconPlate(icon: icon, size: _IconPlate.rowSize, accent: tint),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white.withValues(alpha: 0.9) : _premiumText,
                      height: 1.4,
                    ),
                  ),
                  if (description != null && description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description!,
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        color: _mutedText,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark
            ? _softAccent.withValues(alpha: 0.15)
            : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(
          color: _softAccent.withValues(alpha: isDark ? 0.25 : 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _softAccent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: AppText.sizeCaption,
                color: isDark ? _softAccent : const Color(0xFF047857),
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySelectionNotice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptySelectionNotice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.mutedText(context), size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: appFont(
                color: AppTheme.mutedText(context),
                fontSize: AppText.sizeBody,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingSummary extends StatelessWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> reviews;

  const _RatingSummary({required this.trip, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final rating = _ratingValue(trip);
    final count = _reviewCount(trip, reviews);

    if (rating <= 0 || count <= 0) {
      return Text(
        'ยังไม่มีรีวิว',
        style: appFont(
          color: _mutedText,
          fontSize: AppText.sizeLabel,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return _RatingPill(trip: trip, reviews: reviews);
  }
}

class _RatingPill extends StatelessWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> reviews;

  const _RatingPill({required this.trip, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final rating = _ratingValue(trip);
    final count = _reviewCount(trip, reviews);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.warningTint(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(
          color: const Color(0xFFE8A117).withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFE8A117)),
          const SizedBox(width: 4),
          Text(
            numberText(rating, fallback: '0'),
            style: appFont(
              color: AppTheme.onSurface(context),
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count รีวิว',
            style: appFont(
              color: AppTheme.mutedText(context),
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades + gently lifts its child into place the first time it scrolls into the
/// viewport, giving the long detail page a calm, premium cascade. Purely
/// visual (Opacity/translate don't change layout, so scroll math stays stable).
/// Reveals immediately when there's no enclosing scrollable, so content can
/// never get stuck hidden.
class _RevealOnScroll extends StatefulWidget {
  final Widget child;

  const _RevealOnScroll({required this.child});

  @override
  State<_RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<_RevealOnScroll> {
  bool _shown = false;
  ScrollPosition? _position;
  Timer? _fallbackReveal;

  @override
  void initState() {
    super.initState();
    // Safety net: reveal regardless if the scroll-based check never fires it.
    // Without this, a section sitting below the fold stays at opacity 0 forever
    // when the user doesn't scroll (e.g. the page grew after data loaded but no
    // scroll event was emitted to re-run the position check).
    _fallbackReveal = Timer(const Duration(milliseconds: 700), _reveal);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _position = Scrollable.maybeOf(context)?.position;
      if (_position == null) {
        _reveal();
        return;
      }
      _position!.addListener(_check);
      _check();
    });
  }

  void _check() {
    if (_shown || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final dy = box.localToGlobal(Offset.zero).dy;
    // Reveal a little before the section's top edge reaches the bottom of the
    // screen, so it eases in rather than popping at the very edge.
    if (dy < MediaQuery.sizeOf(context).height * 0.92) _reveal();
  }

  void _reveal() {
    if (_shown || !mounted) return;
    _fallbackReveal?.cancel();
    setState(() => _shown = true);
    _position?.removeListener(_check);
  }

  @override
  void dispose() {
    _fallbackReveal?.cancel();
    _position?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, 0.04),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
