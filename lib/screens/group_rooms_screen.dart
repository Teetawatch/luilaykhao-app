import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/group_plan.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';
import '../widgets/travel_widgets.dart';
import 'customer_app_screen.dart' show AllTripsScreen;
import 'group_room_screen.dart';

/// Lists the group rooms the current user hosts or has joined, so a room is no
/// longer lost once the host navigates away. Tapping a room re-opens it live.
class GroupRoomsScreen extends StatefulWidget {
  const GroupRoomsScreen({super.key});

  @override
  State<GroupRoomsScreen> createState() => _GroupRoomsScreenState();
}

class _GroupRoomsScreenState extends State<GroupRoomsScreen> {
  bool _loading = true;
  String? _error;
  List<GroupPlan> _plans = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await context.read<AppProvider>().myGroupPlans();
      final plans = raw
          .whereType<Map>()
          .map((e) => GroupPlan.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'โหลดกลุ่มของฉันไม่สำเร็จ';
      });
    }
  }

  Future<void> _open(GroupPlan plan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupRoomScreen(initialPlan: plan)),
    );
    if (mounted) _load();
  }

  // A group is created from a specific trip + departure, so creating one starts
  // by picking a trip; the trip detail screen then offers "ชวนเพื่อนมาเป็นกลุ่ม".
  Future<void> _createGroup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AllTripsScreen(introBanner: GroupCreateTripHint()),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        title: Text(
          'กลุ่มของฉัน',
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton.icon(
            onPressed: _createGroup,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(
              'สร้างกลุ่ม',
              style: appFont(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'เกิดข้อผิดพลาด',
            body: _error!,
          ),
        ],
      );
    }
    if (_plans.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          const EmptyState(
            icon: Icons.groups_2_rounded,
            title: 'ยังไม่มีกลุ่ม',
            body: 'สร้างกลุ่มเพื่อชวนเพื่อนไปทริปเดียวกัน จองพร้อมกันได้ในที่เดียว',
          ),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              onPressed: _createGroup,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                'สร้างกลุ่มใหม่',
                style: appFont(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _plans.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _GroupRoomCard(plan: _plans[index], onTap: () => _open(_plans[index])),
    );
  }
}

class _GroupRoomCard extends StatelessWidget {
  final GroupPlan plan;
  final VoidCallback onTap;

  const _GroupRoomCard({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final trip = plan.trip;
    final schedule = plan.schedule;
    final image = trip?.image ?? '';
    final dateLabel = schedule?.departureDate != null
        ? thaiDateShort(DateTime.parse(schedule!.departureDate!))
        : '';
    final claimed = plan.claimedSeatIds.length;

    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border(context)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              if (image.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: image,
                  width: 92,
                  height: 100,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    width: 92,
                    height: 100,
                    color: AppTheme.subtleSurface(context),
                    child: const Icon(Icons.landscape_rounded),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.name?.isNotEmpty == true
                                  ? plan.name!
                                  : (trip?.title ?? 'ทริปแบบกลุ่ม'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appFont(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusChip(plan: plan),
                        ],
                      ),
                      if (plan.name?.isNotEmpty == true &&
                          trip?.title.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          trip!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appFont(
                            fontSize: 12.5,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.event_rounded,
                              size: 14, color: AppTheme.mutedText(context)),
                          const SizedBox(width: 4),
                          Text(
                            dateLabel.isEmpty ? '-' : dateLabel,
                            style: appFont(
                              fontSize: 12.5,
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.event_seat_rounded,
                              size: 14, color: AppTheme.mutedText(context)),
                          const SizedBox(width: 4),
                          Text(
                            'เลือกแล้ว $claimed / ${plan.seatCount}',
                            style: appFont(
                              fontSize: 12.5,
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (plan.isHost)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                'คุณเป็นหัวหน้ากลุ่ม',
                                style: appFont(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            'รหัส ${plan.inviteCode}',
                            style: appFont(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final GroupPlan plan;

  const _StatusChip({required this.plan});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (plan.status) {
      'booked' => ('จองแล้ว', AppTheme.primaryColor),
      'open' => ('กำลังรวมกลุ่ม', AppTheme.accentColor),
      'cancelled' => ('ยกเลิกแล้ว', AppTheme.errorColor),
      'expired' => ('หมดเวลา', AppTheme.mutedText(context)),
      _ => (plan.status, AppTheme.mutedText(context)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: appFont(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
