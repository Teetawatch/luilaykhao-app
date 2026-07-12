part of 'customer_app_screen.dart';

/// Apple-style "find the right trip" quiz: 3 quick questions (activity type →
/// difficulty → number of days) then reveals matching trips inline. Reuses the
/// public /trips filter (type/difficulty/min_days/max_days) with progressive
/// relaxation so it never dead-ends on an empty result.
class TripFinderScreen extends StatefulWidget {
  const TripFinderScreen({super.key});

  @override
  State<TripFinderScreen> createState() => _TripFinderScreenState();
}

class _TripFinderScreenState extends State<TripFinderScreen> {
  static const int _stepCount = 3;

  int _step = 0;
  bool _forward = true;
  bool _showResults = false;
  bool _loading = false;
  String _relaxedNote = '';
  List<dynamic> _results = const [];

  // answers
  String _type = '';
  String _typeLabel = '';
  String _difficulty = '';
  String _difficultyLabel = '';
  int? _minDays;
  int? _maxDays;
  String _daysLabel = '';

  static const List<Map<String, dynamic>> _difficultyOptions = [
    {'label': 'เริ่มต้น', 'desc': 'สบายๆ เหมาะกับมือใหม่', 'icon': Icons.sentiment_satisfied_rounded, 'value': 'easy'},
    {'label': 'ปานกลาง', 'desc': 'ท้าทายพอประมาณ', 'icon': Icons.directions_walk_rounded, 'value': 'medium'},
    {'label': 'ขาโหด', 'desc': 'สายลุยตัวจริง', 'icon': Icons.local_fire_department_rounded, 'value': 'hard'},
    {'label': 'ระดับไหนก็ได้', 'desc': 'ขอแค่ได้ออกไปเที่ยว', 'icon': Icons.all_inclusive_rounded, 'value': ''},
  ];

  static const List<Map<String, dynamic>> _dayOptions = [
    {'label': 'ไปเช้า-เย็นกลับ / 1 วัน', 'icon': Icons.wb_sunny_rounded, 'max': 1},
    {'label': '2–3 วัน', 'desc': 'เที่ยวสุดสัปดาห์', 'icon': Icons.weekend_rounded, 'min': 2, 'max': 3},
    {'label': '4 วันขึ้นไป', 'desc': 'ทริปยาวจัดเต็ม', 'icon': Icons.hiking_rounded, 'min': 4},
    {'label': 'กี่วันก็ได้', 'icon': Icons.all_inclusive_rounded},
  ];

  IconData _typeIcon(String slug, String name) {
    final s = '$slug $name'.toLowerCase();
    if (s.contains('trek') || s.contains('เดิน') || s.contains('ป่า')) return Icons.hiking_rounded;
    if (s.contains('div') || s.contains('snorkel') || s.contains('ดำน้ำ')) return Icons.scuba_diving_rounded;
    if (s.contains('climb') || s.contains('ปีน')) return Icons.terrain_rounded;
    if (s.contains('van') || s.contains('รถ')) return Icons.airport_shuttle_rounded;
    if (s.contains('camp') || s.contains('แคมป์')) return Icons.cabin_rounded;
    return Icons.landscape_rounded;
  }

  List<Map<String, dynamic>> _typeOptions(AppProvider app) {
    final cats = app.categories.map((c) {
      final m = asMap(c);
      final slug = textOf(m['slug']);
      final name = textOf(m['name'], slug);
      return {'label': name, 'value': slug, 'icon': _typeIcon(slug, name)};
    }).where((o) => (o['value'] as String).isNotEmpty).toList();
    return [
      {'label': 'ทั้งหมด', 'desc': 'ดูทุกประเภทกิจกรรม', 'value': '', 'icon': Icons.explore_rounded},
      ...cats,
    ];
  }

  String get _stepTitle => switch (_step) {
        0 => 'อยากไปแนวไหน?',
        1 => 'คุณเป็นสายไหน?',
        _ => 'มีเวลากี่วัน?',
      };

  String get _stepSubtitle => switch (_step) {
        0 => 'เลือกประเภทกิจกรรมที่สนใจ',
        1 => 'บอกระดับความท้าทายที่ชอบ',
        _ => 'เลือกความยาวของทริป',
      };

  String get _selectionSummary {
    final parts = <String>[];
    if (_typeLabel.isNotEmpty) parts.add(_typeLabel);
    if (_difficultyLabel.isNotEmpty) parts.add(_difficultyLabel);
    if (_daysLabel.isNotEmpty) parts.add(_daysLabel);
    return parts.isEmpty ? '' : 'ตามที่เลือก: ${parts.join(' · ')}';
  }

  void _selectType(Map<String, dynamic> opt) {
    _type = opt['value'] as String;
    _typeLabel = _type.isEmpty ? '' : textOf(opt['label']);
    _advance();
  }

  void _selectDifficulty(Map<String, dynamic> opt) {
    _difficulty = opt['value'] as String;
    _difficultyLabel = _difficulty.isEmpty ? '' : textOf(opt['label']);
    _advance();
  }

  void _selectDays(Map<String, dynamic> opt) {
    _minDays = opt['min'] as int?;
    _maxDays = opt['max'] as int?;
    _daysLabel = (_minDays == null && _maxDays == null) ? '' : textOf(opt['label']);
    _advance();
  }

  void _advance() {
    HapticFeedback.selectionClick();
    if (_step < _stepCount - 1) {
      setState(() {
        _forward = true;
        _step++;
      });
    } else {
      _compute();
    }
  }

  void _back() {
    if (_step == 0) return;
    setState(() {
      _forward = false;
      _step--;
    });
  }

  Future<List<dynamic>> _fetch(AppProvider app, Map<String, dynamic> query) async {
    try {
      final res = await app.api.get('trips', query: {...query, 'per_page': 12});
      return List<dynamic>.from(app.api.data(res) ?? const []);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _compute() async {
    final app = context.read<AppProvider>();
    setState(() {
      _showResults = true;
      _loading = true;
      _relaxedNote = '';
    });

    final base = <String, dynamic>{};
    if (_type.isNotEmpty) base['type'] = _type;
    if (_difficulty.isNotEmpty) base['difficulty'] = _difficulty;
    if (_minDays != null) base['min_days'] = _minDays;
    if (_maxDays != null) base['max_days'] = _maxDays;

    var list = await _fetch(app, base);

    // progressive relaxation so the quiz never ends on a dead end
    if (list.isEmpty && (_minDays != null || _maxDays != null)) {
      final q = <String, dynamic>{};
      if (_type.isNotEmpty) q['type'] = _type;
      if (_difficulty.isNotEmpty) q['difficulty'] = _difficulty;
      list = await _fetch(app, q);
      if (list.isNotEmpty) _relaxedNote = 'ยังไม่มีทริป "$_daysLabel" ตอนนี้ — นี่คือทริปใกล้เคียงที่น่าสนใจ';
    }
    if (list.isEmpty && _difficulty.isNotEmpty) {
      final q = <String, dynamic>{};
      if (_type.isNotEmpty) q['type'] = _type;
      list = await _fetch(app, q);
      if (list.isNotEmpty) _relaxedNote = 'ยังไม่มีทริประดับ "$_difficultyLabel" ตามที่เลือก — ลองดูตัวเลือกใกล้เคียงนี้';
    }

    if (!mounted) return;
    setState(() {
      _results = list;
      _loading = false;
    });
  }

  void _restart() {
    setState(() {
      _step = 0;
      _forward = false;
      _showResults = false;
      _results = const [];
      _relaxedNote = '';
      _type = '';
      _typeLabel = '';
      _difficulty = '';
      _difficultyLabel = '';
      _minDays = null;
      _maxDays = null;
      _daysLabel = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('ค้นหาทริปที่ใช่',
            style: appFont(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.onSurface(context))),
      ),
      body: SafeArea(
        child: _showResults ? _buildResults(context) : _buildQuiz(app),
      ),
    );
  }

  Widget _buildQuiz(AppProvider app) {
    final options = switch (_step) {
      0 => _typeOptions(app),
      1 => _difficultyOptions,
      _ => _dayOptions,
    };
    void Function(Map<String, dynamic>) onSelect = switch (_step) {
      0 => _selectType,
      1 => _selectDifficulty,
      _ => _selectDays,
    };

    return Column(
      children: [
        const SizedBox(height: 8),
        // progress dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_stepCount, (i) {
            final active = i == _step;
            final done = i < _step;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: active ? 28 : 8,
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.primaryColor
                    : done
                        ? AppTheme.primaryColor.withValues(alpha: 0.4)
                        : AppTheme.outlineColor,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 28),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) {
              final offset = Tween<Offset>(
                begin: Offset(_forward ? 0.12 : -0.12, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: SingleChildScrollView(
              key: ValueKey(_step),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_stepTitle,
                      style: appFont(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.onSurface(context))),
                  const SizedBox(height: 6),
                  Text(_stepSubtitle,
                      style: appFont(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
                  const SizedBox(height: 20),
                  ...options.map((opt) => _OptionCard(
                        label: textOf(opt['label']),
                        desc: opt['desc'] == null ? null : textOf(opt['desc']),
                        icon: opt['icon'] as IconData,
                        onTap: () => onSelect(opt),
                      )),
                ],
              ),
            ),
          ),
        ),
        // bottom nav
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _step > 0
                  ? TextButton.icon(
                      onPressed: _back,
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      label: Text('ย้อนกลับ', style: appFont(fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                    )
                  : const SizedBox.shrink(),
              TextButton(
                onPressed: () {
                  // skip = clear this step's answer, then advance
                  switch (_step) {
                    case 0:
                      _type = '';
                      _typeLabel = '';
                    case 1:
                      _difficulty = '';
                      _difficultyLabel = '';
                    default:
                      _minDays = null;
                      _maxDays = null;
                      _daysLabel = '';
                  }
                  _advance();
                },
                style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                child: Text('ข้ามขั้นนี้', style: appFont(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(_results.isEmpty ? 'ยังไม่เจอทริปที่ตรงเป๊ะ' : 'ทริปที่ใช่สำหรับคุณ',
            style: appFont(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.onSurface(context))),
        if (_selectionSummary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(_selectionSummary,
              style: appFont(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
        ],
        const SizedBox(height: 16),
        if (_relaxedNote.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates_rounded, color: AppTheme.accentColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_relaxedNote,
                      style: appFont(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.onSurface(context))),
                ),
              ],
            ),
          ),
        if (_results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                const Icon(Icons.travel_explore_rounded, size: 56, color: AppTheme.outlineColor),
                const SizedBox(height: 12),
                Text('ลองเริ่มใหม่แล้วปรับเงื่อนไขให้กว้างขึ้นนะครับ',
                    textAlign: TextAlign.center,
                    style: appFont(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
              ],
            ),
          )
        else
          ..._results.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TripCard(trip: asMap(t)),
              )),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AllTripsScreen()),
            ),
            icon: const Icon(Icons.grid_view_rounded),
            label: Text('ดูทริปทั้งหมด', style: appFont(fontWeight: FontWeight.w800, color: Colors.white)),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text('เริ่มใหม่', style: appFont(fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppTheme.outlineColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Prominent entry point shown on the Explore tab that opens the Trip Finder.
class TripFinderEntryCard extends StatelessWidget {
  const TripFinderEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TripFinderScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primaryColor, AppTheme.accentColor],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('ค้นหาทริปที่ใช่',
                        style: appFont(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('ตอบ 3 ข้อ เจอทริปที่ชอบใน 1 นาที',
                        style: appFont(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final String? desc;
  final IconData icon;
  final VoidCallback onTap;

  const _OptionCard({required this.label, this.desc, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: AppTheme.outlineColor.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(icon, color: AppTheme.accentColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          style: appFont(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.onSurface(context))),
                      if (desc != null) ...[
                        const SizedBox(height: 2),
                        Text(desc!,
                            style: appFont(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.outlineColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
