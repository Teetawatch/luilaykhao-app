import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/trip_live_location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack.dart';

/// "เพื่อนร่วมทริปอยู่ตรงไหน"
///
/// พอขึ้นดอยจริงคนกระจายกันเป็นกิโล แล้วคำถามสองข้อดังขึ้นพร้อมกันทั้งกลุ่ม:
/// หัวแถวถึงยัง และน้องคนนั้นหายไปไหน ก่อนหน้านี้แอปตอบไม่ได้เลยเพราะเห็นแค่รถ
///
/// หน้าจอนี้ตั้งใจให้ "ดูอย่างเดียวก็มีประโยชน์" — ไม่ต้องเปิดแชร์ก็เห็นเพื่อนที่
/// เปิดไว้ได้ การเปิดแชร์เป็นการตัดสินใจแยกต่างหากที่กดเองทุกครั้ง
class TripMembersMapScreen extends StatefulWidget {
  final int scheduleId;
  final String tripTitle;

  const TripMembersMapScreen({
    super.key,
    required this.scheduleId,
    this.tripTitle = '',
  });

  @override
  State<TripMembersMapScreen> createState() => _TripMembersMapScreenState();
}

class _TripMembersMapScreenState extends State<TripMembersMapScreen> {
  static const LatLng _fallbackCenter = LatLng(18.79, 98.98);

  final MapController _map = MapController();
  late final TripLiveLocationController _controller;

  /// รีเฟรชเป็นระยะเผื่อ socket หลุด — บนดอยมันหลุดบ่อยกว่าที่คิด และหน้าจอที่
  /// ค้างหมุดเก่าไว้เงียบ ๆ อันตรายกว่าหน้าจอที่บอกว่าไม่รู้
  Timer? _poll;

  bool _fitted = false;

  @override
  void initState() {
    super.initState();
    _controller = TripLiveLocationController(
      api: context.read<AppProvider>().api,
      scheduleId: widget.scheduleId,
    )..addListener(_onChange);

    _controller.start();
    _poll = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _controller.refreshMembers(),
    );
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    _fitOnce();
  }

  /// จัดกล้องให้เห็นทุกคนครั้งเดียวตอนข้อมูลชุดแรกมาถึง — หลังจากนั้นปล่อยให้
  /// ผู้ใช้เลื่อนเอง ไม่มีอะไรน่ารำคาญกว่าแผนที่ที่ดีดกลับทุก 20 วินาที
  void _fitOnce() {
    if (_fitted) return;
    final points = [
      for (final member in _controller.members) member.position,
      if (_controller.myPosition != null) _controller.myPosition!,
    ];
    if (points.isEmpty) return;

    _fitted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (points.length == 1) {
        _map.move(points.first, 14);
        return;
      }
      _map.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(60),
          maxZoom: 15,
        ),
      );
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleSharing() async {
    HapticFeedback.selectionClick();

    if (_controller.sharing) {
      await _controller.stopSharing();
      if (!mounted) return;
      AppSnack.show(context, 'หยุดแชร์ตำแหน่งแล้ว');
      return;
    }

    final ok = await _controller.startSharing();
    if (!mounted) return;
    if (ok) {
      AppSnack.show(context, 'เพื่อนร่วมทริปเห็นตำแหน่งของคุณแล้ว');
    } else if (_controller.error != null) {
      AppSnack.error(context, _controller.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _controller.members;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        title: Text(
          'เพื่อนร่วมทริป',
          style: appFont(
            fontSize: AppText.sizeTitle,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _controller.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _map,
                        options: MapOptions(
                          initialCenter:
                              _controller.myPosition ??
                              (members.isNotEmpty
                                  ? members.first.position
                                  : _fallbackCenter),
                          initialZoom: 13,
                          minZoom: 5,
                          maxZoom: 17,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName: 'com.luilaykhao.app',
                          ),
                          MarkerLayer(
                            markers: [
                              for (final member in members)
                                Marker(
                                  point: member.position,
                                  width: 52,
                                  height: 60,
                                  child: _MemberPin(member: member),
                                ),
                              if (_controller.myPosition != null)
                                Marker(
                                  point: _controller.myPosition!,
                                  width: 26,
                                  height: 26,
                                  child: const _MePin(),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (members.isEmpty)
                        const Positioned(
                          left: 16,
                          right: 16,
                          top: 16,
                          child: _FloatingNote(
                            text:
                                'ยังไม่มีเพื่อนร่วมทริปคนไหนเปิดแชร์ตำแหน่ง — เปิดของคุณก่อนได้เลย',
                          ),
                        ),
                    ],
                  ),
                ),
                _SharePanel(
                  sharing: _controller.sharing,
                  busy: _controller.busy,
                  onToggle: _toggleSharing,
                ),
                if (members.isNotEmpty)
                  SizedBox(
                    height: 138,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: members.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, index) {
                        final member = members[index];
                        return _MemberCard(
                          member: member,
                          myPosition: _controller.myPosition,
                          onTap: () => _map.move(member.position, 15),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SharePanel extends StatelessWidget {
  final bool sharing;
  final bool busy;
  final VoidCallback onToggle;

  const _SharePanel({
    required this.sharing,
    required this.busy,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(top: BorderSide(color: AppTheme.border(context))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (sharing ? AppTheme.accentColor : AppTheme.mutedText(context))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              sharing ? Icons.share_location_rounded : Icons.location_off_rounded,
              size: 20,
              color: sharing
                  ? AppTheme.accentColor
                  : AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sharing ? 'กำลังแชร์ตำแหน่งของคุณ' : 'ยังไม่ได้แชร์ตำแหน่ง',
                  style: appFont(
                    fontSize: AppText.sizeSubtitle,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sharing
                      ? 'เห็นเฉพาะคนในรอบนี้ และหยุดเองเมื่อทริปจบ'
                      : 'เปิดเพื่อให้เพื่อนในรอบนี้เห็นว่าคุณอยู่ตรงไหน',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    color: AppTheme.mutedText(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch(value: sharing, onChanged: (_) => onToggle()),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final TripMemberPin member;
  final LatLng? myPosition;
  final VoidCallback onTap;

  const _MemberCard({
    required this.member,
    required this.myPosition,
    required this.onTap,
  });

  String? get _distanceLabel {
    final me = myPosition;
    if (me == null) return null;
    final metres = const Distance().as(LengthUnit.Meter, me, member.position);
    if (metres < 950) return 'ห่าง ${metres.round()} ม.';
    return 'ห่าง ${(metres / 1000).toStringAsFixed(1)} กม.';
  }

  @override
  Widget build(BuildContext context) {
    final avatar = member.avatarUrl ?? '';
    final distance = _distanceLabel;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  backgroundImage: avatar.isNotEmpty
                      ? CachedNetworkImageProvider(avatar)
                      : null,
                  child: avatar.isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          size: 16,
                          color: AppTheme.primaryColor,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (distance != null)
              Text(
                distance,
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accentColor,
                ),
              ),
            const Spacer(),
            Text(
              member.lastSeenLabel,
              style: appFont(
                fontSize: AppText.sizeCaption,
                color: AppTheme.mutedText(context),
              ),
            ),
            if (member.batteryLevel != null) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(
                    member.batteryLevel! <= 20
                        ? Icons.battery_alert_rounded
                        : Icons.battery_full_rounded,
                    size: 13,
                    color: member.batteryLevel! <= 20
                        ? AppTheme.errorColor
                        : AppTheme.mutedText(context),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'แบต ${member.batteryLevel}%',
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: member.batteryLevel! <= 20
                          ? AppTheme.errorColor
                          : AppTheme.mutedText(context),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemberPin extends StatelessWidget {
  final TripMemberPin member;

  const _MemberPin({required this.member});

  @override
  Widget build(BuildContext context) {
    final avatar = member.avatarUrl ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            radius: 15,
            backgroundColor: Colors.white,
            backgroundImage: avatar.isNotEmpty
                ? CachedNetworkImageProvider(avatar)
                : null,
            child: avatar.isEmpty
                ? const Icon(
                    Icons.person_rounded,
                    size: 16,
                    color: AppTheme.primaryColor,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appFont(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _MePin extends StatelessWidget {
  const _MePin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.accentColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
    );
  }
}

class _FloatingNote extends StatelessWidget {
  final String text;

  const _FloatingNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Text(
        text,
        style: appFont(
          fontSize: AppText.sizeLabel,
          fontWeight: FontWeight.w600,
          color: AppTheme.onSurface(context),
        ),
      ),
    );
  }
}
