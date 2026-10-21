import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';

// สติกเกอร์ของแบรนด์ในห้องแชท — แอดมินอัปโหลดที่ /admin/stickers แอปดึงผ่าน
// GET chat/stickers แล้ววาดเป็นแผงแทนคีย์บอร์ด (แตะครั้งแรก = ดูตัวอย่าง
// แตะซ้ำ = ส่ง กันส่งพลาดแบบ LINE) และเสนอสติกเกอร์ให้ตอนพิมพ์คำที่ตรงป้าย
//
// ข้อความสติกเกอร์มี body สำรอง "[สติกเกอร์] ป้าย" จากเซิร์ฟเวอร์ (Sticker::BODY_PREFIX)
// แอปรุ่นเก่า เว็บ และ push จึงอ่านรู้เรื่องโดยไม่ต้องรู้จักสติกเกอร์

/// ตรงกับ Sticker::BODY_PREFIX ฝั่งเซิร์ฟเวอร์ — ใช้ตอนวาดข้อความที่ยังส่งไม่ถึง
const kStickerBodyPrefix = '[สติกเกอร์]';

class ChatSticker {
  final int id;
  final String label;
  final List<String> keywords;
  final String url;
  final bool isAnimated;

  const ChatSticker({
    required this.id,
    required this.label,
    required this.keywords,
    required this.url,
    this.isAnimated = false,
  });

  static ChatSticker? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final id = int.tryParse('${raw['id']}');
    final url = raw['url']?.toString() ?? '';
    if (id == null || url.isEmpty) return null;
    final label = raw['label']?.toString() ?? '';
    final keywords = (raw['keywords'] as List? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return ChatSticker(
      id: id,
      label: label,
      keywords: keywords.isEmpty && label.isNotEmpty ? [label] : keywords,
      url: url,
      isAnimated: raw['is_animated'] == true,
    );
  }

  /// รูปแบบเดียวกับ `sticker` ในข้อความจากเซิร์ฟเวอร์ — ใช้กับข้อความที่ยังส่งไม่ถึง
  Map<String, dynamic> toMessageJson() => {
        'id': id,
        'label': label,
        'url': url,
        'is_animated': isAnimated,
      };

  String get fallbackBody => '$kStickerBodyPrefix $label';
}

class ChatStickerPack {
  final int id;
  final String name;
  final List<ChatSticker> stickers;

  const ChatStickerPack({
    required this.id,
    required this.name,
    required this.stickers,
  });

  static List<ChatStickerPack> parseList(dynamic raw) {
    final out = <ChatStickerPack>[];
    for (final p in (raw is List ? raw : const [])) {
      if (p is! Map) continue;
      final stickers = (p['stickers'] as List? ?? const [])
          .map(ChatSticker.fromJson)
          .whereType<ChatSticker>()
          .toList();
      if (stickers.isEmpty) continue;
      out.add(
        ChatStickerPack(
          id: int.tryParse('${p['id']}') ?? 0,
          name: p['name']?.toString() ?? '',
          stickers: stickers,
        ),
      );
    }
    return out;
  }
}

/// คำลงท้ายที่ไม่เปลี่ยนความหมาย — "รับทราบครับ" ควรเจอสติกเกอร์ "รับทราบ"
final _trailingParticles = RegExp(
  r'(\s*(ครับผม|ครับ|คับ|ค้าบ|ค่ะ|คะ|ค่า|จ้า|จ้ะ|นะคะ|นะครับ|นะ|น้า|ๆ|[!?.~]+))+$',
);

String _normalize(String text) => text
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(_trailingParticles, '')
    .trim();

/// สติกเกอร์ที่ควรเสนอให้ข้อความที่กำลังพิมพ์ — ตรงทั้งคำมาก่อน แล้วขึ้นต้นด้วย
/// แล้วค่อย "มีคำนั้นอยู่ในประโยค" (เฉพาะคำยาว 3 ตัวขึ้นไป กัน "ok" ไปติดใน "book")
///
/// ข้อความยาวเกิน [maxLength] ตัวไม่เสนอเลย — คนที่พิมพ์ยาวขนาดนั้นกำลังเล่าเรื่อง
List<ChatSticker> matchStickers(
  List<ChatStickerPack> packs,
  String text, {
  int limit = 8,
  int maxLength = 24,
}) {
  final t = _normalize(text);
  if (t.isEmpty || t.characters.length > maxLength) return const [];

  final scored = <({ChatSticker sticker, int score, int order})>[];
  var order = 0;
  final seen = <int>{};

  for (final pack in packs) {
    for (final s in pack.stickers) {
      order++;
      if (!seen.add(s.id)) continue;
      var best = 0;
      for (final raw in s.keywords) {
        final k = _normalize(raw);
        if (k.isEmpty) continue;
        if (t == k) {
          best = 3;
          break;
        }
        if (t.characters.length >= 2 && k.startsWith(t)) {
          best = best < 2 ? 2 : best;
        } else if (k.characters.length >= 3 && t.contains(k)) {
          best = best < 1 ? 1 : best;
        }
      }
      if (best > 0) scored.add((sticker: s, score: best, order: order));
    }
  }

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.order.compareTo(b.order);
  });

  return scored.take(limit).map((e) => e.sticker).toList();
}

/// สติกเกอร์ที่ใช้ล่าสุด (เก็บในเครื่อง) — แท็บแรกของแผงสติกเกอร์
class StickerRecents {
  static const prefKey = 'chat_sticker_recent';
  static const max = 16;

  static Future<List<int>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(prefKey) ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// ดันตัวที่เพิ่งใช้ขึ้นหน้าสุด คืนรายการใหม่
  static List<int> bump(List<int> current, int id) =>
      [id, ...current.where((e) => e != id)].take(max).toList();

  static Future<void> save(List<int> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(prefKey, ids.map((e) => '$e').toList());
    } catch (_) {
      // จำไม่ได้ก็แค่แท็บ "ล่าสุด" ว่าง ไม่ต้องเตือนใคร
    }
  }
}

/// รูปสติกเกอร์ — ถอดรหัสภาพแค่ขนาดที่แสดงจริง (ไฟล์ต้นฉบับ 512px)
class ChatStickerImage extends StatelessWidget {
  final String url;
  final double size;
  final String? label;

  const ChatStickerImage({
    super.key,
    required this.url,
    required this.size,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();

    return SizedBox(
      width: size,
      height: size,
      child: CachedNetworkImage(
        imageUrl: ApiConfig.mediaUrl(url),
        fit: BoxFit.contain,
        memCacheWidth: cacheWidth,
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, _) => DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
        ),
        // รูปโหลดไม่ได้ (เน็ตบนดอย) — ยังเหลือป้ายให้อ่านว่าสื่ออะไร
        errorWidget: (_, _, _) => Center(
          child: Text(
            label?.isNotEmpty == true ? label! : 'สติกเกอร์',
            textAlign: TextAlign.center,
            style: appFont(
              fontSize: AppText.sizeLabel,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// แผงสติกเกอร์ที่ขึ้นแทนคีย์บอร์ด
class ChatStickerPanel extends StatefulWidget {
  final List<ChatStickerPack> packs;
  final List<int> recentIds;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<ChatSticker> onSend;
  final double height;

  const ChatStickerPanel({
    super.key,
    required this.packs,
    required this.recentIds,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onSend,
    this.height = 286,
  });

  @override
  State<ChatStickerPanel> createState() => _ChatStickerPanelState();
}

class _ChatStickerPanelState extends State<ChatStickerPanel> {
  /// -1 = แท็บ "ล่าสุด"
  int _tab = -1;
  ChatSticker? _selected;
  bool _tabChosen = false;

  List<ChatSticker> get _recent {
    final byId = <int, ChatSticker>{
      for (final p in widget.packs)
        for (final s in p.stickers) s.id: s,
    };
    return widget.recentIds
        .map((id) => byId[id])
        .whereType<ChatSticker>()
        .toList();
  }

  int get _effectiveTab {
    // ยังไม่เคยใช้สติกเกอร์ = แท็บล่าสุดว่าง เปิดชุดแรกให้เลย
    if (!_tabChosen && _tab == -1 && _recent.isEmpty && widget.packs.isNotEmpty) {
      return 0;
    }
    if (_tab >= widget.packs.length) return widget.packs.isEmpty ? -1 : 0;
    return _tab;
  }

  void _tap(ChatSticker s) {
    if (_selected?.id == s.id) {
      _send(s);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _selected = s);
  }

  void _send(ChatSticker s) {
    HapticFeedback.mediumImpact();
    setState(() => _selected = null);
    widget.onSend(s);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(top: BorderSide(color: AppTheme.border(context))),
      ),
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (widget.packs.isEmpty) {
      if (widget.loading) {
        return const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emoji_emotions_outlined,
                size: 32,
                color: AppTheme.mutedText(context),
              ),
              const SizedBox(height: 10),
              Text(
                widget.error != null
                    ? 'โหลดสติกเกอร์ไม่สำเร็จ'
                    : 'ยังไม่มีสติกเกอร์ให้ใช้',
                textAlign: TextAlign.center,
                style: appFont(
                  fontSize: AppText.sizeBody,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface(context),
                ),
              ),
              if (widget.error != null) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: widget.onRetry,
                  child: Text(
                    'ลองอีกครั้ง',
                    style: appFont(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final tab = _effectiveTab;
    final stickers = tab == -1 ? _recent : widget.packs[tab].stickers;

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            children: [
              _TabButton(
                selected: tab == -1,
                tooltip: 'ใช้ล่าสุด',
                onTap: () => setState(() {
                  _tab = -1;
                  _tabChosen = true;
                  _selected = null;
                }),
                child: Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: tab == -1
                      ? AppTheme.primaryColor
                      : AppTheme.mutedText(context),
                ),
              ),
              for (var i = 0; i < widget.packs.length; i++)
                _TabButton(
                  selected: tab == i,
                  tooltip: widget.packs[i].name,
                  onTap: () => setState(() {
                    _tab = i;
                    _tabChosen = true;
                    _selected = null;
                  }),
                  child: ChatStickerImage(
                    url: widget.packs[i].stickers.first.url,
                    size: 28,
                    label: widget.packs[i].name,
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: AppTheme.border(context)),
        Expanded(
          child: Stack(
            children: [
              if (stickers.isEmpty)
                Center(
                  child: Text(
                    'สติกเกอร์ที่คุณส่งจะมาอยู่ตรงนี้',
                    style: appFont(
                      fontSize: AppText.sizeLabel,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText(context),
                    ),
                  ),
                )
              else
                GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: stickers.length,
                  itemBuilder: (_, i) {
                    final s = stickers[i];
                    final selected = _selected?.id == s.id;
                    return Semantics(
                      button: true,
                      label: 'สติกเกอร์ ${s.label}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        onTap: () => _tap(s),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.primaryColor.withValues(alpha: 0.10)
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: LayoutBuilder(
                            builder: (_, c) => ChatStickerImage(
                              url: s.url,
                              size: c.biggest.shortestSide,
                              label: s.label,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              if (_selected != null)
                Positioned.fill(
                  child: _StickerPreview(
                    sticker: _selected!,
                    onSend: () => _send(_selected!),
                    onDismiss: () => setState(() => _selected = null),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  const _TabButton({
    required this.selected,
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusXs),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            width: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primaryColor.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusXs),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// ตัวอย่างสติกเกอร์ที่เลือก — แตะรูปหรือปุ่มส่งเพื่อส่ง แตะพื้นที่ว่างเพื่อยกเลิก
class _StickerPreview extends StatelessWidget {
  final ChatSticker sticker;
  final VoidCallback onSend;
  final VoidCallback onDismiss;

  const _StickerPreview({
    required this.sticker,
    required this.onSend,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: ColoredBox(
        color: AppTheme.surface(context).withValues(alpha: 0.94),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onSend,
                child: ChatStickerImage(
                  url: sticker.url,
                  size: 128,
                  label: sticker.label,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onSend,
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  'ส่ง',
                  style: appFont(fontWeight: FontWeight.w800),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// แถบเสนอสติกเกอร์เหนือช่องพิมพ์ เมื่อคำที่พิมพ์ตรงกับป้าย/คำค้นของสติกเกอร์
class StickerSuggestionBar extends StatelessWidget {
  final List<ChatSticker> stickers;
  final ValueChanged<ChatSticker> onPick;
  final VoidCallback onDismiss;

  const StickerSuggestionBar({
    super.key,
    required this.stickers,
    required this.onPick,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(top: BorderSide(color: AppTheme.border(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 7, 4, 7),
              itemCount: stickers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final s = stickers[i];
                return Semantics(
                  button: true,
                  label: 'ส่งสติกเกอร์ ${s.label}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onPick(s);
                    },
                    child: ChatStickerImage(
                      url: s.url,
                      size: 56,
                      label: s.label,
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
            tooltip: 'ไม่ใช้สติกเกอร์',
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: AppTheme.mutedText(context),
            ),
          ),
        ],
      ),
    );
  }
}
