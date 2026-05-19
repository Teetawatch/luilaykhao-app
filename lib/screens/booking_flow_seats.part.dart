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
        borderRadius: BorderRadius.circular(22),
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
                                        color: Colors.white.withValues(
                                          alpha: selected ? 0.95 : 0.55,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.18,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
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
                    borderRadius: BorderRadius.circular(12),
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
                        style: GoogleFonts.anuphan(
                          color: _premiumText(context),
                          fontSize: 15,
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
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _mutedTextColor(context), size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.anuphan(
              color: AppTheme.mutedText(context),
              fontSize: 11.5,
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
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _VehiclePhotoFallback extends StatelessWidget {
  const _VehiclePhotoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE7F3EF),
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

  const SeatSelectionSection({
    super.key,
    required this.seatMap,
    required this.isLoading,
    required this.error,
    required this.selectedSeatIds,
    required this.onSeatTap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final map = seatMap ?? <String, dynamic>{};
    final hasSeatMap = map['has_seat_map'] == true;
    final statusCounts = _SeatStatusCounts.from(map);

    return _SectionShell(
      title: 'เลือกที่นั่ง',
      icon: Icons.event_seat_rounded,
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
                  _SelectedSeatSummary(selectedSeatIds: selectedSeatIds),
                  const SizedBox(height: 14),
                  _SeatRealtimeSummary(
                    counts: statusCounts,
                    refreshInterval: _seatRefreshInterval,
                  ),
                  const SizedBox(height: 16),
                  const Center(child: _SeatLegend()),
                  const SizedBox(height: 18),
                  _VehicleSeatMap(
                    seatMap: map,
                    selectedSeatIds: selectedSeatIds,
                    onSeatTap: onSeatTap,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'ที่นั่งว่าง ${textOf(map['available_seats'], '0')} / ${textOf(map['total_seats'], '0')}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.anuphan(
                      color: _mutedTextColor(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SelectedSeatSummary extends StatelessWidget {
  final Set<String> selectedSeatIds;

  const _SelectedSeatSummary({required this.selectedSeatIds});

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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasSelection
              ? _softAccent.withValues(alpha: 0.18)
              : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasSelection
                ? Icons.airline_seat_recline_extra_rounded
                : Icons.touch_app_rounded,
            color: hasSelection ? _softAccent : AppTheme.warningColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasSelection
                  ? 'ที่นั่งที่เลือก ${seats.join(', ')}'
                  : 'กรุณาเลือกที่นั่งก่อนกรอกข้อมูลผู้เดินทาง',
              style: GoogleFonts.anuphan(
                color: hasSelection
                    ? const Color(0xFF126B5B)
                    : const Color(0xFF92400E),
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatRealtimeSummary extends StatelessWidget {
  final _SeatStatusCounts counts;
  final Duration refreshInterval;

  const _SeatRealtimeSummary({
    required this.counts,
    required this.refreshInterval,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.selectedTint(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _softAccent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sync_rounded, color: _softAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'อัปเดตสถานะที่นั่งทุก ${refreshInterval.inSeconds} วินาที ล็อกที่นั่งชั่วคราวตามจำนวนที่นั่งที่เลือก',
                  style: GoogleFonts.anuphan(
                    color: const Color(0xFF126B5B),
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SeatStatusPill(
                color: const Color(0xFFBBF7D0),
                textColor: const Color(0xFF065F46),
                label: 'ว่าง',
                value: counts.available,
              ),
              _SeatStatusPill(
                color: const Color(0xFFF59E0B),
                textColor: const Color(0xFF78350F),
                label: 'กำลังจอง',
                value: counts.locked,
              ),
              _SeatStatusPill(
                color: const Color(0xFFEF4444),
                textColor: Colors.white,
                label: 'จองแล้ว',
                value: counts.booked,
              ),
            ],
          ),
          if (counts.lockedSeatLabels.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'กำลังจองอยู่: ${counts.lockedSeatLabels.take(4).join(', ')}${counts.lockedSeatLabels.length > 4 ? ' ...' : ''}',
              style: GoogleFonts.anuphan(
                color: const Color(0xFF126B5B),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeatStatusPill extends StatelessWidget {
  final Color color;
  final Color textColor;
  final String label;
  final int value;

  const _SeatStatusPill({
    required this.color,
    required this.textColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Text(
        '$label $value',
        style: GoogleFonts.anuphan(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SeatLegend extends StatelessWidget {
  const _SeatLegend();

  @override
  Widget build(BuildContext context) {
    const items = [
      _SeatLegendItem(Color(0xFFBBF7D0), 'ว่าง'),
      _SeatLegendItem(_softAccent, 'กำลังเลือก'),
      _SeatLegendItem(Color(0xFFF59E0B), 'กำลังจอง'),
      _SeatLegendItem(Color(0xFFEF4444), 'จองแล้ว'),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              item.label,
              style: GoogleFonts.anuphan(
                color: _mutedTextColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _VehicleSeatMap extends StatelessWidget {
  final Map<String, dynamic> seatMap;
  final Set<String> selectedSeatIds;
  final ValueChanged<Map<String, dynamic>> onSeatTap;

  const _VehicleSeatMap({
    required this.seatMap,
    required this.selectedSeatIds,
    required this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    final frontSeatId = textOf(seatMap['front_seat']);
    final frontSeat = frontSeatId.isEmpty
        ? null
        : _seatById(seatMap, frontSeatId);
    final rows = _seatRows(seatMap);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _fieldBackground(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder(context)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  frontSeat == null
                      ? const SizedBox(width: 58)
                      : _SeatButton(
                          seat: frontSeat,
                          selected: selectedSeatIds.contains(frontSeatId),
                          onTap: () => onSeatTap(frontSeat),
                        ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _VehicleLabel(
                      text: textOf(seatMap['front_label'], 'หน้ารถ'),
                    ),
                  ),
                  _DriverBlock(show: seatMap['show_driver'] != false),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: 292,
                  child: Divider(height: 1, color: Color(0xFFD8DEDB)),
                ),
              ),
              ...rows.map((row) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SeatRow(
                    row: row,
                    seatMap: seatMap,
                    selectedSeatIds: selectedSeatIds,
                    onSeatTap: onSeatTap,
                  ),
                );
              }),
              const SizedBox(height: 4),
              _VehicleLabel(
                text: textOf(
                  seatMap['rear_label'],
                  'ท้ายรถ (สำหรับเก็บสัมภาระ)',
                ),
                muted: true,
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _SeatRow extends StatelessWidget {
  final _SeatRowData row;
  final Map<String, dynamic> seatMap;
  final Set<String> selectedSeatIds;
  final ValueChanged<Map<String, dynamic>> onSeatTap;

  const _SeatRow({
    required this.row,
    required this.seatMap,
    required this.selectedSeatIds,
    required this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget seats(List<String> ids) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: ids.map((id) {
          final seat = _seatById(seatMap, id);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _SeatButton(
              seat: seat,
              seatId: id,
              selected: selectedSeatIds.contains(id),
              onTap: seat == null ? null : () => onSeatTap(seat),
            ),
          );
        }).toList(),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        seats(row.left),
        if (row.center.isNotEmpty) ...[
          const SizedBox(width: 8),
          seats(row.center),
        ],
        SizedBox(
          width: 44,
          child: Center(
            child: row.hasAisle
                ? Container(
                    width: 2,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8DEDB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                : null,
          ),
        ),
        seats(row.right),
      ],
    );
  }
}

class _SeatButton extends StatelessWidget {
  final Map<String, dynamic>? seat;
  final String? seatId;
  final bool selected;
  final VoidCallback? onTap;

  const _SeatButton({
    required this.seat,
    this.seatId,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final id = textOf(seat?['id'] ?? seatId);
    final status = textOf(seat?['status'], 'available');
    final lockedByCurrentUser = seat != null && _seatLockedByCurrentUser(seat!);
    final disabled =
        seat == null ||
        status == 'booked' ||
        (status == 'locked' && !lockedByCurrentUser);
    final color = _seatColor(status: status, selected: selected);
    final muted = disabled && status != 'booked';
    final seatColor = muted ? color.withValues(alpha: 0.55) : color;
    final foregroundColor = selected || status == 'booked'
        ? Colors.white
        : status == 'locked'
        ? const Color(0xFF78350F)
        : const Color(0xFF065F46);
    final labelColor = selected
        ? _softAccent
        : status == 'locked'
        ? const Color(0xFF92400E).withValues(alpha: muted ? 0.62 : 1)
        : _mutedTextColor(context).withValues(alpha: muted ? 0.62 : 1);

    return Tooltip(
      message: _seatTooltip(seat, id, selected: selected),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 52,
          height: 60,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 42,
                height: 38,
                decoration: BoxDecoration(
                  color: seatColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _softAccent.withValues(alpha: 0.24),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.airline_seat_recline_extra_rounded,
                      color: foregroundColor,
                      size: 20,
                    ),
                    if (selected || status == 'locked' || status == 'booked')
                      Positioned(
                        top: 3,
                        right: 3,
                        child: Icon(
                          selected
                              ? Icons.check_circle
                              : status == 'booked'
                              ? Icons.lock_rounded
                              : Icons.timer_rounded,
                          color: selected || status == 'booked'
                              ? Colors.white
                              : const Color(0xFF78350F),
                          size: 11,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                textOf(seat?['label'], id),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.anuphan(
                  color: labelColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverBlock extends StatelessWidget {
  final bool show;

  const _DriverBlock({required this.show});

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox(width: 58);

    return SizedBox(
      width: 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.drive_eta_rounded,
              color: _mutedTextColor(context),
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'คนขับ',
            style: GoogleFonts.anuphan(
              color: _mutedTextColor(context),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleLabel extends StatelessWidget {
  final String text;
  final bool muted;

  const _VehicleLabel({required this.text, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: muted ? Colors.white : _softAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: muted ? _cardBorder(context) : Colors.transparent),
      ),
      child: Text(
        text,
        style: GoogleFonts.anuphan(
          color: muted ? _mutedTextColor(context) : _softAccent,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
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
        borderRadius: BorderRadius.circular(22),
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
            style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
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

class _SeatLegendItem {
  final Color color;
  final String label;

  const _SeatLegendItem(this.color, this.label);
}

class _SeatStatusCounts {
  final int available;
  final int locked;
  final int booked;
  final List<String> lockedSeatLabels;

  const _SeatStatusCounts({
    required this.available,
    required this.locked,
    required this.booked,
    required this.lockedSeatLabels,
  });

  factory _SeatStatusCounts.from(Map<String, dynamic> seatMap) {
    var available = 0;
    var locked = 0;
    var booked = 0;
    final lockedSeatLabels = <String>[];

    for (final item in asList(seatMap['seats'])) {
      final seat = asMap(item);
      final status = textOf(seat['status'], 'available');
      if (status == 'booked') {
        booked++;
      } else if (status == 'locked') {
        locked++;
        final seatLabel = textOf(seat['label'], textOf(seat['id']));
        final remaining = _seatLockRemainingText(seat);
        lockedSeatLabels.add(
          remaining.isEmpty ? seatLabel : '$seatLabel $remaining',
        );
      } else {
        available++;
      }
    }

    return _SeatStatusCounts(
      available: available,
      locked: locked,
      booked: booked,
      lockedSeatLabels: lockedSeatLabels,
    );
  }
}

class _SeatRowData {
  final List<String> left;
  final List<String> right;
  final List<String> center;
  final bool hasAisle;

  const _SeatRowData({
    required this.left,
    required this.right,
    required this.center,
    required this.hasAisle,
  });
}

