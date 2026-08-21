import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack.dart';
import '../widgets/document_attach_field.dart';
import '../widgets/skeleton.dart';
import '../widgets/travel_widgets.dart';

/// เอกสารแนบของการจอง — ตามมาแนบทีหลังได้ที่นี่
///
/// ทริปที่แอดมินตั้งว่าต้องใช้เอกสาร (ใบรับรองแพทย์ บัตรดำน้ำ สำเนาบัตร ฯลฯ)
/// จะมีช่องแนบให้ตั้งแต่ตอนจอง แต่เอกสารจริงบางใบลูกค้ายังไม่มีในมือวันนั้น
/// หน้านี้คือทางกลับมาแนบ — และเป็นที่เดียวกับที่ใช้แก้ของที่แนบผิดไฟล์
///
/// อัปโหลดทันทีที่เลือกไฟล์ ไม่มีปุ่ม "บันทึก" — ไฟล์ที่เลือกแล้วแต่ยังไม่ส่ง
/// คือไฟล์ที่ลูกค้าคิดว่าส่งแล้ว
class BookingDocumentsScreen extends StatefulWidget {
  final String bookingRef;

  const BookingDocumentsScreen({super.key, required this.bookingRef});

  @override
  State<BookingDocumentsScreen> createState() => _BookingDocumentsScreenState();
}

class _BookingDocumentsScreenState extends State<BookingDocumentsScreen> {
  Map<String, dynamic> _data = const {};
  bool _loading = true;
  String? _error;

  /// ช่องที่กำลังส่งไฟล์อยู่ — คีย์เป็น "passengerId:requirementKey"
  final Set<String> _busy = <String>{};

  /// ไฟล์ที่กำลังถูกลบ (id ของ booking_document)
  int? _deleting;

  /// มีอะไรเปลี่ยนไปไหม — ใช้บอกหน้าใบจองว่าควรโหลดใหม่ตอนกดย้อนกลับ
  bool _changed = false;

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
      final data = await context.read<AppProvider>().bookingDocuments(
        widget.bookingRef,
      );
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload(int passengerId, String key, String path) async {
    final slot = '$passengerId:$key';
    setState(() => _busy.add(slot));
    try {
      final documents = await context.read<AppProvider>().uploadBookingDocument(
        ref: widget.bookingRef,
        passengerId: passengerId,
        requirementKey: key,
        filePath: path,
      );
      if (!mounted) return;
      setState(() {
        if (documents.isNotEmpty) _data = documents;
        _changed = true;
      });
      AppSnack.success(context, 'แนบเอกสารแล้ว');
    } on ApiException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'แนบเอกสารไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _busy.remove(slot));
    }
  }

  Future<void> _delete(Map<String, dynamic> file) async {
    final id = int.tryParse(textOf(file['id']));
    if (id == null || _deleting != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ลบเอกสารนี้?', style: appFont(fontWeight: FontWeight.w800)),
        content: Text(
          '${textOf(file['original_name'])}\nลบแล้วต้องแนบใหม่ครับ',
          style: appFont(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('ลบไฟล์'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = id);
    try {
      final documents = await context.read<AppProvider>().deleteBookingDocument(
        widget.bookingRef,
        id,
      );
      if (!mounted) return;
      setState(() {
        if (documents.isNotEmpty) _data = documents;
        _changed = true;
      });
    } catch (_) {
      if (mounted) AppSnack.error(context, 'ลบเอกสารไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _deleting = null);
    }
  }

  Future<void> _open(Map<String, dynamic> file) async {
    final uri = Uri.tryParse(textOf(file['url']));
    if (uri == null || uri.toString().isEmpty) return;
    // ลิงก์เป็น signed URL อายุสั้น — เปิดหน้านี้ค้างไว้นานแล้วกดเปิดอาจหมดอายุ
    // ดึงใหม่ให้ก่อนเสมอถูกกว่าอธิบายว่าทำไมลิงก์พัง
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final passengers = asList(_data['passengers']).map(asMap).toList();
    final requirements = asList(_data['requirements']);

    // ปัดกลับกับกดปุ่มย้อนต้องได้ผลเดียวกัน — คืน _changed ทั้งสองทาง ไม่งั้น
    // คนที่ปัดกลับจะเห็นใบจองเป็นข้อมูลเก่าโดยไม่รู้ว่าทำไม
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppTheme.background(context),
        appBar: AppBar(
          backgroundColor: AppTheme.background(context),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text('เอกสารแนบ', style: AppTheme.appBarTitleStyle(context)),
          iconTheme: IconThemeData(color: AppTheme.onSurface(context)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
        ),
        body: _loading && passengers.isEmpty
            ? const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: SkeletonDetail(showHero: false),
              )
            : _error != null
            ? _DocumentsErrorState(message: _error!, onRetry: _load)
            : requirements.isEmpty
            ? _EmptyRequirements()
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  children: [
                    _IntroCard(data: _data),
                    const SizedBox(height: 20),
                    ...passengers.map((passenger) {
                      final passengerId =
                          int.tryParse(textOf(passenger['passenger_id'])) ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _PassengerDocumentCard(
                          passenger: passenger,
                          busySlots: _busy,
                          deletingId: _deleting,
                          onPick: (key, path) =>
                              _upload(passengerId, key, path),
                          onOpen: _open,
                          onDelete: _delete,
                        ),
                      );
                    }),
                  ],
                ),
              ),
      ),
    );
  }
}

/// บอกว่าทริปนี้ขออะไรบ้าง และยังขาดใครอยู่ไหม
class _IntroCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _IntroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final hasMissing = data['has_missing'] == true;
    final accent = hasMissing ? AppTheme.warningColor : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: AppTheme.isDark(context) ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasMissing
                ? Icons.assignment_late_rounded
                : Icons.assignment_turned_in_rounded,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasMissing ? 'ยังขาดเอกสารอยู่' : 'เอกสารครบแล้ว',
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasMissing
                      ? 'ทริปนี้ต้องใช้เอกสารของผู้เดินทางทุกท่านครับ '
                            'ถ่ายรูปเอกสารหรือแนบไฟล์ PDF ก็ได้ '
                            'ยังไม่มีในมือตอนนี้ กลับมาแนบทีหลังได้'
                      : 'ทีมงานได้รับเอกสารของทุกท่านแล้วครับ '
                            'ถ้าแนบผิดไฟล์ ลบแล้วแนบใหม่ได้ที่นี่',
                  style: appFont(
                    fontSize: AppText.sizeCaption,
                    color: AppTheme.mutedText(context),
                    height: 1.6,
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

/// เอกสารของผู้เดินทางหนึ่งคน
class _PassengerDocumentCard extends StatelessWidget {
  final Map<String, dynamic> passenger;
  final Set<String> busySlots;
  final int? deletingId;
  final void Function(String key, String path) onPick;
  final void Function(Map<String, dynamic> file) onOpen;
  final void Function(Map<String, dynamic> file) onDelete;

  const _PassengerDocumentCard({
    required this.passenger,
    required this.busySlots,
    required this.deletingId,
    required this.onPick,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final passengerId = textOf(passenger['passenger_id']);
    final requirements = asList(passenger['requirements']).map(asMap).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context, radius: AppTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            textOf(passenger['name'], 'ผู้เดินทาง'),
            style: appFont(
              fontSize: AppText.sizeBody,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface(context),
            ),
          ),
          for (final requirement in requirements) ...[
            const SizedBox(height: 16),
            _RequirementBlock(
              requirement: requirement,
              busy: busySlots.contains(
                '$passengerId:${textOf(requirement['key'])}',
              ),
              deletingId: deletingId,
              onPick: (path) => onPick(textOf(requirement['key']), path),
              onOpen: onOpen,
              onDelete: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

/// ข้อกำหนดหนึ่งรายการ: ไฟล์ที่ส่งแล้ว (เปิดดู/ลบได้) + ปุ่มแนบเพิ่ม
class _RequirementBlock extends StatelessWidget {
  final Map<String, dynamic> requirement;
  final bool busy;
  final int? deletingId;
  final ValueChanged<String> onPick;
  final void Function(Map<String, dynamic> file) onOpen;
  final void Function(Map<String, dynamic> file) onDelete;

  const _RequirementBlock({
    required this.requirement,
    required this.busy,
    required this.deletingId,
    required this.onPick,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final files = asList(requirement['files']).map(asMap).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ไฟล์ที่ส่งขึ้นแล้ว — คนละเรื่องกับไฟล์ที่เพิ่งเลือก จึงวาดเองที่นี่
        // ไม่ผ่าน DocumentAttachField ซึ่งรู้จักแต่ชื่อไฟล์ในเครื่อง
        for (final file in files) ...[
          _UploadedFileRow(
            file: file,
            deleting: deletingId == int.tryParse(textOf(file['id'])),
            onOpen: () => onOpen(file),
            onDelete: () => onDelete(file),
          ),
          const SizedBox(height: 8),
        ],
        DocumentAttachField(
          requirement: requirement,
          // ไฟล์ที่ส่งแล้ววาดไว้ข้างบน ตรงนี้จึงส่งรายการเปล่าไป — แต่ยังต้องนับ
          // จำนวนให้ปุ่ม "แนบไฟล์" หายไปเมื่อครบโควตา
          fileNames: List.filled(files.length, ''),
          busy: busy,
          onPicked: onPick,
        ),
      ],
    );
  }
}

class _UploadedFileRow extends StatelessWidget {
  final Map<String, dynamic> file;
  final bool deleting;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _UploadedFileRow({
    required this.file,
    required this.deleting,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isImage = file['is_image'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border(context).withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Icon(
            isImage ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
            size: 18,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              textOf(file['original_name'], 'เอกสาร'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appFont(
                fontSize: AppText.sizeLabel,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface(context),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              onOpen();
            },
            visualDensity: VisualDensity.compact,
            tooltip: 'เปิดดู',
            icon: Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: AppTheme.mutedText(context),
            ),
          ),
          IconButton(
            onPressed: deleting ? null : onDelete,
            visualDensity: VisualDensity.compact,
            tooltip: 'ลบไฟล์นี้',
            icon: deleting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppTheme.mutedText(context),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRequirements extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'ทริปนี้ไม่ต้องแนบเอกสารเพิ่มครับ',
          textAlign: TextAlign.center,
          style: appFont(
            fontSize: AppText.sizeBody,
            color: AppTheme.mutedText(context),
          ),
        ),
      ),
    );
  }
}

class _DocumentsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DocumentsErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: AppTheme.mutedText(context),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: appFont(
                fontSize: AppText.sizeLabel,
                color: AppTheme.mutedText(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('ลองใหม่')),
          ],
        ),
      ),
    );
  }
}
