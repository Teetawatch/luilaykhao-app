import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';
import '../widgets/app_snack.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/skeleton.dart';
import '../widgets/travel_widgets.dart' show PrimaryCTAButton;
import 'staff_check_in_screen.dart' show asMap, asList, textOf;
import '../widgets/confirm_dialog.dart';

/// รูปต่อคำขอที่แอปส่ง — เซิร์ฟเวอร์รับได้ถึง 20 แต่บนเน็ตมือถือชุดเล็กกว่า
/// พลาดแล้วเสียน้อยกว่า และไม่ชนเพดาน body ของ nginx
const int _kChunkSize = 3;

/// ส่งพร้อมกันกี่ชุด — 2 พอให้ท่อเต็มโดยไม่แย่งแบนด์วิดท์กันจนหมดเวลาทั้งคู่
const int _kConcurrency = 2;

/// ด้านยาวสุดของรูปก่อนอัป เท่ากับที่หน้าแอดมินย่อไว้ (2400px) — ลูกค้าได้รูป
/// คมพอพิมพ์ แต่ไม่ต้องรอไฟล์ 12MB จากกล้องมือถือ
const double _kMaxEdge = 2400;

/// อัลบั้มรอบเดินทาง ฝั่งสตาฟ — เลือกรูปจากเครื่องทีละหลายรูปแล้วอัปขึ้น R2
/// เข้าอัลบั้มของรอบ ลูกค้าเห็นในหน้ารูปของการจองทันที
///
/// อัปได้ตั้งแต่วันเดินทางจนถึงไม่กี่วันหลังกลับ (เซิร์ฟเวอร์เป็นคนบอกผ่าน
/// `can_upload` / `upload_until`) และลบได้เฉพาะรูปที่ตัวเองอัป
class StaffPhotosScreen extends StatefulWidget {
  final int scheduleId;
  final String title;

  const StaffPhotosScreen({
    super.key,
    required this.scheduleId,
    required this.title,
  });

  @override
  State<StaffPhotosScreen> createState() => _StaffPhotosScreenState();
}

class _StaffPhotosScreenState extends State<StaffPhotosScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  /// งานอัปชุดปัจจุบัน — null เมื่อไม่ได้อัปอยู่
  _UploadRun? _run;

  final Set<int> _deleting = {};

  bool get _uploading => _run != null && !_run!.finished;

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
      final data = await context.read<AppProvider>().loadStaffPhotos(
        widget.scheduleId,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pick({required bool camera}) async {
    if (_uploading) return;
    HapticFeedback.selectionClick();

    final List<XFile> picked;
    try {
      final picker = ImagePicker();
      if (camera) {
        final shot = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: _kMaxEdge,
          maxHeight: _kMaxEdge,
          imageQuality: 85,
        );
        picked = shot == null ? const [] : [shot];
      } else {
        picked = await picker.pickMultiImage(
          maxWidth: _kMaxEdge,
          maxHeight: _kMaxEdge,
          imageQuality: 85,
        );
      }
    } catch (e) {
      _snack('เปิดรูปไม่สำเร็จ: $e');
      return;
    }

    if (picked.isEmpty || !mounted) return;
    await _upload(picked.map((f) => f.path).toList());
  }

  /// แบ่งรูปเป็นชุดละ [_kChunkSize] แล้วส่งพร้อมกัน [_kConcurrency] ชุด
  ///
  /// ชุดที่ล้มเหลวเก็บไว้ใน [_UploadRun.failed] ให้กด "ลองใหม่" เฉพาะชุดนั้น —
  /// รูปที่ขึ้นแล้วไม่ต้องส่งซ้ำ
  Future<void> _upload(List<String> paths) async {
    final run = _UploadRun(total: paths.length);
    setState(() => _run = run);

    final chunks = <List<String>>[
      for (var i = 0; i < paths.length; i += _kChunkSize)
        paths.sublist(
          i,
          i + _kChunkSize > paths.length ? paths.length : i + _kChunkSize,
        ),
    ];
    var cursor = 0;
    final provider = context.read<AppProvider>();

    Future<void> worker() async {
      while (cursor < chunks.length) {
        final chunk = chunks[cursor++];
        try {
          final result = await provider.uploadStaffPhotos(
            widget.scheduleId,
            chunk,
          );
          run.done += chunk.length;
          final uploaded = asList(result['uploaded']).map(asMap).toList();
          if (mounted && _data != null) {
            setState(() {
              _data = {
                ..._data!,
                'photos': [...asList(_data!['photos']), ...uploaded],
                'photos_count':
                    result['photos_count'] ?? _data!['photos_count'],
              };
            });
          }
        } on ApiException catch (e) {
          run.failed.addAll(chunk);
          run.lastError = e.message;
        } catch (e) {
          run.failed.addAll(chunk);
          run.lastError = 'เน็ตหลุดระหว่างอัป';
        }
        if (mounted) setState(() {});
      }
    }

    await Future.wait([
      for (var i = 0; i < _kConcurrency && i < chunks.length; i++) worker(),
    ]);

    run.finished = true;
    if (!mounted) return;
    setState(() {});

    if (run.failed.isEmpty) {
      HapticFeedback.mediumImpact();
      AppSnack.success(context, 'อัปรูปแล้ว ${run.done} รูป');
      setState(() => _run = null);
    }
    // ดึงอัลบั้มจริงกลับมา — ลำดับ/ภาพย่อที่เซิร์ฟเวอร์สร้างเสร็จแล้ว
    unawaited(_refreshQuietly());
  }

  Future<void> _refreshQuietly() async {
    try {
      final data = await context.read<AppProvider>().loadStaffPhotos(
        widget.scheduleId,
      );
      if (mounted) setState(() => _data = data);
    } catch (_) {
      // ของที่ต่อท้ายไว้ตอนอัปยังใช้ได้ — ไม่ต้องขึ้น error ซ้ำ
    }
  }

  Future<void> _retryFailed() async {
    final failed = List<String>.from(_run?.failed ?? const []);
    if (failed.isEmpty) return;
    await _upload(failed);
  }

  Future<void> _delete(Map<String, dynamic> photo) async {
    final id = int.tryParse('${photo['id']}');
    if (id == null || _deleting.contains(id)) return;

    final ok = await showConfirmDialog(
      context,
      title: 'ลบรูปนี้?',
      message: 'ลูกค้าจะไม่เห็นรูปนี้ในอัลบั้มอีก',
      tone: ConfirmTone.danger,
      icon: Icons.hide_image_outlined,
      confirmLabel: 'ลบรูป',
    );
    if (!ok || !mounted) return;

    setState(() => _deleting.add(id));
    try {
      final data = await context.read<AppProvider>().deleteStaffPhoto(
        widget.scheduleId,
        id,
      );
      if (!mounted) return;
      setState(() => _data = data);
      if (Navigator.of(context).canPop() && _viewerOpen) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _deleting.remove(id));
    }
  }

  bool _viewerOpen = false;

  Future<void> _openViewer(Map<String, dynamic> photo, bool mine) async {
    _viewerOpen = true;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PhotoViewer(
          url: textOf(photo['url']),
          uploader: textOf(photo['uploader_name']),
          onDelete: mine ? () => _delete(photo) : null,
        ),
      ),
    );
    _viewerOpen = false;
  }

  void _snack(String message) {
    if (!mounted) return;
    AppSnack.show(context, message);
  }

  Future<bool> _confirmLeave() {
    return showConfirmDialog(
      context,
      title: 'ยังอัปรูปไม่เสร็จ',
      message:
          'ออกจากหน้านี้ได้ รูปจะอัปต่อจนเสร็จ แต่ถ้ามีรูปที่อัปไม่ขึ้นจะไม่เห็นปุ่มลองใหม่',
      tone: ConfirmTone.warning,
      icon: Icons.cloud_upload_outlined,
      confirmLabel: 'ออกเลย',
      cancelLabel: 'รอให้เสร็จ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final canUpload = _data?['can_upload'] == true;

    return PopScope(
      canPop: !_uploading,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background(context),
        appBar: AppBar(
          // งานสตาฟชิดซ้ายทุกหน้า (ธีมรวมตั้ง centerTitle: true ไว้)
          centerTitle: false,
          title: Text(
            'รูปทริป',
            style: appFont(
              fontSize: AppText.sizeTitle,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'โหลดใหม่',
              onPressed: _loading || _uploading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
        bottomNavigationBar: _data == null
            ? null
            : _UploadBar(
                canUpload: canUpload,
                uploading: _uploading,
                onGallery: () => _pick(camera: false),
                onCamera: () => _pick(camera: true),
              ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _data == null) {
      return const SkeletonList(count: 4, padding: EdgeInsets.only(top: 8));
    }
    if (_error != null && _data == null) {
      return ScrollableEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'โหลดอัลบั้มไม่สำเร็จ',
        body: _error!,
        actionLabel: 'ลองใหม่',
        onAction: _load,
        accent: AppTheme.errorColor,
      );
    }

    final photos = asList(_data?['photos']).map(asMap).toList();
    final myId = context.read<AppProvider>().userId;
    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeWidth = ((width - 32) / 3 * dpr).round();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          sliver: SliverList.list(
            children: [
              _AlbumInfoCard(
                title: widget.title,
                count: photos.length,
                canUpload: _data?['can_upload'] == true,
                uploadUntil: textOf(_data?['upload_until']),
                retentionDays: int.tryParse('${_data?['retention_days']}') ?? 7,
              ),
              if (_run != null) ...[
                const SizedBox(height: 12),
                _UploadProgressCard(
                  run: _run!,
                  onRetry: _retryFailed,
                  onDismiss: () => setState(() => _run = null),
                ),
              ],
            ],
          ),
        ),
        if (photos.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 48,
                    color: AppTheme.mutedText(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ยังไม่มีรูปในรอบนี้',
                    style: appFont(
                      fontSize: AppText.sizeSubtitle,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'เลือกรูปจากเครื่องได้ทีละหลายรูป',
                    textAlign: TextAlign.center,
                    style: appFont(
                      fontSize: AppText.sizeBody,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                final id = int.tryParse('${photo['id']}');
                final mine =
                    myId != null &&
                    int.tryParse('${photo['uploaded_by']}') == myId;
                return _PhotoTile(
                  thumb: textOf(photo['thumb_url']).isNotEmpty
                      ? textOf(photo['thumb_url'])
                      : textOf(photo['url']),
                  decodeWidth: decodeWidth,
                  mine: mine,
                  deleting: id != null && _deleting.contains(id),
                  onTap: () => _openViewer(photo, mine),
                  onDelete: mine ? () => _delete(photo) : null,
                );
              },
            ),
          ),
      ],
    );
  }
}

/// ความคืบหน้าของการอัปหนึ่งครั้ง — แก้ค่าในที่แล้ว setState ให้หน้าจอวาดใหม่
class _UploadRun {
  final int total;
  int done = 0;
  final List<String> failed = [];
  String? lastError;
  bool finished = false;

  _UploadRun({required this.total});

  double get progress => total == 0 ? 0 : (done + failed.length) / total;
}

class _AlbumInfoCard extends StatelessWidget {
  final String title;
  final int count;
  final bool canUpload;
  final String uploadUntil;
  final int retentionDays;

  const _AlbumInfoCard({
    required this.title,
    required this.count,
    required this.canUpload,
    required this.uploadUntil,
    required this.retentionDays,
  });

  @override
  Widget build(BuildContext context) {
    final until = DateTime.tryParse(uploadUntil);
    final muted = AppTheme.mutedText(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeSubtitle,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count รูป',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ลูกค้าในรอบนี้เห็นรูปในหน้า "รูปจากทริป" ของการจองทันที '
            'และรูปจะถูกลบอัตโนมัติ $retentionDays วันหลังอัป',
            style: appFont(
              fontSize: AppText.sizeLabel,
              color: muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                canUpload ? Icons.cloud_upload_outlined : Icons.lock_clock,
                size: 16,
                color: canUpload
                    ? AppTheme.primaryColor
                    : AppTheme.warningColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  canUpload
                      ? (until != null
                            ? 'อัปได้ถึง ${thaiDateShort(until)}'
                            : 'อัปได้แล้ว')
                      : 'ยังอัปไม่ได้ — เปิดรับตั้งแต่วันเดินทาง'
                            '${until != null ? 'ถึง ${thaiDateShort(until)}' : ''}',
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w700,
                    color: canUpload
                        ? AppTheme.primaryColor
                        : AppTheme.warningColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadProgressCard extends StatelessWidget {
  final _UploadRun run;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const _UploadProgressCard({
    required this.run,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final failed = run.failed.length;
    final done = run.finished;
    final accent = failed > 0 && done
        ? AppTheme.errorColor
        : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(context, radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            done
                ? 'อัปขึ้นแล้ว ${run.done} จาก ${run.total} รูป'
                : 'กำลังอัป ${run.done + failed} / ${run.total} รูป',
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: run.progress,
              minHeight: 6,
              color: accent,
              backgroundColor: AppTheme.border(context),
            ),
          ),
          if (failed > 0) ...[
            const SizedBox(height: 8),
            Text(
              'ไม่ขึ้น $failed รูป${run.lastError != null ? ' · ${run.lastError}' : ''}',
              style: appFont(
                fontSize: AppText.sizeLabel,
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (done && failed > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text('ลองใหม่ $failed รูป'),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: onDismiss, child: const Text('ข้ามไป')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String thumb;
  final int decodeWidth;
  final bool mine;
  final bool deleting;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _PhotoTile({
    required this.thumb,
    required this.decodeWidth,
    required this.mine,
    required this.deleting,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: onTap,
            child: CachedNetworkImage(
              imageUrl: thumb,
              fit: BoxFit.cover,
              // ตั้งแค่ความกว้าง — ใส่ทั้งกว้างและสูงจะบีบสัดส่วนรูปเพี้ยน
              memCacheWidth: decodeWidth,
              maxWidthDiskCache: decodeWidth,
              placeholder: (_, _) => Container(color: AppTheme.border(context)),
              errorWidget: (_, _, _) => Container(
                color: AppTheme.border(context),
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ),
          ),
          if (deleting)
            Container(
              color: Colors.black45,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else if (onDelete != null)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          if (mine)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'ของฉัน',
                  style: appFont(
                    fontSize: AppText.sizeMicro,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UploadBar extends StatelessWidget {
  final bool canUpload;
  final bool uploading;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  const _UploadBar({
    required this.canUpload,
    required this.uploading,
    required this.onGallery,
    required this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = canUpload && !uploading;

    // แถบล่างทึบ: เว้นขอบล่างไว้ข้างใน แทนการห่อ SafeArea ที่ทำให้แถบลอย
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(top: BorderSide(color: AppTheme.border(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: PrimaryCTAButton(
              label: uploading ? 'กำลังอัปรูป…' : 'เลือกรูปจากเครื่อง',
              icon: Icons.add_photo_alternate_outlined,
              loading: uploading,
              onPressed: enabled ? onGallery : null,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 54,
            height: 54,
            child: OutlinedButton(
              onPressed: enabled ? onCamera : null,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
              child: const Icon(Icons.photo_camera_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  final String url;
  final String uploader;
  final VoidCallback? onDelete;

  const _PhotoViewer({
    required this.url,
    required this.uploader,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeWidth = (MediaQuery.sizeOf(context).width * dpr).round();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: Text(
          uploader.isEmpty ? 'รูปทริป' : 'อัปโดย $uploader',
          style: appFont(
            fontSize: AppText.sizeSubtitle,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          if (onDelete != null)
            IconButton(
              tooltip: 'ลบรูป',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 4,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            memCacheWidth: decodeWidth,
            placeholder: (_, _) =>
                const CircularProgressIndicator(color: Colors.white),
            errorWidget: (_, _, _) =>
                const Icon(Icons.broken_image, size: 64, color: Colors.white54),
          ),
        ),
      ),
    );
  }
}
