part of 'trip_detail_screen.dart';

class DestinationInfoSection extends StatelessWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> reviews;
  final bool isLoading;

  const DestinationInfoSection({
    super.key,
    required this.trip,
    required this.reviews,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    if (isLoading) {
      return const _PremiumCard(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Skeleton(width: 110, height: 28, radius: 14),
              Spacer(),
              Skeleton(width: 80, height: 28, radius: 14),
            ]),
            SizedBox(height: 18),
            Skeleton(width: double.infinity, height: 36, radius: 12),
            SizedBox(height: 8),
            Skeleton(width: 220, height: 36, radius: 12),
            SizedBox(height: 14),
            Skeleton(width: 180, height: 18, radius: 9),
            SizedBox(height: 24),
            Skeleton(width: double.infinity, height: 88, radius: 20),
          ],
        ),
      );
    }

    final chips = _quickInfoItems(trip);
    final location = textOf(trip['location'] ?? trip['destination']).trim();
    final travelers =
        (num.tryParse('${trip['confirmed_passengers_count'] ?? 0}') ?? 0)
            .toInt();

    return _PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── top badge row ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                _RatingSummary(trip: trip, reviews: reviews),
                const Spacer(),
                if (travelers > 0)
                  _InfoChip(
                    icon: Icons.groups_rounded,
                    label: '$travelers คนร่วมเดินทางแล้ว',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── title ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _tripTitle(trip),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : _premiumText,
                height: 1.2,
                letterSpacing: -0.5,
              ),
            ),
          ),
          // ── location ───────────────────────────────────────────────
          if (location.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _softAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 13,
                      color: _softAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: 13,
                        color: _mutedText,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // ── stats grid ─────────────────────────────────────────────
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFE9F5F1),
                ),
              ),
              child: QuickInfoChips(trip: trip),
            ),
          ] else
            const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class QuickInfoChips extends StatelessWidget {
  final Map<String, dynamic> trip;

  const QuickInfoChips({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final chips = _quickInfoItems(trip);
    if (chips.isEmpty) return const SizedBox.shrink();

    // 2-column grid layout
    final rows = <List<_QuickInfoItem>>[];
    for (var i = 0; i < chips.length; i += 2) {
      rows.add([
        chips[i],
        if (i + 1 < chips.length) chips[i + 1],
      ]);
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final isLast = entry.key == rows.length - 1;
          final row = entry.value;
          return Column(
            children: [
              Row(
                children: row.asMap().entries.map((e) {
                  final isLastInRow = e.key == row.length - 1;
                  final chip = e.value;
                  return Expanded(
                    child: _StatTile(
                      icon: chip.icon,
                      label: chip.label,
                      showRightBorder: !isLastInRow && row.length > 1,
                      showBottomBorder: !isLast,
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool showRightBorder;
  final bool showBottomBorder;

  const _StatTile({
    required this.icon,
    required this.label,
    this.showRightBorder = false,
    this.showBottomBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFE9F5F1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          right: showRightBorder
              ? BorderSide(color: dividerColor)
              : BorderSide.none,
          bottom: showBottomBorder
              ? BorderSide(color: dividerColor)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _softAccent.withValues(alpha: 0.18),
                  _softAccent.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: _softAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white.withValues(alpha: 0.85) : _premiumText,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AboutSection extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool isLoading;
  final bool isExpanded;
  final VoidCallback onToggle;

  const AboutSection({
    super.key,
    required this.trip,
    required this.isLoading,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 150, height: 24),
            SizedBox(height: 16),
            Skeleton(width: double.infinity, height: 16),
            SizedBox(height: 8),
            Skeleton(width: double.infinity, height: 16),
            SizedBox(height: 8),
            Skeleton(width: 260, height: 16),
          ],
        ),
      );
    }

    final description = textOf(trip['description']).trim();
    if (description.isEmpty) return const SizedBox.shrink();

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.article_outlined,
            title: 'เกี่ยวกับทริปนี้',
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: Text(
              description,
              maxLines: isExpanded ? null : 5,
              overflow: isExpanded ? TextOverflow.visible : TextOverflow.fade,
              style: appFont(
                fontSize: 15,
                height: 1.75,
                color: const Color(0xFF374151),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          if (description.length > 160) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onToggle,
              style: TextButton.styleFrom(
                foregroundColor: _softAccent,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                isExpanded ? 'อ่านน้อยลง' : 'อ่านเพิ่มเติม',
                style: appFont(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PhotoGallerySection extends StatelessWidget {
  final Map<String, dynamic> trip;

  const PhotoGallerySection({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final images = _detailGalleryImages(trip);
    if (images.isEmpty) return const SizedBox.shrink();

    return _PremiumCard(
      padding: const EdgeInsets.fromLTRB(24, 24, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: _SectionHeader(
              icon: Icons.photo_library_outlined,
              title: 'รูปภาพ',
              subtitle: '${images.length} รูป',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 24),
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _openFullscreen(context, images, index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: images[index],
                    width: 120,
                    height: 160,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        const Skeleton(width: 120, height: 160, radius: 16),
                    errorWidget: (_, _, _) => Container(
                      width: 120,
                      height: 160,
                      color: const Color(0xFFE7ECEA),
                      child: const Icon(
                        Icons.landscape_rounded,
                        color: _softAccent,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullscreen(
    BuildContext context,
    List<String> images,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            _FullscreenGallery(images: images, initialIndex: initialIndex),
      ),
    );
  }
}

/// Trip videos — shown right after the photo gallery. Each tile is a tappable
/// play card; tapping opens a fullscreen player.
class VideoGallerySection extends StatelessWidget {
  final Map<String, dynamic> trip;

  const VideoGallerySection({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final videos = _tripVideos(trip);
    if (videos.isEmpty) return const SizedBox.shrink();

    return _PremiumCard(
      padding: const EdgeInsets.fromLTRB(24, 24, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: _SectionHeader(
              icon: Icons.videocam_outlined,
              title: 'วิดีโอ',
              subtitle: '${videos.length} คลิป',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 24),
              itemCount: videos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _openVideo(context, videos[index]),
                child: _VideoThumbCard(url: videos[index], index: index),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openVideo(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenVideoPlayer(url: url),
      ),
    );
  }
}

/// Video tile that renders the clip's first frame as a poster. A muted,
/// non-playing [VideoPlayerController] is initialised lazily (tiles off-screen
/// in the horizontal list aren't built until scrolled to) and disposed with the
/// tile, so only the visible cards hold a decoder. Falls back to a gradient
/// placeholder while loading or if the frame can't be decoded.
class _VideoThumbCard extends StatefulWidget {
  final String url;
  final int index;
  final double width;
  final double height;
  final bool showLabel;

  const _VideoThumbCard({
    required this.url,
    required this.index,
    this.width = 240,
    this.height = 160,
    this.showLabel = true,
  });

  @override
  State<_VideoThumbCard> createState() => _VideoThumbCardState();
}

class _VideoThumbCardState extends State<_VideoThumbCard> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setVolume(0);
      // Nudge to a frame so the texture paints a poster rather than black.
      await controller.seekTo(const Duration(milliseconds: 100));
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // Keep the gradient placeholder on any decode/network failure.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final showFrame = _ready && controller != null;

    final playSize = widget.height < 110 ? 38.0 : 54.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showFrame)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1F2937), Color(0xFF0F172A)],
                  ),
                ),
              ),
            // Subtle scrim so the play button and label stay legible.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x66000000)],
                ),
              ),
            ),
            Center(
              child: Container(
                width: playSize,
                height: playSize,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: _premiumText,
                  size: playSize * 0.63,
                ),
              ),
            ),
            if (widget.showLabel)
              Positioned(
                left: 12,
                bottom: 10,
                child: Text(
                  'วิดีโอ ${widget.index + 1}',
                  style: appFont(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenVideoPlayer extends StatefulWidget {
  final String url;

  const _FullscreenVideoPlayer({required this.url});

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _videoController = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
          aspectRatio: controller.value.aspectRatio == 0
              ? 16 / 9
              : controller.value.aspectRatio,
          materialProgressColors: ChewieProgressColors(
            playedColor: _softAccent,
            handleColor: _softAccent,
          ),
        );
      });
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(child: _buildContent()),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_hasError) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'ไม่สามารถเล่นวิดีโอนี้ได้',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final chewie = _chewieController;
    if (chewie == null) {
      return const CircularProgressIndicator(color: Colors.white54);
    }

    return Chewie(controller: chewie);
  }
}

class _FullscreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullscreenGallery({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late int _currentIndex;
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.paddingOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, index) => InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.images[index],
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                    errorWidget: (_, _, _) => const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white54,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: safePadding.top + 8,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                bottom: safePadding.bottom + 20,
                left: 0,
                right: 0,
                child: Text(
                  '${_currentIndex + 1} / ${widget.images.length}',
                  textAlign: TextAlign.center,
                  style: appFont(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MustKnowSection extends StatelessWidget {
  final Map<String, dynamic> trip;

  const MustKnowSection({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final items = _mustKnowItems(trip);
    final remarks = textOf(asMap(trip['must_know'])['remarks']).trim();
    if (items.isEmpty && remarks.isEmpty) return const SizedBox.shrink();
    final isDark = AppTheme.isDark(context);

    return _PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // amber accent header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFFB45309).withValues(alpha: 0.12)
                  : const Color(0xFFFFFBEB),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFFB45309).withValues(alpha: 0.18)
                      : const Color(0xFFFDE68A),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFB45309).withValues(alpha: 0.2)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'สิ่งที่ควรรู้ก่อนเดินทาง',
                        style: appFont(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF92400E),
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'อ่านก่อนทำการจอง',
                        style: appFont(
                          fontSize: 11.5,
                          color: isDark
                              ? const Color(0xFFD97706)
                              : const Color(0xFFB45309),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                ...items.map((item) => _MustKnowItemRow(item: item)),
                if (remarks.isNotEmpty)
                  _FeatureRow(
                    icon: Icons.notes_rounded,
                    title: remarks,
                    iconColor: const Color(0xFFD97706),
                    iconBackground: const Color(0xFFFEF3C7),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MustKnowItemRow extends StatelessWidget {
  final _MustKnowItem item;

  const _MustKnowItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final title = item.price > 0
        ? '${item.name} · ${money(item.price)} ${item.priceTypeLabel}'
        : item.name;

    if (!item.hasImage) {
      return _FeatureRow(
        icon: Icons.error_outline_rounded,
        title: title,
        iconColor: const Color(0xFFD97706),
        iconBackground: const Color(0xFFFEF3C7),
      );
    }

    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) =>
                    _FullscreenGallery(images: [item.imageUrl], initialIndex: 0),
              ),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      width: 52,
                      height: 52,
                      color: const Color(0xFFFEF3C7),
                    ),
                    errorWidget: (_, _, _) => Container(
                      width: 52,
                      height: 52,
                      color: const Color(0xFFFEF3C7),
                      child: const Icon(
                        Icons.broken_image_rounded,
                        size: 20,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 3,
                  bottom: 3,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.zoom_in_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: appFont(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white.withValues(alpha: 0.9) : _premiumText,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PreparationsSection extends StatelessWidget {
  final Map<String, dynamic> trip;

  const PreparationsSection({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final items = _textItems(trip['preparations']);
    if (items.isEmpty) return const SizedBox.shrink();
    final isDark = AppTheme.isDark(context);

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.backpack_rounded,
            title: 'สิ่งที่ควรเตรียม',
            subtitle: 'เตรียมตัวก่อนออกเดินทาง',
          ),
          const SizedBox(height: 20),
          // checklist with sequential numbers
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final text = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _softAccent.withValues(alpha: isDark ? 0.18 : 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: appFont(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _softAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        text,
                        style: appFont(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.85)
                              : _premiumText,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
