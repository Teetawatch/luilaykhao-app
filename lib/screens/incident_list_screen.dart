import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Read-only history of incidents logged for a schedule. Closing a case is done
/// from the admin web, not here.
class IncidentListScreen extends StatefulWidget {
  final int scheduleId;
  final String title;

  const IncidentListScreen({
    super.key,
    required this.scheduleId,
    this.title = '',
  });

  @override
  State<IncidentListScreen> createState() => _IncidentListScreenState();
}

class _IncidentListScreenState extends State<IncidentListScreen> {
  List<Map<String, dynamic>> _incidents = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<AppProvider>().loadIncidents(
        widget.scheduleId,
      );
      if (!mounted) return;
      setState(() => _incidents = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'โหลดรายการแจ้งเหตุไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(widget.title.isEmpty ? 'รายการแจ้งเหตุ' : widget.title),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryColor,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _incidents.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _incidents.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Center(
            child: Text(
              _error!,
              style: appFont(
                fontWeight: FontWeight.w700,
                color: AppTheme.mutedText(context),
              ),
            ),
          ),
        ],
      );
    }
    if (_incidents.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 96),
          Icon(
            Icons.verified_outlined,
            size: 48,
            color: AppTheme.mutedText(context),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'ยังไม่มีการแจ้งเหตุในรอบนี้',
              style: appFont(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.mutedText(context),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: _incidents.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _IncidentCard(incident: _incidents[i]),
    );
  }
}

({String label, Color color}) _severityMeta(String value) {
  return switch (value) {
    'minor' => (label: 'เล็กน้อย', color: const Color(0xFF059669)),
    'severe' => (label: 'รุนแรง', color: const Color(0xFFEA580C)),
    'critical' => (label: 'วิกฤต', color: AppTheme.errorColor),
    _ => (label: 'ปานกลาง', color: AppTheme.warningColor),
  };
}

String _formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
}

class _IncidentCard extends StatelessWidget {
  final Map<String, dynamic> incident;

  const _IncidentCard({required this.incident});

  String _text(dynamic v) => v?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final severity = _text(incident['severity']);
    final meta = _severityMeta(severity);
    final severityLabel = _text(incident['severity_label']).isNotEmpty
        ? _text(incident['severity_label'])
        : meta.label;
    final resolved = _text(incident['status']) == 'resolved';
    final passenger = _text(incident['passenger_name']);
    final description = _text(incident['description']);
    final reporter = _text(incident['reported_by_name']);
    final photoUrl = _text(incident['photo_url']);
    final lat = incident['latitude'];
    final lng = incident['longitude'];
    final hasLocation = lat != null && lng != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(
        context,
        borderColor: resolved ? null : meta.color.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  severityLabel,
                  style: appFont(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: meta.color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(resolved: resolved),
              const Spacer(),
              Text(
                _formatDateTime(_text(incident['created_at'])),
                style: appFont(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ],
          ),
          if (passenger.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: AppTheme.mutedText(context),
                ),
                const SizedBox(width: 6),
                Text(
                  passenger,
                  style: appFont(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            description,
            style: appFont(
              fontSize: 13.5,
              height: 1.5,
              color: AppTheme.onSurface(context),
            ),
          ),
          if (photoUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: photoUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  reporter.isEmpty ? 'ไม่ระบุผู้แจ้ง' : 'แจ้งโดย $reporter',
                  style: appFont(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ),
              if (hasLocation)
                TextButton.icon(
                  onPressed: () => _openMap(lat, lng),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: Text(
                    'ดูตำแหน่ง',
                    style: appFont(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          if (resolved && _text(incident['resolved_by_name']).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'ปิดเคสโดย ${_text(incident['resolved_by_name'])}',
              style: appFont(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openMap(dynamic lat, dynamic lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _StatusPill extends StatelessWidget {
  final bool resolved;

  const _StatusPill({required this.resolved});

  @override
  Widget build(BuildContext context) {
    final color = resolved ? const Color(0xFF059669) : AppTheme.warningColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        resolved ? 'ปิดเคสแล้ว' : 'รอดำเนินการ',
        style: appFont(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
