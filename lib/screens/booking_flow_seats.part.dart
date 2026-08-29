part of 'booking_flow_screen.dart';


class _VehiclePhotoPreview extends StatefulWidget {
  final Map<String, dynamic> vehicle;

  const _VehiclePhotoPreview({required this.vehicle});

  @override
  State<_VehiclePhotoPreview> createState() => _VehiclePhotoPreviewState();
}

class _VehiclePhotoPreviewState extends State<_VehiclePhotoPreview> {
  final PageController _photoController = PageController();
  int _photoIndex = 0;

  @override
  void didUpdateWidget(covariant _VehiclePhotoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameStringList(
      _vehicleImageUrls(oldWidget.vehicle),
      _vehicleImageUrls(widget.vehicle),
    )) {
      _photoIndex = 0;
      if (_photoController.hasClients) {
        _photoController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  void _showPhoto(int index) {
    _photoController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _showPreviousPhoto(int total) {
    if (total <= 1) return;
    _showPhoto((_photoIndex - 1 + total) % total);
  }

  void _showNextPhoto(int total) {
    if (total <= 1) return;
    _showPhoto((_photoIndex + 1) % total);
  }

  @override
  Widget build(BuildContext context) {
    final images = _vehicleImageUrls(widget.vehicle);
    final name = textOf(widget.vehicle['name'], 'รถประจำรอบนี้');
    final plate = textOf(widget.vehicle['license_plate']);
    final capacity = textOf(widget.vehicle['capacity']);
    final color = textOf(widget.vehicle['color']);
    final canSlide = images.length > 1;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _fieldBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: _cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RepaintBoundary(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: images.isEmpty
                  ? const _VehiclePhotoFallback()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final imageCacheSize = _cacheSizeFor(
                          context,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                        );

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            PageView.builder(
                              controller: _photoController,
                              itemCount: images.length,
                              onPageChanged: (index) =>
                                  setState(() => _photoIndex = index),
                              itemBuilder: (context, index) {
                                return CachedNetworkImage(
                                  imageUrl: images[index],
                                  fit: BoxFit.cover,
                                  memCacheWidth: imageCacheSize.width,
                                  memCacheHeight: imageCacheSize.height,
                                  maxWidthDiskCache: imageCacheSize.width,
                                  maxHeightDiskCache: imageCacheSize.height,
                                  fadeInDuration: const Duration(
                                    milliseconds: 120,
                                  ),
                                  fadeOutDuration: Duration.zero,
                                  useOldImageOnUrlChange: true,
                                  filterQuality: FilterQuality.low,
                                  placeholder: (_, _) =>
                                      const _VehiclePhotoFallback(),
                                  errorWidget: (_, _, _) =>
                                      const _VehiclePhotoFallback(),
                                );
                              },
                            ),
                            if (canSlide) ...[
                              Positioned(
                                left: 10,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: _VehiclePhotoNavButton(
                                    icon: Icons.chevron_left_rounded,
                                    onPressed: () =>
                                        _showPreviousPhoto(images.length),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 10,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: _VehiclePhotoNavButton(
                                    icon: Icons.chevron_right_rounded,
                                    onPressed: () =>
                                        _showNextPhoto(images.length),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 10,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(images.length, (
                                    index,
                                  ) {
                                    final selected = index == _photoIndex;
                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      width: selected ? 18 : 7,
                                      height: 7,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surface(context).withValues(
                                          alpha: selected ? 0.95 : 0.55,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _softAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: const Icon(
                    Icons.directions_bus_filled_rounded,
                    color: _softAccent,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('รถประจำรอบนี้', style: _labelStyle(context)),
                      const SizedBox(height: 3),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          color: _premiumText(context),
                          fontSize: AppText.sizeSubtitle,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      if (plate.isNotEmpty || capacity.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (plate.isNotEmpty)
                              _VehicleInfoPill(
                                icon: Icons.badge_outlined,
                                text: plate,
                              ),
                            if (capacity.isNotEmpty)
                              _VehicleInfoPill(
                                icon: Icons.event_seat_outlined,
                                text: '$capacity ที่นั่ง',
                              ),
                            if (color.isNotEmpty)
                              _VehicleInfoPill(
                                icon: Icons.palette_outlined,
                                text: color,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleInfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _VehicleInfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _mutedTextColor(context), size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: appFont(
              color: AppTheme.mutedText(context),
              fontSize: AppText.sizeCaption,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehiclePhotoNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _VehiclePhotoNavButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: MinTapTarget(child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, color: Colors.white, size: 24),
        )),
      ),
    );
  }
}

class _VehiclePhotoFallback extends StatelessWidget {
  const _VehiclePhotoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFECFDF5),
      child: const Center(
        child: Icon(
          Icons.directions_bus_filled_rounded,
          color: _softAccent,
          size: 42,
        ),
      ),
    );
  }
}

class SeatSelectionSection extends StatelessWidget {
  final Map<String, dynamic>? seatMap;
  final bool isLoading;
  final String? error;
  final Set<String> selectedSeatIds;
  final ValueChanged<Map<String, dynamic>> onSeatTap;
  final VoidCallback onRetry;

  /// ยิงเมื่อล็อกของคนอื่นนับถอยหลังหมดฝั่งเครื่อง เพื่อให้ผังที่นั่งถูกโหลดใหม่
  final VoidCallback? onLockExpired;

  const SeatSelectionSection({
    super.key,
    required this.seatMap,
    required this.isLoading,
    required this.error,
    required this.selectedSeatIds,
    required this.onSeatTap,
    required this.onRetry,
    this.onLockExpired,
  });

  @override
  Widget build(BuildContext context) {
    final map = seatMap ?? <String, dynamic>{};
    final hasSeatMap = map['has_seat_map'] == true;
    final statusCounts = _SeatStatusCounts.from(map);
    // ที่นั่งที่ผู้ใช้คนนี้ถืออยู่เอง — ต้องอธิบายให้ชัด ไม่งั้นอ่านว่าโดนคนอื่นจองไป
    final ownSeatIds = <String>[
      for (final item in asList(map['seats']))
        if (_seatOwnedByCurrentUser(asMap(item))) textOf(asMap(item)['id']),
    ]..sort();
    final showBody = !isLoading && error == null && hasSeatMap;

    return _SectionShell(
      title: 'เลือกที่นั่ง',
      icon: Icons.event_seat_rounded,
      // จำนวนที่ว่างขึ้นหัวข้อไปเลย — เป็นตัวเลขที่ลูกค้ามองหาก่อนอย่างอื่น
      // และไม่ต้องเสียการ์ดทั้งใบให้มัน
      trailing: showBody
          ? _SeatAvailabilityPill(
              available: int.tryParse(textOf(map['available_seats'])) ?? 0,
              total: int.tryParse(textOf(map['total_seats'])) ?? 0,
            )
          : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: isLoading
            ? const _SeatLoadingState(key: ValueKey('seat-loading'))
            : error != null
            ? _SeatErrorState(
                key: const ValueKey('seat-error'),
                error: error!,
                onRetry: onRetry,
              )
            : !hasSeatMap
            ? _NoSeatMapState(key: const ValueKey('no-seat-map'), seatMap: map)
            : Column(
                key: const ValueKey('seat-map'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // คำสั่งเดียวก่อนถึงผัง แล้วปล่อยให้ผังเป็นพระเอก — ของเดิม
                  // มีการ์ดข้อความสามใบซ้อนกันก่อนจะได้เห็นที่นั่งสักที่
                  _SeatPickHint(selectedCount: selectedSeatIds.length),
                  if (ownSeatIds.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _OwnSeatsNote(seatIds: ownSeatIds),
                  ],
                  const SizedBox(height: 14),
                  _BookingSeatMap(
                    seatMap: map,
                    selectedSeatIds: selectedSeatIds,
                    onSeatTap: onSeatTap,
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: VehicleSeatLegend(
                      tones: [
                        SeatTone.available,
                        SeatTone.picking,
                        SeatTone.locked,
                        SeatTone.booked,
                        if (ownSeatIds.isNotEmpty) SeatTone.mine,
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SeatLiveFooter(
                    counts: statusCounts,
                    refreshInterval: _seatRefreshInterval,
                    onLockExpired: onLockExpired,
                  ),
                  const SizedBox(height: 14),
                  _SelectedSeatSummary(
                    seatMap: map,
                    selectedSeatIds: selectedSeatIds,
                    onRemove: onSeatTap,
                  ),
                ],
              ),
      ),
    );
  }
}

/// ผังที่นั่งของขั้นตอนจอง — โครงรถทั้งหมดอยู่ใน [VehicleSeatMap] (ใช้ร่วมกับ
/// หน้าใบจองและห้องกลุ่ม) ตรงนี้เหลือแค่การแปลสถานะที่นั่งเป็นโทนสีและกฎว่า
/// แตะได้ไหม
class _BookingSeatMap extends StatelessWidget {
  final Map<String, dynamic> seatMap;
  final Set<String> selectedSeatIds;
  final ValueChanged<Map<String, dynamic>> onSeatTap;

  const _BookingSeatMap({
    required this.seatMap,
    required this.selectedSeatIds,
    required this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    return VehicleSeatMap(
      seatMap: seatMap,
      toneFor: (seat, id) {
        if (selectedSeatIds.contains(id)) return SeatTone.picking;
        // ที่นั่งที่ตัวเองถืออยู่ใช้โทนเดียวกับที่นั่งว่าง (มีป้ายรูปคนกำกับ)
        // เพื่อไม่ให้อ่านว่า "ของคนอื่น"
        if (_seatOwnedByCurrentUser(seat)) return SeatTone.available;
        final status = textOf(seat['status'], 'available');
        if (status == 'booked') return SeatTone.booked;
        if (status == 'locked') return SeatTone.locked;
        return SeatTone.available;
      },
      selectableFor: (seat, id) =>
          _isSeatAvailable(seat) || _seatLockedByCurrentUser(seat),
      badgeFor: (seat, id) =>
          !selectedSeatIds.contains(id) && _seatOwnedByCurrentUser(seat)
          ? Icons.person_rounded
          : null,
      tooltipFor: (seat, id) =>
          _seatTooltip(seat, id, selected: selectedSeatIds.contains(id)),
      onSeatTap: (seat, _) => onSeatTap(seat),
      // แตะที่นั่งที่เลือกไม่ได้แล้วเงียบสนิท คือจุดที่ลูกค้าคิดว่าแอปค้าง
      // บอกเหตุผลไปเลยว่าทำไมที่นั่งนี้แตะไม่ได้
      onBlockedSeatTap: (seat, id) {
        HapticFeedback.lightImpact();
        AppSnack.show(context, _seatTooltip(seat, id, selected: false));
      },
    );
  }
}

/// "ว่าง 7 / 10" ข้างหัวข้อ — สีเปลี่ยนตามความตึงของที่นั่งที่เหลือ
class _SeatAvailabilityPill extends StatelessWidget {
  final int available;
  final int total;

  const _SeatAvailabilityPill({required this.available, required this.total});

  @override
  Widget build(BuildContext context) {
    final soldOut = available <= 0;
    final tight = available > 0 && available <= 3;
    final color = soldOut
        ? AppTheme.dangerColor
        : tight
        ? AppTheme.warningColor
        : _softAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        soldOut ? 'เต็มแล้ว' : 'ว่าง $available/$total',
        style: appFont(
          color: color,
          fontSize: AppText.sizeCaption,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// บรรทัดบอกวิธีใช้ผัง — ย้ำว่าจำนวนที่นั่งที่เลือก = จำนวนผู้เดินทาง ซึ่งเป็น
/// ความเข้าใจผิดที่เจอบ่อยที่สุดของหน้านี้
class _SeatPickHint extends StatelessWidget {
  final int selectedCount;

  const _SeatPickHint({required this.selectedCount});

  @override
  Widget build(BuildContext context) {
    final picking = selectedCount > 0;

    return Row(
      children: [
        Icon(
          picking ? Icons.check_circle_rounded : Icons.touch_app_rounded,
          size: 17,
          color: picking ? _softAccent : AppTheme.warningColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            picking
                ? 'เลือกไว้ $selectedCount ที่นั่ง = เดินทาง $selectedCount คน แตะซ้ำเพื่อยกเลิก'
                : 'แตะเลือกที่นั่ง — เลือกกี่ที่ ก็คือเดินทางกี่คน',
            style: appFont(
              color: picking
                  ? const Color(0xFF047857)
                  : const Color(0xFF92400E),
              fontWeight: FontWeight.w700,
              fontSize: AppText.sizeLabel,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

/// สรุปที่นั่งที่เลือก — เป็นชิปกดเอาออกได้ทีละที่ ไม่ต้องเลื่อนกลับขึ้นไปหา
/// ที่นั่งนั้นในผัง (สำคัญมากกับรถบัสที่ผังยาวเป็นหน้าจอ)
class _SelectedSeatSummary extends StatelessWidget {
  final Map<String, dynamic> seatMap;
  final Set<String> selectedSeatIds;
  final ValueChanged<Map<String, dynamic>> onRemove;

  const _SelectedSeatSummary({
    required this.seatMap,
    required this.selectedSeatIds,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final seats = selectedSeatIds.toList()..sort();
    final hasSelection = seats.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasSelection
            ? _softAccent.withValues(alpha: 0.08)
            : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: hasSelection
              ? _softAccent.withValues(alpha: 0.18)
              : const Color(0xFFFDE68A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasSelection
                    ? Icons.airline_seat_recline_extra_rounded
                    : Icons.touch_app_rounded,
                color: hasSelection ? _softAccent : AppTheme.warningColor,
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasSelection
                      ? 'ที่นั่งที่เลือก ${seats.length} ที่'
                      : 'กรุณาเลือกที่นั่งก่อนกรอกข้อมูลผู้เดินทาง',
                  style: appFont(
                    color: hasSelection
                        ? const Color(0xFF047857)
                        : const Color(0xFF92400E),
                    fontWeight: FontWeight.w700,
                    fontSize: AppText.sizeLabel,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          if (hasSelection) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: seats.map((id) {
                final seat = _seatById(seatMap, id);

                return MinTapTarget(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    onTap: seat == null
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            onRemove(seat);
                          },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                      decoration: BoxDecoration(
                        color: _softAccent,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            textOf(seat?['label'], id),
                            style: appFont(
                              color: Colors.white,
                              fontSize: AppText.sizeCaption,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// ที่นั่งที่ผู้ใช้ถืออยู่เองในรอบนี้ — ล็อกค้างจากครั้งก่อน หรืออยู่ในใบจองของตัวเอง
class _OwnSeatsNote extends StatelessWidget {
  final List<String> seatIds;

  const _OwnSeatsNote({required this.seatIds});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.how_to_reg_rounded, color: _softAccent, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'ที่นั่ง ${seatIds.join(', ')} เป็นของคุณอยู่แล้ว ไม่ได้ถูกคนอื่นจอง',
            style: appFont(
              color: const Color(0xFF047857),
              fontWeight: FontWeight.w600,
              fontSize: AppText.sizeCaption,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

/// บรรทัดเล็ก ๆ ใต้ผัง — บอกว่าสถานะสด และที่นั่งไหนกำลังถูกคนอื่นจองอยู่
/// (ของเดิมเป็นการ์ดใหญ่ที่มีตัวเลขซ้ำกับคำอธิบายสีใต้ผังทุกตัว)
class _SeatLiveFooter extends StatelessWidget {
  final _SeatStatusCounts counts;
  final Duration refreshInterval;
  final VoidCallback? onLockExpired;

  const _SeatLiveFooter({
    required this.counts,
    required this.refreshInterval,
    this.onLockExpired,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: _softAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                'สถานะที่นั่งอัปเดตทุก ${refreshInterval.inSeconds} วินาที',
                textAlign: TextAlign.center,
                style: appFont(
                  color: _mutedTextColor(context),
                  fontSize: AppText.sizeCaption,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (counts.lockedSeats.isNotEmpty) ...[
          const SizedBox(height: 6),
          _LockedSeatsCountdown(
            seats: counts.lockedSeats,
            onExpired: onLockExpired,
          ),
        ],
      ],
    );
  }
}

class _SeatLoadingState extends StatelessWidget {
  const _SeatLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      decoration: BoxDecoration(
        color: _fieldBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: const Center(child: CircularProgressIndicator(color: _softAccent)),
    );
  }
}

class _SeatErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _SeatErrorState({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CompactNotice(icon: Icons.error_outline_rounded, text: error),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(
            'โหลดผังที่นั่งอีกครั้ง',
            style: appFont(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _NoSeatMapState extends StatelessWidget {
  final Map<String, dynamic> seatMap;

  const _NoSeatMapState({super.key, required this.seatMap});

  @override
  Widget build(BuildContext context) {
    return _CompactNotice(
      icon: Icons.event_seat_outlined,
      text:
          'ทริปนี้ไม่มีผังที่นั่ง เลือกจำนวนผู้เดินทางได้ตามปกติ · ว่าง ${textOf(seatMap['available_seats'], '0')} / ${textOf(seatMap['total_seats'], '0')} ที่นั่ง',
    );
  }
}

class _SeatStatusCounts {
  final int available;
  final int locked;
  final int booked;

  /// ที่นั่งที่ถูกล็อกอยู่ (ส่งทั้ง map ไปให้ตัวนับถอยหลังคำนวณเวลาที่เหลือเอง
  /// ทุกวินาที ไม่ใช่ประกอบเป็นข้อความไว้ล่วงหน้าซึ่งจะค้างจนกว่าจะโหลดใหม่)
  final List<Map<String, dynamic>> lockedSeats;

  const _SeatStatusCounts({
    required this.available,
    required this.locked,
    required this.booked,
    required this.lockedSeats,
  });

  factory _SeatStatusCounts.from(Map<String, dynamic> seatMap) {
    var available = 0;
    var locked = 0;
    var booked = 0;
    final lockedSeats = <Map<String, dynamic>>[];

    for (final item in asList(seatMap['seats'])) {
      final seat = asMap(item);
      final status = textOf(seat['status'], 'available');
      if (status == 'booked') {
        booked++;
      } else if (status == 'locked') {
        locked++;
        lockedSeats.add(seat);
      } else {
        available++;
      }
    }

    return _SeatStatusCounts(
      available: available,
      locked: locked,
      booked: booked,
      lockedSeats: lockedSeats,
    );
  }
}

/// "กำลังจองอยู่: A2 4:32 นาที, A3 1:07 นาที" — เดินถอยหลังเองทุกวินาที
/// ตัวจับเวลาอยู่ในวิดเจ็ตนี้ตัวเดียว จึง rebuild แค่บรรทัดนี้ ไม่ลากทั้งผังที่นั่ง
/// และหยุดเองเมื่อทุกล็อกหมดเวลาแล้ว
class _LockedSeatsCountdown extends StatefulWidget {
  final List<Map<String, dynamic>> seats;
  final VoidCallback? onExpired;

  const _LockedSeatsCountdown({required this.seats, this.onExpired});

  @override
  State<_LockedSeatsCountdown> createState() => _LockedSeatsCountdownState();
}

class _LockedSeatsCountdownState extends State<_LockedSeatsCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _LockedSeatsCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker({bool notifyOnStop = false}) {
    final hasLive = widget.seats.any(
      (seat) => _seatLockRemainingSeconds(seat) > 0,
    );
    if (hasLive && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        _syncTicker(notifyOnStop: true);
      });
    } else if (!hasLive && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
      // นับถึงศูนย์ระหว่างเปิดหน้าอยู่ = ที่นั่งน่าจะหลุดแล้ว ขอผังใหม่รอบเดียว
      if (notifyOnStop) widget.onExpired?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.seats.map((seat) {
      final label = textOf(seat['label'], textOf(seat['id']));
      final remaining = _seatLockRemainingText(seat);
      return remaining.isEmpty ? label : '$label $remaining';
    }).toList();

    return Text(
      'กำลังจองอยู่: ${labels.take(4).join(', ')}${labels.length > 4 ? ' ...' : ''}',
      style: appFont(
        color: const Color(0xFF047857),
        fontSize: AppText.sizeCaption,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
    );
  }
}
