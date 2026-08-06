import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snack.dart';
import '../widgets/empty_state_view.dart';

/// "ผู้ใช้ที่ถูกบล็อก" — ที่เดียวที่เลิกบล็อกได้
///
/// การบล็อกทำได้จากหลายที่ (แชท รีวิว ฟีด กำแพงรูป) แต่การเลิกบล็อกต้องมี
/// ที่อยู่ถาวรที่หาเจอ ไม่งั้นคนที่กดพลาดจะไม่มีทางย้อนกลับ เพราะเนื้อหาของ
/// คนที่บล็อกไปแล้วหายไปจากสายตาหมด
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>> _blocks = [];
  bool _loading = true;
  String? _error;
  int? _busyId;

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
      final blocks = await context.read<AppProvider>().blockedUsers();
      if (!mounted) return;
      setState(() {
        _blocks = blocks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _unblock(Map<String, dynamic> block) async {
    final userId = int.tryParse('${block['user_id']}');
    if (userId == null) return;

    final name = '${block['name'] ?? ''}'.trim();
    setState(() => _busyId = userId);
    try {
      await context.read<AppProvider>().unblockUser(userId);
      if (!mounted) return;
      setState(() {
        _blocks.removeWhere((b) => '${b['user_id']}' == '$userId');
        _busyId = null;
      });
      AppSnack.show(
        context,
        name.isEmpty ? 'เลิกบล็อกแล้ว' : 'เลิกบล็อก$nameแล้ว',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      AppSnack.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.background(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.onSurface(context)),
        title: Text(
          'ผู้ใช้ที่ถูกบล็อก',
          style: AppTheme.appBarTitleStyle(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 32),
        children: [
          EmptyStateView(
            icon: Icons.wifi_off_rounded,
            title: 'โหลดรายการไม่สำเร็จ',
            body: _error!,
            actionLabel: 'ลองใหม่',
            onAction: _load,
          ),
        ],
      );
    }

    if (_blocks.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 32),
        children: const [
          EmptyStateView(
            icon: Icons.block_rounded,
            title: 'ยังไม่ได้บล็อกใคร',
            body:
                'เมื่อคุณบล็อกใคร คุณจะไม่เห็นข้อความ รีวิว และโพสต์ของเขา '
                'และเขาก็จะไม่เห็นของคุณ รายชื่อจะมาแสดงที่นี่',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: _blocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final block = _blocks[index];
        final userId = int.tryParse('${block['user_id']}');
        final name = '${block['name'] ?? ''}'.trim();
        final avatarUrl = ApiConfig.mediaUrl(block['avatar_url']);
        final busy = _busyId != null && _busyId == userId;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: AppTheme.cardDecoration(context),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.subtleSurface(context),
                backgroundImage:
                    avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                        style: appFont(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.mutedText(context),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name.isEmpty ? 'ผู้ใช้' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeBody,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              TextButton(
                onPressed: busy ? null : () => _unblock(block),
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'เลิกบล็อก',
                        style: appFont(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
