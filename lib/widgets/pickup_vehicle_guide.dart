import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/pickup_vehicle_class.dart';
import '../theme/app_theme.dart';

/// ไกด์ประเภทรถรับ-ส่งที่วิ่งจากจุดรับต่างภูมิภาคมายังจุดขึ้นรถจุดแรก
///
/// จงใจแสดง "ทั้งชุด" แล้วไฮไลต์ใบที่ตรงกับจำนวนผู้โดยสารของลูกค้า ไม่ใช่โชว์
/// รถคันเดียวแบบชี้ขาด — ตอนเลือกจุดรับเรายังไม่รู้ว่าจุดนั้นจะมีคนรวมกี่คน
/// (ขึ้นกับ booking อื่นที่เลือกจุดเดียวกัน) การโชว์ใบเดียวจึงกลายเป็นคำสัญญา
/// ที่ผิดได้ง่ายเมื่อวันจริงถูกรวมกลุ่ม
class PickupVehicleGuide extends StatefulWidget {
  final List<PickupVehicleClass> classes;

  /// จำนวนผู้โดยสารของลูกค้ารายนี้ — ใช้ไฮไลต์ใบที่น่าจะตรง (null = ไม่ไฮไลต์)
  final int? paxCount;

  /// จุดรับที่เลือกแพงกว่าราคารอบไหม — ถ้าใช่ จะขึ้นบรรทัดโยงว่าเงินที่จ่ายเพิ่ม
  /// คือค่ารถคันนี้ ไม่ใช่ค่าธรรมเนียมลอย ๆ
  final bool hasSurcharge;

  const PickupVehicleGuide({
    super.key,
    required this.classes,
    this.paxCount,
    this.hasSurcharge = false,
  });

  @override
  State<PickupVehicleGuide> createState() => _PickupVehicleGuideState();
}

class _PickupVehicleGuideState extends State<PickupVehicleGuide> {
  final ScrollController _controller = ScrollController();

  static const double _cardWidth = 156;
  static const double _cardGap = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMatch());
  }

  @override
  void didUpdateWidget(covariant PickupVehicleGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paxCount != widget.paxCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMatch());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _matchIndex {
    final pax = widget.paxCount;
    if (pax == null) return -1;
    return widget.classes.indexWhere((c) => c.covers(pax));
  }

  /// เลื่อนใบที่ตรงเข้ามาในจอเอง — ถ้าไม่เลื่อน คนกลุ่มใหญ่ (รถตู้ ซึ่งอยู่ท้ายสุด)
  /// จะเห็นแต่รถเก๋งและนึกว่าเราส่งรถเล็กมารับ
  void _scrollToMatch() {
    final index = _matchIndex;
    if (index <= 0 || !_controller.hasClients) return;

    final target = (index * (_cardWidth + _cardGap)).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.classes.isEmpty) return const SizedBox.shrink();

    final matchIndex = _matchIndex;
    final match = matchIndex >= 0 ? widget.classes[matchIndex] : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.airport_shuttle_rounded,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'รถรับ-ส่งมาที่จุดขึ้นรถ',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (match != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'เดินทาง ${widget.paxCount} ท่าน โดยประมาณจะใช้${match.label}',
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            height: 168,
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.classes.length,
              separatorBuilder: (_, _) => const SizedBox(width: _cardGap),
              itemBuilder: (context, index) => _VehicleCard(
                item: widget.classes[index],
                highlighted: index == matchIndex,
                width: _cardWidth,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              widget.hasSurcharge
                  ? 'ค่าจุดรับที่จ่ายเพิ่มคือค่ารถรับ-ส่งมาที่จุดขึ้นรถจุดแรก '
                      'ประเภทรถขึ้นกับจำนวนผู้โดยสารรวมที่จุดนั้นในวันเดินทาง'
                  : 'ประเภทรถขึ้นกับจำนวนผู้โดยสารรวมที่จุดนั้นในวันเดินทาง '
                      'ทีมงานจะแจ้งรถคันจริงก่อนออกเดินทาง',
              style: appFont(
                fontSize: AppText.sizeCaption,
                color: AppTheme.mutedText(context),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final PickupVehicleClass item;
  final bool highlighted;
  final double width;

  const _VehicleCard({
    required this.item,
    required this.highlighted,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    final cacheWidth = (width * dpr).round();

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: highlighted
            ? AppTheme.selectedTint(context)
            : AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: highlighted
              ? AppTheme.primaryColor
              : AppTheme.border(context).withValues(alpha: 0.55),
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusSm - 2),
            ),
            child: SizedBox(
              height: 92,
              width: double.infinity,
              child: imageUrl == null
                  ? _placeholder(context)
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: cacheWidth,
                      maxWidthDiskCache: cacheWidth,
                      placeholder: (_, _) => _placeholder(context),
                      errorWidget: (_, _, _) => _placeholder(context),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w800,
                    color: highlighted
                        ? AppTheme.primaryColor
                        : AppTheme.onSurface(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.paxLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.mutedText(context),
                  ),
                ),
                if (item.note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      color: AppTheme.mutedText(context),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: AppTheme.fieldSurface(context),
      child: Center(
        child: Icon(
          Icons.directions_car_rounded,
          size: 28,
          color: AppTheme.mutedText(context).withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
