part of 'customer_app_screen.dart';

/// "ภาพจากทริป" — photos taken by staff during the customer's trip.
/// Lazily loaded from /bookings/{ref}/photos so the booking detail sheet
/// stays fast for bookings that don't yet have any photos.
class BookingPhotosSection extends StatefulWidget {
  final String bookingRef;

  const BookingPhotosSection({super.key, required this.bookingRef});

  @override
  State<BookingPhotosSection> createState() => _BookingPhotosSectionState();
}

class _BookingPhotosSectionState extends State<BookingPhotosSection> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppProvider>().bookingPhotos(widget.bookingRef);
  }

  void _reload() {
    setState(() {
      _future = context.read<AppProvider>().bookingPhotos(widget.bookingRef);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final photos = snap.data!;
        final urls = photos
            .map((p) => ApiConfig.mediaUrl(p['url'] ?? p['path']))
            .where((u) => u.isNotEmpty)
            .toList();
        if (urls.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                const _SheetSectionTitle(
                  icon: Icons.photo_camera_back_rounded,
                  title: 'ภาพจากทริป',
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${urls.length}',
                    style: GoogleFonts.anuphan(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'รีเฟรช',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'แตะเพื่อดูเต็มจอ · กดปุ่มดาวน์โหลดเพื่อบันทึก/แชร์',
              style: GoogleFonts.anuphan(
                fontSize: 12,
                color: AppTheme.mutedText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: urls.length,
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => Navigator.of(context).push(
                  PageRouteBuilder(
                    opaque: false,
                    barrierColor: Colors.black,
                    pageBuilder: (_, _, _) => _BookingPhotoViewer(
                      urls: urls,
                      initialIndex: index,
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: urls[index],
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      color: const Color(0xFFE7ECEA),
                    ),
                    errorWidget: (_, _, _) => Container(
                      color: const Color(0xFFE7ECEA),
                      child: const Icon(
                        Icons.image_not_supported_rounded,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _shareAll(context, urls),
                icon: const Icon(Icons.download_rounded),
                label: Text('ดาวน์โหลด/แชร์ทั้งหมด (${urls.length} รูป)'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareAll(BuildContext context, List<String> urls) async {
    showSnack(context, 'กำลังเตรียมรูป…');
    try {
      final files = await _downloadAll(urls);
      if (files.isEmpty) {
        if (context.mounted) showSnack(context, 'ดาวน์โหลดรูปไม่สำเร็จ');
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: files.map((p) => XFile(p)).toList(),
          subject: 'ภาพจากทริป Luilaykhao',
        ),
      );
    } catch (e) {
      if (context.mounted) showSnack(context, 'ดาวน์โหลดไม่สำเร็จ: $e');
    }
  }

  Future<List<String>> _downloadAll(List<String> urls) async {
    final dir = await getTemporaryDirectory();
    final paths = <String>[];
    for (var i = 0; i < urls.length; i++) {
      final saved = await _downloadOne(
        urls[i],
        '${dir.path}/llk_${widget.bookingRef}_$i.jpg',
      );
      if (saved != null) paths.add(saved);
    }
    return paths;
  }
}

class _BookingPhotoViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _BookingPhotoViewer({
    required this.urls,
    required this.initialIndex,
  });

  @override
  State<_BookingPhotoViewer> createState() => _BookingPhotoViewerState();
}

class _BookingPhotoViewerState extends State<_BookingPhotoViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _current = widget.initialIndex;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveCurrent() async {
    if (_saving) return;
    setState(() => _saving = true);
    final url = widget.urls[_current];
    try {
      final dir = await getTemporaryDirectory();
      final saved = await _downloadOne(
        url,
        '${dir.path}/llk_photo_$_current.jpg',
      );
      if (!mounted) return;
      if (saved == null) {
        showSnack(context, 'ดาวน์โหลดไม่สำเร็จ');
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(saved)],
          subject: 'ภาพจากทริป Luilaykhao',
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, 'เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.urls[i],
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const CircularProgressIndicator(
                      color: Colors.white,
                    ),
                    errorWidget: (_, _, _) => const Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _saving ? null : _saveCurrent,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.ios_share_rounded,
                            color: Colors.white,
                          ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_current + 1} / ${widget.urls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
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

Future<String?> _downloadOne(String url, String destPath) async {
  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return null;
    final file = File(destPath);
    await file.writeAsBytes(res.bodyBytes);
    return file.path;
  } catch (_) {
    return null;
  }
}
