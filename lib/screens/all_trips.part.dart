part of 'customer_app_screen.dart';

class AllTripsScreen extends StatefulWidget {
  const AllTripsScreen({super.key});

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
    setState(() {
      _selectedType = _selectedType == value ? '' : value;
      if (_selectedType != 'trekking') _selectedDifficulty = '';
    });
  }

  void _toggleDifficulty(String value) {
    setState(() {
      _selectedDifficulty = _selectedDifficulty == value ? '' : value;
    });
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
            const TravelSliverAppBar(title: 'กิจกรรมและทริปทั้งหมด'),
            SliverToBoxAdapter(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AllTripsHero(),
                      const SizedBox(height: 22),
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
                        for (final trip in _sortedTrips) ...[
                          _AllTripCard(
                            trip: trip,
                            typeLabel: _categoryLabel(
                              textOf(
                                trip['type'] ??
                                    trip['category_slug'] ??
                                    trip['category_name'] ??
                                    trip['category'],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_lastPage > 1)
                          _TripsPaginationBar(
                            currentPage: _currentPage,
                            lastPage: _lastPage,
                            onPageSelected: _fetchTrips,
                          ),
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

class _AllTripsHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.explore_rounded,
                color: AppTheme.primaryColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'ค้นพบประสบการณ์ใหม่',
                style: GoogleFonts.anuphan(
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'กิจกรรมและทริปทั้งหมด',
          style: GoogleFonts.anuphan(
            color: AppTheme.textMain,
            fontSize: 32,
            height: 1.12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'สำรวจทริปที่คัดสรรมาเพื่อคุณ ตั้งแต่ดำน้ำตื้น เดินป่า จนถึงบริการรถตู้ระดับพรีเมียม',
          style: GoogleFonts.anuphan(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.55,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
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
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppTheme.subtleSurface(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
            ),
            style: GoogleFonts.anuphan(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          const _FilterTitle(icon: Icons.category_rounded, label: 'หมวดหมู่กิจกรรม'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in categories)
                _FilterChipButton(
                  label: textOf(category['name'], textOf(category['slug'])),
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
              icon: const Icon(Icons.filter_list_rounded),
              label: const Text('ใช้ตัวกรอง'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: GoogleFonts.anuphan(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('ล้างตัวกรอง'),
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
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.anuphan(
            color: AppTheme.textMain,
            fontSize: 14,
            fontWeight: FontWeight.w900,
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

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor
              : AppTheme.subtleSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.border(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.anuphan(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
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
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: sortOrder,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              borderRadius: BorderRadius.circular(18),
              isExpanded: true,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.anuphan(
              color: AppTheme.textMain,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripsLoadingCard extends StatelessWidget {
  const _TripsLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryColor),
          const SizedBox(height: 18),
          Text(
            'กำลังค้นหาทริปที่ดีที่สุดให้คุณ...',
            style: GoogleFonts.anuphan(
              color: AppTheme.textMain,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: AppTheme.textSecondary,
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            'โหลดข้อมูลทริปไม่สำเร็จ',
            style: GoogleFonts.anuphan(
              color: AppTheme.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.anuphan(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }
}

class _AllTripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final String typeLabel;

  const _AllTripCard({required this.trip, required this.typeLabel});

  @override
  Widget build(BuildContext context) {
    final image = ApiConfig.mediaUrl(
      trip['thumbnail_image'] ?? trip['cover_image'],
    );
    final slug = textOf(trip['slug']);
    final title = textOf(trip['title'], '-');
    final description = textOf(trip['description']);
    final location = textOf(trip['location'], 'ประเทศไทย');
    final duration = textOf(trip['duration_days'], '1');
    final difficulty = textOf(trip['difficulty']);
    final joined =
        int.tryParse(textOf(trip['confirmed_passengers_count'], '0')) ?? 0;
    final reviewCount = int.tryParse(textOf(trip['review_count'], '0')) ?? 0;

    return InkWell(
      onTap: slug.isEmpty
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TripDetailScreen(slug: slug)),
            ),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppTheme.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: AspectRatio(
                aspectRatio: 1.12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (image.isEmpty)
                        Container(
                          color: AppTheme.subtleSurface(context),
                          child: const Icon(
                            Icons.image_rounded,
                            color: AppTheme.textSecondary,
                            size: 46,
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
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.62),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _OverlayPill(
                              text: typeLabel,
                              icon: null,
                              backgroundColor: _tripTypeColor(
                                textOf(trip['type']),
                              ).withValues(alpha: 0.92),
                              foregroundColor: Colors.white,
                            ),
                            if (_asBool(trip['is_women_only'])) ...[
                              const SizedBox(height: 8),
                              _OverlayPill(
                                text: 'หญิงล้วน',
                                icon: Icons.female_rounded,
                                backgroundColor: Colors.pinkAccent.withValues(
                                  alpha: 0.92,
                                ),
                                foregroundColor: Colors.white,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 14,
                        child: Row(
                          children: [
                            _OverlayPill(
                              text: '$duration วัน',
                              icon: Icons.schedule_rounded,
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.34,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            const Spacer(),
                            if (difficulty.isNotEmpty)
                              _OverlayPill(
                                text: _difficultyLabel(difficulty),
                                icon: Icons.terrain_rounded,
                                backgroundColor: Colors.black.withValues(
                                  alpha: 0.34,
                                ),
                                foregroundColor: Colors.white,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFB020),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      if (reviewCount > 0) ...[
                        Text(
                          numberText(trip['rating'], fallback: '0'),
                          style: GoogleFonts.anuphan(
                            color: AppTheme.textMain,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '($reviewCount รีวิว)',
                          style: GoogleFonts.anuphan(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else
                        Text(
                          'ยังไม่มีรีวิว',
                          style: GoogleFonts.anuphan(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const Spacer(),
                      if (joined > 0)
                        _MiniStatPill(
                          icon: Icons.group_rounded,
                          text: '$joined คนร่วมทริป',
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.textMain,
                      fontSize: 18,
                      height: 1.22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description.isNotEmpty ? description : location,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: AppTheme.border(context), height: 1),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pricePrefix(trip),
                              style: GoogleFonts.anuphan(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _priceLabel(trip),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.anuphan(
                                color: AppTheme.textMain,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.subtleSurface(context),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppTheme.primaryColor,
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

class _MiniStatPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniStatPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 15),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.anuphan(
              color: AppTheme.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
                  '...',
                  style: GoogleFonts.anuphan(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w900,
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
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : AppTheme.surface(context),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.border(context),
          ),
        ),
        child: Text(
          page.toString(),
          style: GoogleFonts.anuphan(
            color: selected ? Colors.white : AppTheme.textMain,
            fontWeight: FontWeight.w900,
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

  @override
  Widget build(BuildContext context) {
    final code = promotion['code']?.toString() ?? '';
    final name = promotion['name']?.toString() ?? '-';
    final startDate = promotion['start_date'];
    final endDate = promotion['end_date'];
    final maxUses = promotion['max_uses'];
    final usedCount = promotion['used_count'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryColor, AppTheme.accentColor],
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.anuphan(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _discountLabel(),
                    style: GoogleFonts.anuphan(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CodeChip(code: code),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
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
                    if (maxUses != null)
                      _MetaPill(
                        icon: Icons.people_outline_rounded,
                        text: 'ใช้แล้ว $usedCount/$maxUses',
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
            style: GoogleFonts.anuphan(
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

