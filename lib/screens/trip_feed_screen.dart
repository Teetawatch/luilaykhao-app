import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/travel_widgets.dart';
import '../widgets/tier_badge.dart';

/// ฟีดรูปหลังทริป (community feed) — โพสต์สาธารณะจากลูกค้าที่เดินทางจริง
/// ใช้ได้ 2 โหมด: ฟีดรวมทุกทริป (slug == null) และฟีดของทริปเดียว
class TripFeedScreen extends StatefulWidget {
  final String? slug;
  final String? tripTitle;

  const TripFeedScreen({super.key, this.slug, this.tripTitle});

  @override
  State<TripFeedScreen> createState() => _TripFeedScreenState();
}

class _TripFeedScreenState extends State<TripFeedScreen> {
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _canPost = false;
  int _page = 1;
  int _lastPage = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _posts.isEmpty;
      _error = null;
    });
    try {
      final response = await context.read<AppProvider>().tripPosts(
        slug: widget.slug,
      );
      if (!mounted) return;
      final meta = asMap(response['meta']);
      setState(() {
        _posts
          ..clear()
          ..addAll(asList(response['data']).map(asMap));
        _page = int.tryParse(textOf(meta['current_page'])) ?? 1;
        _lastPage = int.tryParse(textOf(meta['last_page'])) ?? 1;
        _canPost = meta['can_post'] == true;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _maybeLoadMore() {
    if (_loadingMore || _loading || _page >= _lastPage) return;
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 400) {
      return;
    }
    _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final response = await context.read<AppProvider>().tripPosts(
        slug: widget.slug,
        page: _page + 1,
      );
      if (!mounted) return;
      final meta = asMap(response['meta']);
      setState(() {
        _posts.addAll(asList(response['data']).map(asMap));
        _page = int.tryParse(textOf(meta['current_page'])) ?? _page + 1;
        _lastPage = int.tryParse(textOf(meta['last_page'])) ?? _lastPage;
      });
    } catch (_) {
      // เลื่อนถึงล่างแล้วโหลดไม่ได้ — ปล่อยให้ลองใหม่รอบถัดไป
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openComposer() async {
    final slug = widget.slug;
    if (slug == null) return;
    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TripPostComposerScreen(
          slug: slug,
          tripTitle: widget.tripTitle ?? 'ทริปนี้',
        ),
      ),
    );
    if (posted == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.slug == null
        ? 'ฟีดนักเดินทาง'
        : 'ฟีดทริป ${widget.tripTitle ?? ''}'.trim();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        title: Text(
          title,
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      floatingActionButton: _canPost
          ? FloatingActionButton.extended(
              onPressed: _openComposer,
              icon: const Icon(Icons.add_a_photo_rounded),
              label: Text(
                'โพสต์รูป',
                style: appFont(fontWeight: FontWeight.w800),
              ),
            )
          : null,
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _posts.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          EmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'โหลดฟีดไม่สำเร็จ',
            body: _error!,
          ),
        ],
      );
    }
    if (_posts.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          EmptyState(
            icon: Icons.photo_camera_back_rounded,
            title: 'ยังไม่มีโพสต์ในฟีด',
            body: 'กลับจากทริปแล้วมาแชร์รูปสวย ๆ เป็นคนแรกกันเลย!',
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: _posts.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _posts.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _TripPostCard(
          post: _posts[index],
          showTripName: widget.slug == null,
          onChanged: (updated) {
            if (updated == null) {
              setState(() => _posts.removeAt(index));
            } else {
              setState(() => _posts[index] = updated);
            }
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post card
// ─────────────────────────────────────────────────────────────────────────────

class _TripPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool showTripName;

  /// เรียกเมื่อโพสต์เปลี่ยน (ไลก์/คอมเมนต์/ลบ) — null = โพสต์ถูกลบ
  final ValueChanged<Map<String, dynamic>?> onChanged;

  const _TripPostCard({
    required this.post,
    required this.showTripName,
    required this.onChanged,
  });

  @override
  State<_TripPostCard> createState() => _TripPostCardState();
}

class _TripPostCardState extends State<_TripPostCard> {
  int _photoIndex = 0;
  bool _liking = false;

  Map<String, dynamic> get post => widget.post;

  Future<void> _toggleLike() async {
    final app = context.read<AppProvider>();
    if (!app.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เข้าสู่ระบบเพื่อกดถูกใจโพสต์')),
      );
      return;
    }
    if (_liking) return;
    setState(() => _liking = true);
    HapticFeedback.selectionClick();
    try {
      final id = int.tryParse(textOf(post['id'])) ?? 0;
      final result = await app.likeTripPost(id);
      final updated = Map<String, dynamic>.from(post);
      updated['liked_by_me'] = result['liked'] == true;
      updated['likes_count'] = result['likes_count'];
      widget.onChanged(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  void _openComments() {
    final id = int.tryParse(textOf(post['id'])) ?? 0;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _CommentsSheet(
        postId: id,
        onCountChanged: (count) {
          final updated = Map<String, dynamic>.from(post);
          updated['comments_count'] = count;
          widget.onChanged(updated);
        },
      ),
    );
  }

  Future<void> _showMenu() async {
    final isMine = post['is_mine'] == true;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red),
                title: Text('ลบโพสต์ของฉัน',
                    style: appFont(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              )
            else
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text('รายงานโพสต์ไม่เหมาะสม',
                    style: appFont(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'delete') await _delete();
    if (action == 'report') await _report();
  }

  Future<void> _delete() async {
    final id = int.tryParse(textOf(post['id'])) ?? 0;
    try {
      await context.read<AppProvider>().deleteTripPost(id);
      widget.onChanged(null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _report() async {
    final app = context.read<AppProvider>();
    if (!app.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เข้าสู่ระบบเพื่อรายงานโพสต์')),
      );
      return;
    }
    final id = int.tryParse(textOf(post['id'])) ?? 0;
    try {
      await app.reportTripPost(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ขอบคุณสำหรับการรายงาน ทีมงานจะตรวจสอบโดยเร็ว'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = asMap(post['user']);
    final tierBadge = TierBadge.fromUser(user, compact: true);
    final trip = asMap(post['trip']);
    final photos = asList(post['photos']).map(asMap).toList();
    final caption = textOf(post['caption']);
    final liked = post['liked_by_me'] == true;
    final likesCount = int.tryParse(textOf(post['likes_count'])) ?? 0;
    final commentsCount = int.tryParse(textOf(post['comments_count'])) ?? 0;
    final avatarUrl = textOf(user['avatar_url']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: ผู้โพสต์ + เวลา + เมนู
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.10),
                  backgroundImage: avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: avatarUrl.isEmpty
                      ? const Icon(Icons.person_rounded,
                          color: AppTheme.primaryColor, size: 19)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              textOf(user['name'], 'นักเดินทาง'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appFont(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: AppTheme.onSurface(context),
                              ),
                            ),
                          ),
                          if (tierBadge != null) ...[
                            const SizedBox(width: 6),
                            tierBadge,
                          ],
                        ],
                      ),
                      Text(
                        widget.showTripName &&
                                textOf(trip['title']).isNotEmpty
                            ? '${textOf(trip['title'])} · ${_timeAgo(post['created_at'])}'
                            : _timeAgo(post['created_at']),
                        style: appFont(
                          fontSize: 11.5,
                          color: AppTheme.mutedText(context),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_horiz_rounded,
                      color: AppTheme.mutedText(context)),
                  onPressed: _showMenu,
                ),
              ],
            ),
          ),

          // Photo carousel
          if (photos.isNotEmpty)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _photoIndex = i),
                    itemBuilder: (_, i) => CachedNetworkImage(
                      imageUrl: textOf(photos[i]['url']),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, _) => Container(
                        color: AppTheme.subtleSurface(context),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: AppTheme.subtleSurface(context),
                        child: Icon(Icons.broken_image_rounded,
                            color: AppTheme.mutedText(context)),
                      ),
                    ),
                  ),
                  if (photos.length > 1)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          photos.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _photoIndex ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _photoIndex
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Actions: like + comment
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _liking ? null : _toggleLike,
                  icon: Icon(
                    liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 21,
                    color: liked
                        ? const Color(0xFFE11D48)
                        : AppTheme.mutedText(context),
                  ),
                  label: Text(
                    likesCount > 0 ? '$likesCount' : 'ถูกใจ',
                    style: appFont(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: liked
                          ? const Color(0xFFE11D48)
                          : AppTheme.mutedText(context),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _openComments,
                  icon: Icon(Icons.mode_comment_outlined,
                      size: 19, color: AppTheme.mutedText(context)),
                  label: Text(
                    commentsCount > 0 ? '$commentsCount' : 'คอมเมนต์',
                    style: appFont(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Caption
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
              child: Text(
                caption,
                style: appFont(
                  fontSize: 13.5,
                  height: 1.5,
                  color: AppTheme.onSurface(context),
                ),
              ),
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comments bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final int postId;
  final ValueChanged<int> onCountChanged;

  const _CommentsSheet({required this.postId, required this.onCountChanged});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await context.read<AppProvider>().tripPostComments(
        widget.postId,
      );
      if (!mounted) return;
      setState(() {
        _comments = asList(response['data']).map(asMap).toList();
        _total = int.tryParse(textOf(asMap(response['meta'])['total'])) ??
            _comments.length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final app = context.read<AppProvider>();
    if (!app.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เข้าสู่ระบบเพื่อคอมเมนต์')),
      );
      return;
    }
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final comment = await app.addTripPostComment(widget.postId, body);
      if (!mounted) return;
      setState(() {
        _comments.add(Map<String, dynamic>.from(comment));
        _total += 1;
        _controller.clear();
      });
      widget.onCountChanged(_total);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> comment) async {
    final id = int.tryParse(textOf(comment['id'])) ?? 0;
    try {
      await context.read<AppProvider>().deleteTripPostComment(
        widget.postId,
        id,
      );
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => textOf(c['id']) == textOf(comment['id']));
        _total = _total > 0 ? _total - 1 : 0;
      });
      widget.onCountChanged(_total);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Column(
          children: [
            Text(
              'คอมเมนต์',
              style: appFont(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface(context),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? const Center(
                          child: EmptyState(
                            icon: Icons.mode_comment_outlined,
                            title: 'ยังไม่มีคอมเมนต์',
                            body: 'เป็นคนแรกที่คอมเมนต์โพสต์นี้เลย',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          itemCount: _comments.length,
                          itemBuilder: (_, i) {
                            final c = _comments[i];
                            final user = asMap(c['user']);
                            final avatarUrl = textOf(user['avatar_url']);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 15,
                                    backgroundColor: AppTheme.primaryColor
                                        .withValues(alpha: 0.10),
                                    backgroundImage: avatarUrl.isNotEmpty
                                        ? CachedNetworkImageProvider(avatarUrl)
                                        : null,
                                    child: avatarUrl.isEmpty
                                        ? const Icon(Icons.person_rounded,
                                            color: AppTheme.primaryColor,
                                            size: 16)
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${textOf(user['name'], 'นักเดินทาง')} · ${_timeAgo(c['created_at'])}',
                                          style: appFont(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                AppTheme.mutedText(context),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          textOf(c['body']),
                                          style: appFont(
                                            fontSize: 13.5,
                                            height: 1.45,
                                            color:
                                                AppTheme.onSurface(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (c['can_delete'] == true)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(Icons.close_rounded,
                                          size: 16,
                                          color: AppTheme.mutedText(context)),
                                      onPressed: () => _delete(c),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: 'เขียนคอมเมนต์…',
                          counterText: '',
                          isDense: true,
                          filled: true,
                          fillColor: AppTheme.subtleSurface(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, size: 19),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Composer — โพสต์รูปใหม่
// ─────────────────────────────────────────────────────────────────────────────

class TripPostComposerScreen extends StatefulWidget {
  final String slug;
  final String tripTitle;

  const TripPostComposerScreen({
    super.key,
    required this.slug,
    required this.tripTitle,
  });

  @override
  State<TripPostComposerScreen> createState() => _TripPostComposerScreenState();
}

class _TripPostComposerScreenState extends State<TripPostComposerScreen> {
  static const _maxPhotos = 6;

  final _captionController = TextEditingController();
  final List<XFile> _images = [];
  bool _posting = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final picked = await ImagePicker().pickMultiImage(
        imageQuality: 85,
        maxWidth: 1800,
        limit: _maxPhotos,
      );
      if (picked.isEmpty || !mounted) return;
      setState(() {
        _images
          ..addAll(picked)
          ..removeRange(
            _images.length > _maxPhotos ? _maxPhotos : _images.length,
            _images.length,
          );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เลือกรูปไม่สำเร็จ: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เลือกรูปอย่างน้อย 1 รูปก่อนโพสต์')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _posting = true);
    try {
      final caption = _captionController.text.trim();
      await context.read<AppProvider>().createTripPost(
        widget.slug,
        imagePaths: _images.map((f) => f.path).toList(),
        caption: caption.isEmpty ? null : caption,
      );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('โพสต์รูปขึ้นฟีดแล้ว 🎉')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _posting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        title: Text(
          'แชร์รูปทริป',
          style: appFont(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.tripTitle,
            style: appFont(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 12),

          // Photo grid + ปุ่มเพิ่มรูป
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              ..._images.map(
                (image) => ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(image.path), fit: BoxFit.cover),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.remove(image)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_images.length < _maxPhotos)
                GestureDetector(
                  onTap: _posting ? null : _pickImages,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.subtleSurface(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.border(context),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_rounded,
                            size: 28, color: AppTheme.mutedText(context)),
                        const SizedBox(height: 4),
                        Text(
                          'เพิ่มรูป',
                          style: appFont(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.mutedText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'สูงสุด $_maxPhotos รูป',
            style: appFont(
              fontSize: 11.5,
              color: AppTheme.mutedText(context),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _captionController,
            maxLines: 4,
            maxLength: 1000,
            decoration: InputDecoration(
              hintText: 'เล่าความประทับใจของทริปนี้… (ไม่บังคับ)',
              filled: true,
              fillColor: AppTheme.surface(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: _posting ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: _posting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _posting ? 'กำลังโพสต์…' : 'โพสต์ขึ้นฟีด',
              style: appFont(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'โพสต์ของคุณจะแสดงในฟีดสาธารณะของทริปนี้ '
            'ทีมงานอาจซ่อนโพสต์ที่ไม่เหมาะสมตามการรายงานของผู้ใช้',
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: 11.5,
              height: 1.5,
              color: AppTheme.mutedText(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _timeAgo(dynamic value) {
  final raw = textOf(value);
  if (raw.isEmpty) return '';
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;

  final diff = DateTime.now().difference(date.toLocal());
  if (diff.inMinutes < 1) return 'เมื่อกี้';
  if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
  if (diff.inHours < 24) return '${diff.inHours} ชม.ที่แล้ว';
  if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
  return dateText(raw);
}
