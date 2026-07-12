part of 'customer_app_screen.dart';

class AllTripsScreen extends StatefulWidget {
  /// Optional banner pinned above the filters — used to explain a special entry
  /// flow, e.g. "pick a trip to start a group".
  final Widget? introBanner;

  /// Whether the app bar shows a back button. Defaults to true for the pushed
  /// usages (from home / trip finder / group flow); the bottom-nav tab passes
  /// false so it never shows a stray back arrow when a detail page is pushed
  /// over it on the root navigator.
  final bool showBackButton;

  /// Pre-fills the search box (and the first fetch) so this screen can act as a
  /// dedicated results page when opened from the home search bar.
  final String? initialSearch;

  const AllTripsScreen({
    super.key,
    this.introBanner,
    this.showBackButton = true,
    this.initialSearch,
  });

  @override
  State<AllTripsScreen> createState() => _AllTripsScreenState();
}

class _AllTripsScreenState extends State<AllTripsScreen> {
  final _searchController = TextEditingController();
  final _difficulties = const [
    ('easy', 'ระดับเริ่มต้น'),
    ('medium', 'ระดับปานกลาง'),
    ('hard', 'ระดับท้าทาย'),
  ];

  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _categories = [];
  Map<String, dynamic>? _meta;
  bool _loading = true;
  String _selectedType = '';
  String _selectedDifficulty = '';
  String _sortOrder = 'popular';
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null) {
      _searchController.text = widget.initialSearch!.trim();
    }
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchTrips());
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchTrips([int page = 1]) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final app = context.read<AppProvider>();
      if (_categories.isEmpty) {
        _categories = app.categories.map(asMap).toList();
      }

      final response = await app.api.get(
        'trips',
        query: {
          'page': page,
          'per_page': 12,
          'type': _selectedType,
          'difficulty': _selectedDifficulty,
          'search': _searchController.text.trim(),
        },
      );

      if (_categories.isEmpty) {
        final categoryResponse = await app.api.get('categories');
        _categories = List<dynamic>.from(
          app.api.data(categoryResponse) ?? [],
        ).map(asMap).toList();
      }

      if (!mounted) return;
      setState(() {
        _trips = List<dynamic>.from(
          app.api.data(response) ?? [],
        ).map(asMap).toList();
        _meta = app.api.meta(response);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _sortedTrips {
    final list = [..._trips];
    if (_sortOrder == 'price_asc') {
      list.sort((a, b) => _tripPrice(a).compareTo(_tripPrice(b)));
    } else if (_sortOrder == 'price_desc') {
      list.sort((a, b) => _tripPrice(b).compareTo(_tripPrice(a)));
    }
    return list;
  }

  int get _totalConfirmedParticipants {
    return _trips.fold<int>(
      0,
      (sum, trip) =>
          sum +
          (int.tryParse(textOf(trip['confirmed_passengers_count'], '0')) ?? 0),
    );
  }

  int get _currentPage =>
      int.tryParse(textOf(_meta?['current_page'], '1')) ?? 1;
  int get _lastPage => int.tryParse(textOf(_meta?['last_page'], '1')) ?? 1;
  int get _totalTrips =>
      int.tryParse(textOf(_meta?['total'], _trips.length.toString())) ??
      _trips.length;

  void _toggleType(String value) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedType = _selectedType == value ? '' : value;
      if (_selectedType != 'trekking') _selectedDifficulty = '';
    });
    // Apply immediately so picking a category (including ones with no trips)
    // refreshes the list right away instead of leaving the previous results.
    _fetchTrips();
  }

  void _toggleDifficulty(String value) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDifficulty = _selectedDifficulty == value ? '' : value;
    });
    _fetchTrips();
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedType = '';
      _selectedDifficulty = '';
      _sortOrder = 'popular';
    });
    _fetchTrips();
  }

  String _categoryLabel(String value) {
    final category = _categories.firstWhere(
      (item) => textOf(item['slug']) == value,
      orElse: () => const <String, dynamic>{},
    );
    return textOf(
      category['name'],
      value.isEmpty ? 'ทริป' : _tripTypeLabel(value),
    );
  }

  bool get _hasFilters =>
      _selectedType.isNotEmpty ||
      _selectedDifficulty.isNotEmpty ||
      _searchController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: RefreshIndicator(
        onRefresh: () => _fetchTrips(_currentPage),
        child: CustomScrollView(
          slivers: [
            TravelSliverAppBar(
              title: 'กิจกรรมและทริปทั้งหมด',
              showBackButton: widget.showBackButton,
            ),
            SliverToBoxAdapter(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.introBanner != null) ...[
                        widget.introBanner!,
                        const SizedBox(height: 18),
                      ],
                      _TripsFilterPanel(
                        searchController: _searchController,
                        categories: _categories,
                        selectedType: _selectedType,
                        selectedDifficulty: _selectedDifficulty,
                        difficulties: _difficulties,
                        onToggleType: _toggleType,
                        onToggleDifficulty: _toggleDifficulty,
                        onApply: () => _fetchTrips(),
                        onClear: _clearFilters,
                        hasFilters: _hasFilters,
                      ),
                      const SizedBox(height: 22),
                      _TripsResultsToolbar(
                        totalTrips: _totalTrips,
                        participants: _totalConfirmedParticipants,
                        sortOrder: _sortOrder,
                        onSortChanged: (value) {
                          if (value == null) return;
                          HapticFeedback.selectionClick();
                          setState(() => _sortOrder = value);
                        },
                      ),
                      const SizedBox(height: 18),
                      if (_loading)
                        const _TripsLoadingCard()
                      else if (_error != null)
                        _TripsErrorCard(
                          message: _error!,
                          onRetry: () => _fetchTrips(_currentPage),
                        )
                      else if (_trips.isEmpty)
                        const _EmptyState(
                          icon: Icons.explore_off_rounded,
                          title: 'ไม่พบกิจกรรมที่ตรงกับเงื่อนไข',
                          body: 'ลองปรับตัวกรองหรือคำค้นหา แล้วค้นหาอีกครั้ง',
                        )
                      else ...[
                        for (var index = 0;
                            index < _sortedTrips.length;
                            index++) ...[
                          if (index > 0) const SizedBox(height: 18),
                          _RevealOnMount(
                            delay: Duration(
                              milliseconds: 45 * (index.clamp(0, 8)),
                            ),
                            child: _AllTripCard(
                              trip: _sortedTrips[index],
                              typeLabel: _categoryLabel(
                                textOf(
                                  _sortedTrips[index]['type'] ??
                                      _sortedTrips[index]['category_slug'] ??
                                      _sortedTrips[index]['category_name'] ??
                                      _sortedTrips[index]['category'],
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (_lastPage > 1) ...[
                          const SizedBox(height: 20),
                          _TripsPaginationBar(
                            currentPage: _currentPage,
                            lastPage: _lastPage,
                            onPageSelected: _fetchTrips,
                          ),
                        ],
                      ],
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

class _TripsFilterPanel extends StatelessWidget {
  final TextEditingController searchController;
  final List<Map<String, dynamic>> categories;
  final String selectedType;
  final String selectedDifficulty;
  final List<(String, String)> difficulties;
  final ValueChanged<String> onToggleType;
  final ValueChanged<String> onToggleDifficulty;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final bool hasFilters;

  const _TripsFilterPanel({
    required this.searchController,
    required this.categories,
    required this.selectedType,
    required this.selectedDifficulty,
    required this.difficulties,
    required this.onToggleType,
    required this.onToggleDifficulty,
    required this.onApply,
    required this.onClear,
    required this.hasFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FilterTitle(icon: Icons.search_rounded, label: 'ค้นหา'),
          const SizedBox(height: 10),
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onApply(),
            decoration: InputDecoration(
              hintText: 'ค้นหาทริป...',
              hintStyle: appFont(
                color: AppTheme.mutedText(context),
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: AppTheme.mutedText(context),
              ),
              isDense: true,
              filled: true,
              fillColor: AppTheme.subtleSurface(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 1.5,
                ),
              ),
            ),
            style: appFont(
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 20),
          const _FilterTitle(icon: Icons.category_rounded, label: 'หมวดหมู่กิจกรรม'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in categories)
                if (textOf(category['slug']).isNotEmpty)
                  _FilterChipButton(
                    label: textOf(category['name'], textOf(category['slug'])),
                    icon: categoryIcon(textOf(category['icon']).isEmpty
                        ? null
                        : textOf(category['icon'])),
                    selected: selectedType == textOf(category['slug']),
                    onTap: () => onToggleType(textOf(category['slug'])),
                  ),
            ],
          ),
          if (selectedType == 'trekking') ...[
            const SizedBox(height: 20),
            const _FilterTitle(icon: Icons.terrain_rounded, label: 'ระดับความยาก'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in difficulties)
                  _FilterChipButton(
                    label: item.$2,
                    selected: selectedDifficulty == item.$1,
                    onTap: () => onToggleDifficulty(item.$1),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.filter_list_rounded, size: 18),
              label: const Text('ใช้ตัวกรอง'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: appFont(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text(
                  'ล้างตัวกรอง',
                  style: appFont(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.mutedText(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterTitle extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FilterTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 17),
        const SizedBox(width: 8),
        Text(
          label,
          style: appFont(
            color: AppTheme.textMain,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Optional leading glyph (used by category chips). When absent the chip
  /// shows a check mark while selected instead.
  final IconData? icon;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor
              : AppTheme.primaryColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: selected ? Colors.white : AppTheme.primaryColor,
                size: 15,
              ),
              const SizedBox(width: 5),
            ] else if (selected) ...[
              const Icon(Icons.check_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: appFont(
                color: selected ? Colors.white : AppTheme.primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripsResultsToolbar extends StatelessWidget {
  final int totalTrips;
  final int participants;
  final String sortOrder;
  final ValueChanged<String?> onSortChanged;

  const _TripsResultsToolbar({
    required this.totalTrips,
    required this.participants,
    required this.sortOrder,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _InfoPill(text: 'พบทริปทั้งหมด $totalTrips', icon: Icons.explore),
            if (participants > 0)
              _InfoPill(
                text: '$participants คนร่วมเดินทางแล้ว',
                icon: Icons.group_rounded,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.border(context).withValues(alpha: 0.55),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: sortOrder,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              borderRadius: BorderRadius.circular(14),
              isExpanded: true,
              style: appFont(
                color: AppTheme.textMain,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'popular',
                  child: Text('เรียงโดย: ทริปยอดนิยม'),
                ),
                DropdownMenuItem(
                  value: 'price_asc',
                  child: Text('เรียงโดย: ราคาจากน้อยไปมาก'),
                ),
                DropdownMenuItem(
                  value: 'price_desc',
                  child: Text('เรียงโดย: ราคาจากมากไปน้อย'),
                ),
              ],
              onChanged: onSortChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String text;
  final IconData icon;

  const _InfoPill({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: appFont(
              color: AppTheme.primaryColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer placeholders shown while trips load — mirror the real full-width
/// card silhouette so the layout doesn't jump when results arrive.
class _TripsLoadingCard extends StatelessWidget {
  const _TripsLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < 3; index++) ...[
          if (index > 0) const SizedBox(height: 18),
          _RevealOnMount(
            delay: Duration(milliseconds: 50 * index),
            child: const _TripCardSkeleton(),
          ),
        ],
      ],
    );
  }
}

class _TripCardSkeleton extends StatelessWidget {
  const _TripCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: SkeletonBox(borderRadius: BorderRadius.circular(18)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(
                  width: double.infinity,
                  height: 16,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 8),
                SkeletonBox(
                  width: 140,
                  height: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(
                      width: 90,
                      height: 22,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    SkeletonBox(
                      width: 120,
                      height: 38,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fade + gentle rise as a widget first appears, after an optional [delay] so a
/// grid of these cascades in. Animates once on mount.
class _RevealOnMount extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _RevealOnMount({required this.child, this.delay = Duration.zero});

  @override
  State<_RevealOnMount> createState() => _RevealOnMountState();
}

class _RevealOnMountState extends State<_RevealOnMount> {
  bool _shown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // A zero-duration timer still fires after the first frame, so the card
    // always animates in from hidden rather than popping in at full opacity.
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, 0.06),
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Press-scale wrapper: dips slightly on tap-down and fires a light haptic, so
/// tapping a card feels physical. Falls back to a plain tap when [onTap] null.
class _PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  const _PressableCard({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _down = false;

  void _set(bool down) {
    if (mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _TripsErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _TripsErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: AppTheme.textSecondary,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'โหลดข้อมูลทริปไม่สำเร็จ',
            style: appFont(
              color: AppTheme.textMain,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: appFont(
              color: AppTheme.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('ลองใหม่'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: appFont(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width immersive trip card for the "all trips" list. Leads with a large
/// 16:10 hero image carrying the type / women-only / scarcity badges and a
/// glassy rating chip, then a content block with title, location, duration,
/// booking social proof, and a price + CTA footer.
class _AllTripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final String typeLabel;

  const _AllTripCard({required this.trip, required this.typeLabel});

  @override
  Widget build(BuildContext context) {
    final image = ApiConfig.mediaUrl(
      trip['cover_image'] ?? trip['thumbnail_image'],
    );
    final slug = textOf(trip['slug']);
    final title = textOf(trip['title'], '-');
    final location = textOf(trip['location'], 'ประเทศไทย');
    final duration = textOf(trip['duration_days'], '1');
    final reviewCount = int.tryParse(textOf(trip['review_count'], '0')) ?? 0;
    final seatsLeft = int.tryParse(textOf(trip['seats_left']));
    final almostFull = _asBool(trip['is_almost_full']) &&
        seatsLeft != null &&
        seatsLeft > 0;
    final booked =
        int.tryParse(textOf(trip['booked_passengers_count'], '0')) ?? 0;

    return _PressableCard(
      onTap: slug.isEmpty
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TripDetailScreen(slug: slug)),
            ),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.border(context).withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero image ──────────────────────────────────────────────
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image.isEmpty)
                    Container(
                      color: AppTheme.subtleSurface(context),
                      child: const Icon(
                        Icons.image_rounded,
                        color: AppTheme.textSecondary,
                        size: 44,
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: AppTheme.subtleSurface(context)),
                      errorWidget: (context, url, error) => Container(
                        color: AppTheme.subtleSurface(context),
                        child: const Icon(Icons.broken_image_rounded),
                      ),
                    ),
                  // Scrim from the bottom for badge legibility + depth.
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x59000000)],
                          stops: [0.55, 1],
                        ),
                      ),
                    ),
                  ),
                  // Top row: type + women-only on the left, rating on the right.
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left group: type + women-only badges. Wrapped in
                        // Expanded so it takes the remaining width and the
                        // rating chip stays pinned flush to the right.
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: _OverlayPill(
                                  text: typeLabel,
                                  icon: null,
                                  backgroundColor: _tripTypeColor(
                                    textOf(trip['type']),
                                  ).withValues(alpha: 0.95),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              if (_asBool(trip['is_women_only'])) ...[
                                const SizedBox(width: 6),
                                _OverlayPill(
                                  text: 'หญิงล้วน',
                                  icon: Icons.female_rounded,
                                  backgroundColor:
                                      Colors.pinkAccent.withValues(alpha: 0.95),
                                  foregroundColor: Colors.white,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Right: rating, or "ทริปใหม่" when there are no reviews.
                        if (reviewCount > 0)
                          _OverlayPill(
                            text:
                                '${numberText(trip['rating'], fallback: '0')} ($reviewCount)',
                            icon: Icons.star_rounded,
                            backgroundColor:
                                Colors.black.withValues(alpha: 0.42),
                            foregroundColor: Colors.white,
                          )
                        else
                          _OverlayPill(
                            text: 'ทริปใหม่',
                            icon: Icons.auto_awesome_rounded,
                            backgroundColor:
                                Colors.black.withValues(alpha: 0.42),
                            foregroundColor: Colors.white,
                          ),
                      ],
                    ),
                  ),
                  // Bottom-left scarcity badge.
                  if (almostFull)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: _OverlayPill(
                        text: 'เหลือ $seatsLeft ที่นั่ง',
                        icon: Icons.local_fire_department_rounded,
                        backgroundColor:
                            const Color(0xFFEA580C).withValues(alpha: 0.95),
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            // ── Content ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      color: AppTheme.textMain,
                      fontSize: 17.5,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appFont(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$duration วัน',
                        style: appFont(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (booked > 0) ...[
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        const Icon(
                          Icons.group_rounded,
                          size: 15,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$booked คนจองแล้ว',
                          style: appFont(
                            color: AppTheme.primaryColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: AppTheme.border(context).withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'เริ่มต้นเพียง',
                              style: appFont(
                                color: AppTheme.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _priceLabel(trip),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appFont(
                                color: AppTheme.textMain,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ดูรายละเอียด',
                              style: appFont(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripsPaginationBar extends StatelessWidget {
  final int currentPage;
  final int lastPage;
  final ValueChanged<int> onPageSelected;

  const _TripsPaginationBar({
    required this.currentPage,
    required this.lastPage,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final pages = _paginationPages(currentPage, lastPage);

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageButton(
            icon: Icons.chevron_left_rounded,
            enabled: currentPage > 1,
            onTap: () => onPageSelected(currentPage - 1),
          ),
          const SizedBox(width: 6),
          for (final page in pages) ...[
            if (page == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '…',
                  style: appFont(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              _NumberPageButton(
                page: page,
                selected: page == currentPage,
                onTap: () => onPageSelected(page),
              ),
            const SizedBox(width: 6),
          ],
          _PageButton(
            icon: Icons.chevron_right_rounded,
            enabled: currentPage < lastPage,
            onTap: () => onPageSelected(currentPage + 1),
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PageButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon),
    );
  }
}

class _NumberPageButton extends StatelessWidget {
  final int page;
  final bool selected;
  final VoidCallback onTap;

  const _NumberPageButton({
    required this.page,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: selected ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : AppTheme.surface(context),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor
                : AppTheme.border(context).withValues(alpha: 0.55),
          ),
        ),
        child: Text(
          page.toString(),
          style: appFont(
            color: selected ? Colors.white : AppTheme.textMain,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}

class _PromotionListCard extends StatelessWidget {
  final Map<String, dynamic> promotion;

  const _PromotionListCard({required this.promotion});

  String _discountLabel() {
    final type = promotion['type']?.toString() ?? '';
    final value = promotion['value'];
    if (value == null) return '';
    final num v = value is num ? value : num.tryParse(value.toString()) ?? 0;
    return type == 'percent'
        ? 'ลด ${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)}%'
        : 'ลด ฿${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)}';
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  int? _daysUntil(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    final end = DateTime.tryParse(raw);
    if (end == null) return null;
    final now = DateTime.now();
    return DateTime(end.year, end.month, end.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  @override
  Widget build(BuildContext context) {
    final code = promotion['code']?.toString() ?? '';
    final name = promotion['name']?.toString() ?? '-';
    final startDate = promotion['start_date'];
    final endDate = promotion['end_date'];
    final maxUses = int.tryParse('${promotion['max_uses'] ?? ''}');
    final usedCount = int.tryParse('${promotion['used_count'] ?? 0}') ?? 0;
    final daysLeft = _daysUntil(endDate);
    final expiringSoon = daysLeft != null && daysLeft >= 0 && daysLeft <= 7;

    final metaPills = <Widget>[
      if (startDate != null)
        _MetaPill(
          icon: Icons.calendar_today_outlined,
          text: 'เริ่ม ${_formatDate(startDate.toString())}',
        ),
      if (endDate != null)
        _MetaPill(
          icon: Icons.event_outlined,
          text: 'ถึง ${_formatDate(endDate.toString())}',
        ),
    ];
    if (metaPills.isEmpty) {
      metaPills.add(
        const _MetaPill(
          icon: Icons.verified_outlined,
          text: 'ใช้ได้ทุกการจอง',
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          // Brand gradient header — discount + copyable code.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryColor, AppTheme.accentColor],
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned(
                  right: -24,
                  top: -34,
                  child: _SoftCircle(size: 96, opacity: 0.10),
                ),
                const Positioned(
                  right: 28,
                  bottom: -42,
                  child: _SoftCircle(size: 72, opacity: 0.08),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: appFont(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _discountLabel(),
                            style: appFont(
                              color: AppTheme.primaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _CodeChip(code: code),
                        const Spacer(),
                        if (expiringSoon) _ExpiryChip(daysLeft: daysLeft),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Details on surface, separated by a coupon tear line.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DashedDivider(
                  color: AppTheme.border(context).withValues(alpha: 0.9),
                ),
                const SizedBox(height: 14),
                Wrap(spacing: 10, runSpacing: 8, children: metaPills),
                if (maxUses != null && maxUses > 0) ...[
                  const SizedBox(height: 14),
                  _PromotionUsageBar(used: usedCount, max: maxUses),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _SoftCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ExpiryChip extends StatelessWidget {
  final int daysLeft;

  const _ExpiryChip({required this.daysLeft});

  @override
  Widget build(BuildContext context) {
    final label = daysLeft <= 0 ? 'หมดเขตวันนี้' : 'เหลือ $daysLeft วัน';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: appFont(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  final Color color;

  const _DashedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const dashGap = 4.0;
        final count = (constraints.maxWidth / (dashWidth + dashGap))
            .floor()
            .clamp(1, 999);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: dashWidth, height: 1.5, color: color),
          ),
        );
      },
    );
  }
}

class _PromotionUsageBar extends StatelessWidget {
  final int used;
  final int max;

  const _PromotionUsageBar({required this.used, required this.max});

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (used / max).clamp(0.0, 1.0);
    final remaining = (max - used).clamp(0, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'สิทธิ์การใช้งาน',
              style: appFont(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              'เหลือ $remaining จาก $max สิทธิ์',
              style: appFont(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppTheme.subtleSurface(context),
            valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
          ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(
            text,
            style: appFont(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

