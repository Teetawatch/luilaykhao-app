part of 'trip_detail_screen.dart';

/// "ทริปนี้ไหวไหม" — เทียบความหนักของทริปกับประวัติการเดินของผู้ใช้
///
/// โหลดข้อมูลเอง และซ่อนตัวเองเมื่อทริปยังไม่ได้ระบุระยะทาง/ความสูง เพราะ
/// เทียบอะไรไม่ได้เลย ส่วนกรณีที่ผู้ใช้ยังไม่มีประวัติจะแสดงฟอร์มให้กรอกแทน
class TripReadinessSection extends StatefulWidget {
  final String slug;

  const TripReadinessSection({super.key, required this.slug});

  @override
  State<TripReadinessSection> createState() => _TripReadinessSectionState();
}

class _TripReadinessSectionState extends State<TripReadinessSection> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _saving = false;

  final _distanceCtrl = TextEditingController();
  final _elevationCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _distanceCtrl.dispose();
    _elevationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AppProvider>().tripReadiness(widget.slug);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _saveBaseline() async {
    final distance = double.tryParse(_distanceCtrl.text.trim());
    final elevation = int.tryParse(_elevationCtrl.text.trim());

    if (distance == null && elevation == null) {
      _toast('กรอกอย่างน้อยหนึ่งช่องนะครับ');
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<AppProvider>().saveHikingBaseline(
            maxDistanceKm: distance,
            maxElevationGainM: elevation,
          );
      HapticFeedback.lightImpact();
      await _load();
    } catch (_) {
      _toast('บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    final data = _data;
    if (data == null) return const SizedBox.shrink();

    final available = data['available'] == true;
    final reason = textOf(data['reason']);

    // ทริปไม่มีตัวเลขให้เทียบ = ไม่ต้องแสดงอะไรเลย ไม่ใช่ปัญหาของผู้ใช้
    if (!available && reason == 'trip_data_missing') {
      return const SizedBox.shrink();
    }

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.monitor_heart_rounded,
            title: 'ทริปนี้ไหวไหม',
            subtitle: 'เทียบกับที่คุณเคยเดินมา',
          ),
          const SizedBox(height: 18),
          if (available)
            ..._buildComparison(context, data)
          else if (reason == 'no_baseline')
            ..._buildBaselineForm(context, data)
          else
            _MessageRow(message: textOf(data['message'])),
        ],
      ),
    );
  }

  // ── ผลการเทียบ ────────────────────────────────────────────────────────────

  List<Widget> _buildComparison(BuildContext context, Map<String, dynamic> d) {
    final verdict = textOf(d['verdict']);
    final trip = asMap(d['trip']);
    final you = asMap(d['you']);
    final comparison = asMap(d['comparison']);
    final alternatives = asList(d['alternatives']);
    final style = _VerdictStyle.of(verdict);

    final tripDistance = _num(trip['distance_km']);
    final tripElevation = _num(trip['elevation_gain_m']);
    final yourDistance = _num(you['max_distance_km']);
    final yourElevation = _num(you['max_elevation_gain_m']);

    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: style.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(style.icon, size: 22, color: style.color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.label,
                    style: appFont(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: style.color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    textOf(d['message']),
                    style: appFont(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText(context),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      if (tripDistance != null && tripDistance > 0)
        _CompareBar(
          label: 'ระยะทาง',
          tripValue: tripDistance,
          yourValue: yourDistance ?? 0,
          unit: 'กม.',
          ratio: _num(comparison['distance_ratio']),
          color: style.color,
        ),
      if (tripElevation != null && tripElevation > 0) ...[
        const SizedBox(height: 14),
        _CompareBar(
          label: 'ความสูงสะสม',
          tripValue: tripElevation,
          yourValue: yourElevation ?? 0,
          unit: 'ม.',
          ratio: _num(comparison['elevation_ratio']),
          color: style.color,
        ),
      ],
      const SizedBox(height: 14),
      Text(
        textOf(d['source']) == 'history'
            ? 'เทียบจากทริปที่คุณเดินจบมาแล้ว ${_num(you['trips_count'])?.toInt() ?? 0} ทริป'
            : 'เทียบจากข้อมูลที่คุณกรอกไว้เอง',
        style: appFont(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppTheme.mutedText(context).withValues(alpha: 0.75),
        ),
      ),
      if (alternatives.isNotEmpty) ...[
        const SizedBox(height: 18),
        const Divider(height: 1),
        const SizedBox(height: 16),
        Text(
          'ลองทริปที่เบากว่านี้ก่อนไหม',
          style: appFont(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.onSurface(context),
          ),
        ),
        const SizedBox(height: 10),
        ...alternatives.map((a) => _AlternativeRow(trip: asMap(a))),
      ],
    ];
  }

  // ── ฟอร์มกรอกค่าอ้างอิง (คนที่ยังไม่มีประวัติ) ─────────────────────────────

  List<Widget> _buildBaselineForm(BuildContext context, Map<String, dynamic> d) {
    return [
      _MessageRow(message: textOf(d['message'])),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _BaselineField(
              controller: _distanceCtrl,
              label: 'เคยเดินไกลสุด',
              suffix: 'กม.',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _BaselineField(
              controller: _elevationCtrl,
              label: 'เคยไต่สูงสุด',
              suffix: 'ม.',
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _saving ? null : _saveBaseline,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('ดูว่าทริปนี้ไหวไหม'),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'ไม่แน่ใจก็กรอกคร่าว ๆ ได้ ใช้แค่เทียบให้ดูเท่านั้น',
        style: appFont(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppTheme.mutedText(context).withValues(alpha: 0.75),
        ),
      ),
    ];
  }

  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

/// สี/ไอคอน/คำตัดสิน ของแต่ละระดับความพร้อม
class _VerdictStyle {
  final String label;
  final Color color;
  final IconData icon;

  const _VerdictStyle(this.label, this.color, this.icon);

  static _VerdictStyle of(String verdict) => switch (verdict) {
        'comfortable' => const _VerdictStyle(
            'น่าจะไปได้สบาย',
            AppTheme.primaryColor,
            Icons.check_circle_rounded,
          ),
        'stretch' => const _VerdictStyle(
            'ท้าทายอยู่บ้าง',
            AppTheme.warningColor,
            Icons.trending_up_rounded,
          ),
        'beyond' => const _VerdictStyle(
            'หนักกว่าที่เคยเดินมาพอสมควร',
            AppTheme.errorColor,
            Icons.warning_amber_rounded,
          ),
        _ => const _VerdictStyle(
            'ยังเทียบให้ไม่ได้',
            AppTheme.textSecondary,
            Icons.help_outline_rounded,
          ),
      };
}

/// แถบเทียบค่าทริปกับสถิติของผู้ใช้ — ให้เห็นภาพว่าห่างกันแค่ไหน
class _CompareBar extends StatelessWidget {
  final String label;
  final double tripValue;
  final double yourValue;
  final String unit;
  final double? ratio;
  final Color color;

  const _CompareBar({
    required this.label,
    required this.tripValue,
    required this.yourValue,
    required this.unit,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // สเกลจากค่าที่มากที่สุด เพื่อให้สองแถบเทียบกันได้ตรง ๆ
    final maxValue = [tripValue, yourValue].reduce((a, b) => a > b ? a : b);
    final tripFraction = maxValue > 0 ? tripValue / maxValue : 0.0;
    final yourFraction = maxValue > 0 ? yourValue / maxValue : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: appFont(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface(context),
              ),
            ),
            const Spacer(),
            if (ratio != null)
              Text(
                '${_formatNumber(ratio!)} เท่า',
                style: appFont(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _Bar(
          caption: 'ทริปนี้',
          value: '${_formatNumber(tripValue)} $unit',
          fraction: tripFraction,
          color: color,
        ),
        const SizedBox(height: 6),
        _Bar(
          caption: 'คุณเคยทำได้',
          value: yourValue > 0 ? '${_formatNumber(yourValue)} $unit' : 'ยังไม่มีข้อมูล',
          fraction: yourFraction,
          color: AppTheme.mutedText(context).withValues(alpha: 0.35),
        ),
      ],
    );
  }

  static String _formatNumber(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

class _Bar extends StatelessWidget {
  final String caption;
  final String value;
  final double fraction;
  final Color color;

  const _Bar({
    required this.caption,
    required this.value,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(
            caption,
            style: appFont(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.mutedText(context),
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor:
                  AppTheme.mutedText(context).withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 78,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: appFont(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlternativeRow extends StatelessWidget {
  final Map<String, dynamic> trip;

  const _AlternativeRow({required this.trip});

  @override
  Widget build(BuildContext context) {
    final distance = trip['distance_km'];
    final elevation = trip['elevation_gain_m'];
    final parts = <String>[
      if (distance != null) '${distance is num ? _fmt(distance) : distance} กม.',
      if (elevation != null) '$elevation ม.',
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TripDetailScreen(slug: textOf(trip['slug'])),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    textOf(trip['title']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                  if (parts.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      parts.join(' · '),
                      style: appFont(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedText(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppTheme.mutedText(context),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class _MessageRow extends StatelessWidget {
  final String message;

  const _MessageRow({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    return Text(
      message,
      style: appFont(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.mutedText(context),
        height: 1.5,
      ),
    );
  }
}

class _BaselineField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;

  const _BaselineField({
    required this.controller,
    required this.label,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: appFont(fontSize: 14, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        isDense: true,
      ),
    );
  }
}
