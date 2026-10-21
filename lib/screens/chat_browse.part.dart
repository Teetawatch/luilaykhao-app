part of 'chat_screen.dart';

// ค้นหาข้อความ + คลังรูป/ลิงก์/ตำแหน่งของห้อง (ChatBrowseController)
//
// ทั้งสองหน้าคืน message_id ที่ผู้ใช้เลือก "ไปที่ข้อความ" กลับมาให้ห้องแชท
// ห้องจะโหลดย้อนไปถึงข้อความนั้นเอง (_jumpToMessage) ถ้ายังไม่ได้โหลด

String _browseTime(dynamic raw) {
  final at = _parseTime(raw);
  if (at == null) return '';
  final now = DateTime.now();
  final hm = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  if (at.year == now.year && at.month == now.month && at.day == now.day) return hm;
  return '${at.day}/${at.month} $hm';
}

class _ChatSearchScreen extends StatefulWidget {
  final int scheduleId;

  const _ChatSearchScreen({required this.scheduleId});

  @override
  State<_ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<_ChatSearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = const [];
  bool _loading = false;
  String? _error;
  String _searched = '';

  // คำค้นที่ยิงล่าสุด — ผลของคำเก่าที่กลับมาช้ากว่าไม่ทับผลของคำใหม่
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
    setState(() {});
  }

  Future<void> _search(String raw) async {
    final q = raw.trim();
    final seq = ++_seq;
    if (q.characters.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
        _searched = '';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<AppProvider>().searchChat(widget.scheduleId, q);
      if (!mounted || seq != _seq) return;
      setState(() {
        _results = items;
        _searched = q;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _error = 'ค้นหาไม่สำเร็จ ลองอีกครั้ง';
      });
    }
  }

  Future<void> _openMedia() async {
    HapticFeedback.selectionClick();
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => _ChatMediaScreen(scheduleId: widget.scheduleId)),
    );
    if (id != null && mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) {
            _debounce?.cancel();
            _search(v);
          },
          style: appFont(fontSize: AppText.sizeSubtitle, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'ค้นหาข้อความในห้องนี้',
            hintStyle: appFont(
              fontSize: AppText.sizeSubtitle,
              color: AppTheme.mutedText(context),
            ),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (q.isNotEmpty)
            IconButton(
              tooltip: 'ล้าง',
              onPressed: () {
                _query.clear();
                _search('');
              },
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: _body(context, q),
    );
  }

  Widget _body(BuildContext context, String q) {
    if (q.characters.length < 2) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              onTap: _openMedia,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.photo_library_rounded, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'รูป ลิงก์ และตำแหน่งในห้องนี้',
                            style: appFont(
                              fontSize: AppText.sizeBody,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface(context),
                            ),
                          ),
                          Text(
                            'ดูรวมทีเดียว ไม่ต้องเลื่อนหาในแชท',
                            style: appFont(
                              fontSize: AppText.sizeCaption,
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppTheme.mutedText(context)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'พิมพ์อย่างน้อย 2 ตัวอักษร เช่น เบอร์ จุดนัด เวลา ชื่อร้าน',
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: AppText.sizeLabel,
              color: AppTheme.mutedText(context),
            ),
          ),
        ],
      );
    }

    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (_error != null) {
      return Center(
        child: TextButton(
          onPressed: () => _search(_query.text),
          child: Text(_error!, style: appFont(fontWeight: FontWeight.w700)),
        ),
      );
    }
    if (_results.isEmpty && _searched.isNotEmpty) {
      return Center(
        child: Text(
          'ไม่พบ “$_searched” ในห้องนี้',
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w600,
            color: AppTheme.mutedText(context),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: AppTheme.border(context)),
      itemBuilder: (_, i) {
        final r = _results[i];
        return ListTile(
          onTap: () {
            final id = int.tryParse('${r['message_id']}');
            if (id != null) Navigator.of(context).pop(id);
          },
          title: Row(
            children: [
              Expanded(
                child: Text(
                  r['sender_name']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    fontSize: AppText.sizeLabel,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface(context),
                  ),
                ),
              ),
              Text(
                _browseTime(r['created_at']),
                style: appFont(
                  fontSize: AppText.sizeCaption,
                  color: AppTheme.mutedText(context),
                ),
              ),
            ],
          ),
          subtitle: _Highlighted(
            text: r['excerpt']?.toString() ?? '',
            query: _searched,
          ),
        );
      },
    );
  }
}

/// ข้อความที่ระบายสีคำที่ค้น (ไม่สนตัวพิมพ์เล็กใหญ่)
class _Highlighted extends StatelessWidget {
  final String text;
  final String query;

  const _Highlighted({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    final base = appFont(
      fontSize: AppText.sizeBody,
      height: 1.4,
      color: AppTheme.onSurface(context).withValues(alpha: 0.85),
    );
    if (query.isEmpty) return Text(text, style: base, maxLines: 3, overflow: TextOverflow.ellipsis);

    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    final needle = query.toLowerCase();
    var start = 0;
    while (true) {
      final at = lower.indexOf(needle, start);
      if (at < 0) break;
      if (at > start) spans.add(TextSpan(text: text.substring(start, at)));
      spans.add(TextSpan(
        text: text.substring(at, at + needle.length),
        style: base.copyWith(
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryColor,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.10),
        ),
      ));
      start = at + needle.length;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));

    return Text.rich(
      TextSpan(children: spans, style: base),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ChatMediaScreen extends StatefulWidget {
  final int scheduleId;

  const _ChatMediaScreen({required this.scheduleId});

  @override
  State<_ChatMediaScreen> createState() => _ChatMediaScreenState();
}

class _MediaPage {
  final List<Map<String, dynamic>> items = [];
  int? nextBeforeId;
  bool loading = false;
  bool loaded = false;
  String? error;

  bool get hasMore => !loaded || nextBeforeId != null;
}

class _ChatMediaScreenState extends State<_ChatMediaScreen> {
  final _pages = {'images': _MediaPage(), 'links': _MediaPage()};

  @override
  void initState() {
    super.initState();
    _load('images');
    _load('links');
  }

  Future<void> _load(String type) async {
    final page = _pages[type]!;
    if (page.loading || (page.loaded && page.nextBeforeId == null)) return;
    setState(() {
      page.loading = true;
      page.error = null;
    });
    try {
      final res = await context.read<AppProvider>().chatMedia(
        widget.scheduleId,
        type,
        beforeId: page.nextBeforeId,
      );
      if (!mounted) return;
      setState(() {
        page.items.addAll(
          (res['items'] as List? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e)),
        );
        page.nextBeforeId = int.tryParse('${res['next_before_id']}');
        page.loaded = true;
        page.loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        page.loading = false;
        page.error = 'โหลดไม่สำเร็จ';
      });
    }
  }

  bool _onScroll(String type, ScrollNotification n) {
    if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) _load(type);
    return false;
  }

  void _goTo(dynamic id) {
    final messageId = int.tryParse('$id');
    if (messageId != null) Navigator.of(context).pop(messageId);
  }

  Future<void> _openLink(String url) async {
    HapticFeedback.selectionClick();
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) AppSnack.error(context, 'เปิดลิงก์ไม่ได้');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background(context),
        appBar: AppBar(
          title: Text(
            'รูปและลิงก์ในห้อง',
            style: appFont(fontSize: AppTheme.appBarTitleSize, fontWeight: FontWeight.w800),
          ),
          bottom: TabBar(
            labelStyle: appFont(fontWeight: FontWeight.w800),
            unselectedLabelStyle: appFont(fontWeight: FontWeight.w600),
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            tabs: const [
              Tab(text: 'รูปภาพ'),
              Tab(text: 'ลิงก์และตำแหน่ง'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_images(context), _links(context)],
        ),
      ),
    );
  }

  Widget _state(BuildContext context, _MediaPage page, String empty, String type) {
    if (!page.loaded && page.loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (!page.loaded && page.error != null) {
      return Center(
        child: TextButton(onPressed: () => _load(type), child: Text('${page.error} · ลองอีกครั้ง')),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          empty,
          textAlign: TextAlign.center,
          style: appFont(
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w600,
            color: AppTheme.mutedText(context),
          ),
        ),
      ),
    );
  }

  Widget _images(BuildContext context) {
    final page = _pages['images']!;
    if (page.items.isEmpty) {
      return _state(context, page, 'ยังไม่มีใครส่งรูปในห้องนี้', 'images');
    }
    final cache = (MediaQuery.sizeOf(context).width / 3 * MediaQuery.devicePixelRatioOf(context)).round();

    return NotificationListener<ScrollNotification>(
      onNotification: (n) => _onScroll('images', n),
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: page.items.length,
        itemBuilder: (_, i) {
          final item = page.items[i];
          final url = ApiConfig.mediaUrl(item['image_url']);
          return GestureDetector(
            onTap: () async {
              final go = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => _ImageViewer(
                    url: url,
                    title: item['sender_name']?.toString(),
                    onGoToMessage: true,
                  ),
                ),
              );
              if (go == true) _goTo(item['message_id']);
            },
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: cache,
              placeholder: (_, _) => ColoredBox(color: AppTheme.subtleSurface(context)),
              errorWidget: (_, _, _) => ColoredBox(
                color: AppTheme.subtleSurface(context),
                child: Icon(Icons.broken_image_rounded, color: AppTheme.mutedText(context)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _links(BuildContext context) {
    final page = _pages['links']!;
    if (page.items.isEmpty) {
      return _state(context, page, 'ยังไม่มีลิงก์หรือตำแหน่งที่แชร์ในห้องนี้', 'links');
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) => _onScroll('links', n),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: page.items.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: AppTheme.border(context)),
        itemBuilder: (_, i) {
          final item = page.items[i];
          final isLocation = item['kind'] == 'location';
          return ListTile(
            onTap: () => _openLink(item['url']?.toString() ?? ''),
            leading: CircleAvatar(
              backgroundColor: (isLocation ? AppTheme.errorColor : AppTheme.primaryColor)
                  .withValues(alpha: 0.10),
              child: Icon(
                isLocation ? Icons.location_on_rounded : Icons.link_rounded,
                color: isLocation ? AppTheme.errorColor : AppTheme.primaryColor,
              ),
            ),
            title: Text(
              item['title']?.toString() ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: appFont(fontSize: AppText.sizeBody, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              [
                if (!isLocation) item['host']?.toString() ?? '',
                item['sender_name']?.toString() ?? '',
                _browseTime(item['created_at']),
              ].where((e) => e.isNotEmpty).join(' · '),
              style: appFont(fontSize: AppText.sizeCaption, color: AppTheme.mutedText(context)),
            ),
            trailing: IconButton(
              tooltip: 'ไปที่ข้อความ',
              onPressed: () => _goTo(item['message_id']),
              icon: Icon(Icons.forum_outlined, color: AppTheme.mutedText(context)),
            ),
          );
        },
      ),
    );
  }
}
