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
  // ตัวเลือกปลายทางพร้อมจำนวนทริปจริง จาก GET trips/destinations — คืนเฉพาะ
  // ภาค/ประเทศที่มีทริปอยู่ ปุ่มทุกปุ่มจึงพาไปหน้าที่มีของเสมอ
  Map<String, dynamic> _destinations = const {};
  bool _loading = true;
  String _selectedType = '';
  String _selectedDifficulty = '';
  String _selectedDestination = '';
  String _selectedCountry = '';
  String _selectedRegion = '';
  String _sortOrder = 'popular';
  String? _error;
  Timer? _searchDebounce;

  /// คำค้นล่าสุดของเครื่องนี้ — โชว์เป็นชิปใต้ช่องค้นหาตอนช่องยังว่าง
  List<String> _recentSearches = const [];

  /// คำค้นที่ผู้ใช้ "ตั้งใจค้น" (กด Enter, มาจากช่องค้นหาหน้าแรก หรือแตะชิป
  /// คำค้นล่าสุด) และยังรอผลอยู่ จะถูกบันทึกลงประวัติก็ต่อเมื่อผลกลับมาแล้ว
  /// เจอทริปจริง — ระหว่างพิมพ์ (debounce) ไม่นับ ประวัติจึงไม่มีคำที่พิมพ์
  /// ค้างครึ่งคำหรือคำที่ค้นแล้วไม่เจออะไรเลย
  String? _pendingHistoryQuery;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null) {
      _searchController.text = widget.initialSearch!.trim();
      // คำนี้ผู้ใช้กดค้นมาจากหน้าแรกแล้ว นับเป็นการค้นจริงเท่ากับกดค้นที่นี่
      final initial = _searchController.text.trim();
      _pendingHistoryQuery = initial.isEmpty ? null : initial;
    }
    _searchController.addListener(_handleSearchChanged);
    _loadRecentSearches();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTrips();
      _fetchDestinations();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // Rebuild for the clear button / active-filter state, and refetch shortly
  // after the user stops typing so search feels live without a separate
  // "apply" button.
  void _handleSearchChanged() {
    if (!mounted) return;
    // คำเปลี่ยนแล้ว ผลที่กำลังจะกลับมาไม่ใช่ของคำที่รอบันทึกอีกต่อไป
    _pendingHistoryQuery = null;
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _fetchTrips();
    });
  }

  // Enter key on the keyboard — fetch immediately instead of waiting out the
  // debounce, and drop the keyboard so results are visible.
  void _applySearch() {
    _searchDebounce?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    final query = _searchController.text.trim();
    _pendingHistoryQuery = query.isEmpty ? null : query;
    _fetchTrips();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchDebounce?.cancel();
    _pendingHistoryQuery = null;
    _fetchTrips();
  }

  Future<void> _loadRecentSearches() async {
    final history = await SearchHistoryService.instance.read();
    if (!mounted) return;
    setState(() => _recentSearches = history);
  }

  /// เรียกที่ปลายทางของ [_fetchTrips] เท่านั้น จึงบันทึกได้เฉพาะคำที่ค้นแล้ว
  /// มีทริปจริง
  void _settleSearchRecord() {
    final pending = _pendingHistoryQuery;
    if (pending == null) return;
    _pendingHistoryQuery = null;
    if (_trips.isEmpty) return;
    unawaited(_rememberSearch(pending));
  }

  Future<void> _rememberSearch(String query) async {
    await SearchHistoryService.instance.add(query);
    await _loadRecentSearches();
  }

  /// แตะชิปคำค้นล่าสุด — เติมคำลงช่องแล้วค้นทันที ไม่ต้องรอ debounce
  void _applyRecentSearch(String query) {
    HapticFeedback.selectionClick();
    // ตั้งค่าผ่าน value เพื่อให้เคอร์เซอร์ไปอยู่ท้ายคำ พิมพ์ต่อได้เลย
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    // ต้องอยู่หลังบรรทัดบน เพราะ listener ของช่องค้นหาเพิ่งล้างค่านี้ทิ้ง
    _applySearch();
  }

  Future<void> _removeRecentSearch(String query) async {
    HapticFeedback.selectionClick();
    await SearchHistoryService.instance.remove(query);
    await _loadRecentSearches();
  }

  Future<void> _clearRecentSearches() async {
    HapticFeedback.selectionClick();
    await SearchHistoryService.instance.clear();
    await _loadRecentSearches();
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
          'destination': _selectedDestination,
          'country': _selectedCountry,
          'region': _selectedRegion,
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
      _settleSearchRecord();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Facets are decoration, not results — a failure here must leave the trip
  /// list working, so it fails silently and simply hides the destination row.
  Future<void> _fetchDestinations() async {
    try {
      final app = context.read<AppProvider>();
      final response = await app.api.get('trips/destinations');
      if (!mounted) return;
      setState(() => _destinations = asMap(app.api.data(response) ?? {}));
    } catch (_) {
      // เงียบไว้ — แถบเลือกปลายทางจะไม่ขึ้นเท่านั้น
    }
  }

  Map<String, dynamic> get _domesticFacet => asMap(_destinations['domestic']);
  Map<String, dynamic> get _internationalFacet =>
      asMap(_destinations['international']);

  int get _domesticCount =>
      int.tryParse(textOf(_domesticFacet['count'], '0')) ?? 0;
  int get _internationalCount =>
      int.tryParse(textOf(_internationalFacet['count'], '0')) ?? 0;

  List<Map<String, dynamic>> get _countryFacets => List<dynamic>.from(
    _internationalFacet['countries'] ?? const [],
  ).map(asMap).toList();

  List<Map<String, dynamic>> get _regionFacets =>
      List<dynamic>.from(_domesticFacet['regions'] ?? const [])
          .map(asMap)
          .toList();

  /// The ในประเทศ / ต่างประเทศ row only earns its space once there is at least
  /// one trip on each side; otherwise a tab would lead to an empty list.
  bool get _showDestinations => _internationalCount > 0 && _domesticCount > 0;

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

  /// ทั้งหมด / ในประเทศ / ต่างประเทศ — ย้ายฝั่งแล้วต้องทิ้งประเทศหรือภาคที่
  /// เลือกไว้ ไม่งั้นจะเหลือเงื่อนไขที่ไม่มีทางมีทริปตรง
  void _selectDestination(String value) {
    if (_selectedDestination == value) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDestination = value;
      _selectedCountry = '';
      _selectedRegion = '';
    });
    _fetchTrips();
  }

  void _toggleCountry(String code) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCountry = _selectedCountry == code ? '' : code;
      if (_selectedCountry.isNotEmpty) {
        _selectedDestination = 'international';
        _selectedRegion = '';
      }
    });
    _fetchTrips();
  }

  void _toggleRegion(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedRegion = _selectedRegion == key ? '' : key;
      if (_selectedRegion.isNotEmpty) {
        _selectedDestination = 'domestic';
        _selectedCountry = '';
      }
    });
    _fetchTrips();
  }

  void _clearFilters() {
    _searchController.clear();
    _searchDebounce?.cancel();
    _pendingHistoryQuery = null;
    setState(() {
      _selectedType = '';
      _selectedDifficulty = '';
      _selectedDestination = '';
      _selectedCountry = '';
      _selectedRegion = '';
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
      _selectedDestination.isNotEmpty ||
      _selectedCountry.isNotEmpty ||
      _selectedRegion.isNotEmpty ||
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
                        showDestinations: _showDestinations,
                        domesticCount: _domesticCount,
                        internationalCount: _internationalCount,
                        countries: _countryFacets,
                        regions: _regionFacets,
                        selectedDestination: _selectedDestination,
                        selectedCountry: _selectedCountry,
                        selectedRegion: _selectedRegion,
                        onSelectDestination: _selectDestination,
                        onToggleCountry: _toggleCountry,
                        onToggleRegion: _toggleRegion,
                        onToggleType: _toggleType,
                        onToggleDifficulty: _toggleDifficulty,
                        onSubmitSearch: _applySearch,
                        onClearSearch: _clearSearch,
                        recentSearches: _recentSearches,
                        onSelectRecent: _applyRecentSearch,
                        onRemoveRecent: _removeRecentSearch,
                        onClearRecents: _clearRecentSearches,
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

/// Concise, Klook/Airbnb-style search section: a single prominent search field
/// with an inline clear button, then a horizontally scrolling row of category
/// chips (led by an "all" option) and an inline difficulty strip. Filters apply
/// live — category taps and debounced typing refetch on their own, so there is
/// no separate "apply" button.
class _TripsFilterPanel extends StatelessWidget {
  final TextEditingController searchController;
  final List<Map<String, dynamic>> categories;
  final String selectedType;
  final String selectedDifficulty;
  final List<(String, String)> difficulties;
  final bool showDestinations;
  final int domesticCount;
  final int internationalCount;
  final List<Map<String, dynamic>> countries;
  final List<Map<String, dynamic>> regions;
  final String selectedDestination;
  final String selectedCountry;
  final String selectedRegion;
  final ValueChanged<String> onSelectDestination;
  final ValueChanged<String> onToggleCountry;
  final ValueChanged<String> onToggleRegion;
  final ValueChanged<String> onToggleType;
  final ValueChanged<String> onToggleDifficulty;
  final VoidCallback onSubmitSearch;
  final VoidCallback onClearSearch;
  final VoidCallback onClear;
  final bool hasFilters;

  /// คำค้นล่าสุด เรียงใหม่สุดก่อน — ว่างได้ (แถบจะไม่ขึ้น)
  final List<String> recentSearches;
  final ValueChanged<String> onSelectRecent;
  final ValueChanged<String> onRemoveRecent;
  final VoidCallback onClearRecents;

  const _TripsFilterPanel({
    required this.searchController,
    required this.categories,
    required this.selectedType,
    required this.selectedDifficulty,
    required this.difficulties,
    required this.showDestinations,
    required this.domesticCount,
    required this.internationalCount,
    required this.countries,
    required this.regions,
    required this.selectedDestination,
    required this.selectedCountry,
    required this.selectedRegion,
    required this.onSelectDestination,
    required this.onToggleCountry,
    required this.onToggleRegion,
    required this.onToggleType,
    required this.onToggleDifficulty,
    required this.onSubmitSearch,
    required this.onClearSearch,
    required this.onClear,
    required this.hasFilters,
    required this.recentSearches,
    required this.onSelectRecent,
    required this.onRemoveRecent,
    required this.onClearRecents,
  });

  @override
  Widget build(BuildContext context) {
    final chipCategories = [
      for (final category in categories)
        if (textOf(category['slug']).isNotEmpty) category,
    ];
    // แถบประเทศขึ้นทั้งบนแท็บ "ทั้งหมด" และ "ต่างประเทศ" เพราะทริปต่างประเทศ
    // คือสิ่งที่หาเจอยากที่สุด ส่วนแถบภาคขึ้นเฉพาะฝั่งในประเทศ
    final showCountryRail =
        countries.isNotEmpty && selectedDestination != 'domestic';
    final showRegionRail =
        regions.isNotEmpty && selectedDestination == 'domestic';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDestinations) ...[
          _DestinationTabs(
            selected: selectedDestination,
            domesticCount: domesticCount,
            internationalCount: internationalCount,
            onSelect: onSelectDestination,
          ),
          const SizedBox(height: 14),
        ],
        _SearchField(
          controller: searchController,
          hasQuery: searchController.text.trim().isNotEmpty,
          onSubmitted: onSubmitSearch,
          onClear: onClearSearch,
        ),
        // ขึ้นเฉพาะตอนช่องค้นหาว่าง — ระหว่างพิมพ์ ผลลัพธ์คือสิ่งที่ผู้ใช้มอง
        // อยู่ ไม่ใช่ประวัติ และแถบนี้จะไปดันผลลัพธ์ลงเปล่า ๆ
        if (recentSearches.isNotEmpty &&
            searchController.text.trim().isEmpty) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const _FilterRailLabel(text: 'ค้นหาล่าสุด'),
              const Spacer(),
              InkWell(
                onTap: onClearRecents,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Text(
                    'ล้างประวัติ',
                    style: appFont(
                      color: AppTheme.mutedText(context),
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ChipStrip(
            children: [
              for (final query in recentSearches)
                _RecentSearchChip(
                  label: query,
                  onTap: () => onSelectRecent(query),
                  onRemove: () => onRemoveRecent(query),
                ),
            ],
          ),
        ],
        if (showCountryRail) ...[
          const SizedBox(height: 14),
          _FilterRailLabel(
            text: selectedDestination == 'international'
                ? 'เลือกประเทศ'
                : 'ทริปต่างประเทศ',
          ),
          const SizedBox(height: 8),
          _ChipStrip(
            children: [
              for (final country in countries)
                _FilterChipButton(
                  label: _destinationChipLabel(
                    '${textOf(country['flag'])} ${textOf(country['name'], textOf(country['code']))}'
                        .trim(),
                    country['count'],
                  ),
                  selected:
                      selectedCountry == textOf(country['code']) &&
                      textOf(country['code']).isNotEmpty,
                  onTap: () => onToggleCountry(textOf(country['code'])),
                ),
            ],
          ),
        ],
        if (showRegionRail) ...[
          const SizedBox(height: 14),
          const _FilterRailLabel(text: 'เลือกภาค'),
          const SizedBox(height: 8),
          _ChipStrip(
            children: [
              for (final region in regions)
                _FilterChipButton(
                  label: _destinationChipLabel(
                    textOf(region['label'], textOf(region['key'])),
                    region['count'],
                  ),
                  selected:
                      selectedRegion == textOf(region['key']) &&
                      textOf(region['key']).isNotEmpty,
                  onTap: () => onToggleRegion(textOf(region['key'])),
                ),
            ],
          ),
        ],
        if (chipCategories.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ChipStrip(
            children: [
              _FilterChipButton(
                label: 'ทั้งหมด',
                icon: Icons.apps_rounded,
                selected: selectedType.isEmpty,
                onTap: () {
                  if (selectedType.isNotEmpty) onToggleType(selectedType);
                },
              ),
              for (final category in chipCategories)
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
        ],
        if (selectedType == 'trekking') ...[
          const SizedBox(height: 10),
          _ChipStrip(
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
        if (hasFilters) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: AppTheme.mutedText(context),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'ล้างตัวกรองทั้งหมด',
                    style: appFont(
                      color: AppTheme.mutedText(context),
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "ญี่ปุ่น (3)" — the count only appears when the facet actually carries one,
/// so a chip never reads "(0)".
String _destinationChipLabel(String label, dynamic count) {
  final total = int.tryParse(textOf(count, '0')) ?? 0;
  return total > 0 ? '$label ($total)' : label;
}

/// Small muted heading above a chip rail.
class _FilterRailLabel extends StatelessWidget {
  final String text;

  const _FilterRailLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: appFont(
        color: AppTheme.mutedText(context),
        fontSize: AppText.sizeLabel,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
    );
  }
}

/// ในประเทศ / ต่างประเทศ segmented row — the primary split of the catalogue,
/// so it sits above the search box rather than among the category chips.
class _DestinationTabs extends StatelessWidget {
  final String selected;
  final int domesticCount;
  final int internationalCount;
  final ValueChanged<String> onSelect;

  const _DestinationTabs({
    required this.selected,
    required this.domesticCount,
    required this.internationalCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = <(String, String, IconData, int)>[
      ('', 'ทั้งหมด', Icons.apps_rounded, domesticCount + internationalCount),
      ('domestic', 'ในประเทศ', Icons.terrain_rounded, domesticCount),
      (
        'international',
        'ต่างประเทศ',
        Icons.flight_takeoff_rounded,
        internationalCount,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: _DestinationTab(
                label: tab.$2,
                icon: tab.$3,
                count: tab.$4,
                selected: selected == tab.$1,
                onTap: () => onSelect(tab.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _DestinationTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _DestinationTab({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : AppTheme.mutedText(context),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                count > 0 ? '$label ($count)' : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  color: selected ? Colors.white : AppTheme.textMain,
                  fontSize: AppText.sizeLabel,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prominent, rounded search field with a live clear button. Rebuilds from the
/// parent on every keystroke, so [hasQuery] toggles the trailing clear icon.
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool hasQuery;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.hasQuery,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmitted(),
      cursorColor: AppTheme.primaryColor,
      style: appFont(fontWeight: FontWeight.w600, fontSize: AppText.sizeSubtitle),
      decoration: InputDecoration(
        hintText: 'ค้นหาทริป ปลายทาง หรือกิจกรรม',
        hintStyle: appFont(
          color: AppTheme.mutedText(context),
          fontSize: AppText.sizeBody,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 21,
          color: AppTheme.mutedText(context),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 46),
        suffixIcon: hasQuery
            ? IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppTheme.mutedText(context),
                ),
                splashRadius: 18,
                tooltip: 'ล้างคำค้นหา',
                onPressed: onClear,
              )
            : null,
        isDense: true,
        filled: true,
        fillColor: AppTheme.subtleSurface(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(
            color: AppTheme.border(context).withValues(alpha: 0.6),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(
            color: AppTheme.border(context).withValues(alpha: 0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

/// A single-line, horizontally scrolling row of filter chips. The strip keeps
/// the section height stable no matter how many categories exist and hints —
/// by clipping the last chip at the edge — that more lie off-screen.
class _ChipStrip extends StatelessWidget {
  final List<Widget> children;

  const _ChipStrip({required this.children});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) => children[index],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Optional leading glyph (used by category chips).
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
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor
              : AppTheme.subtleSurface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor
                : AppTheme.border(context).withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: selected ? Colors.white : AppTheme.mutedText(context),
                size: 16,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: appFont(
                color: selected ? Colors.white : AppTheme.textMain,
                fontSize: AppText.sizeLabel,
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

/// ชิปคำค้นล่าสุด — หน้าตาเดียวกับ [_FilterChipButton] แบบยังไม่ถูกเลือก
/// แต่แบ่งพื้นที่แตะเป็นสองส่วน: ตัวคำค้นไว้ค้นซ้ำ กากบาทไว้ลบคำนั้นทิ้ง
class _RecentSearchChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentSearchChip({
    required this.label,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedText(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        // ให้ทั้งสองปุ่มสูงเต็มชิป พื้นที่แตะจะได้ไม่เหลือแค่ความสูงตัวอักษร
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.only(left: 13, right: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, size: 15, color: muted),
                  const SizedBox(width: 6),
                  // คำค้นยาว ๆ ต้องไม่ลากชิปยาวจนดันชิปอื่นตกขอบจอ
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        color: AppTheme.textMain,
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'ลบ $label ออกจากประวัติการค้นหา',
            child: InkWell(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.only(left: 5, right: 12),
                child: Icon(Icons.close_rounded, size: 15, color: muted),
              ),
            ),
          ),
        ],
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
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: AppTheme.border(context).withValues(alpha: 0.55),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: sortOrder,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              isExpanded: true,
              style: appFont(
                color: AppTheme.textMain,
                fontSize: AppText.sizeBody,
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
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
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
              fontSize: AppText.sizeLabel,
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
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
              child: SkeletonBox(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
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
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                ),
                const SizedBox(height: 8),
                SkeletonBox(
                  width: 140,
                  height: 12,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(
                      width: 90,
                      height: 22,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                    ),
                    SkeletonBox(
                      width: 120,
                      height: 38,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
              fontSize: AppText.sizeTitle,
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
              fontSize: AppText.sizeBody,
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
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              textStyle: appFont(
                fontSize: AppText.sizeBody,
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
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
                              // ป้ายประเทศติดเฉพาะทริปต่างประเทศ — ทริปใน
                              // ประเทศไม่ต้องบอกว่า "ไทย"
                              if (textOf(trip['country_label']).isNotEmpty) ...[
                                const SizedBox(width: 6),
                                _OverlayPill(
                                  text: textOf(trip['country_label']),
                                  icon: Icons.flight_takeoff_rounded,
                                  backgroundColor: const Color(
                                    0xFF0284C7,
                                  ).withValues(alpha: 0.95),
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
                      fontSize: AppText.sizeTitle,
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
                            fontSize: AppText.sizeLabel,
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
                          fontSize: AppText.sizeLabel,
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
                            fontSize: AppText.sizeLabel,
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
                                fontSize: AppText.sizeCaption,
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
                                fontSize: AppText.sizeH2,
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
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ดูรายละเอียด',
                              style: appFont(
                                color: Colors.white,
                                fontSize: AppText.sizeBody,
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
                    fontSize: AppText.sizeSubtitle,
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
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: MinTapTarget(child: Container(
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
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      )),
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
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          // Brand header — discount + copyable code.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: const BoxDecoration(color: AppTheme.primaryColor),
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
                              fontSize: AppText.sizeTitle,
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
                            color: AppTheme.surface(context),
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                          ),
                          child: Text(
                            _discountLabel(),
                            style: appFont(
                              color: AppTheme.primaryColor,
                              fontSize: AppText.sizeLabel,
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
        color: AppTheme.surface(context).withValues(alpha: opacity),
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
        color: AppTheme.surface(context).withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
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
              fontSize: AppText.sizeCaption,
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
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              'เหลือ $remaining จาก $max สิทธิ์',
              style: appFont(
                fontSize: AppText.sizeCaption,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
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
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

