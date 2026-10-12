import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../theme/app_theme.dart';

// ข้อความเสียงในห้องแชท — อัด (แตะไมค์ → แถบกำลังอัด → ส่ง/ทิ้ง) และเล่น (บับเบิล
// มีปุ่มเล่น แถบความคืบหน้า และเวลา) ใช้ทั้งห้องแชทกลุ่มและห้องถามทีมงานส่วนตัว
//
// ไฟล์เป็น AAC ในกล่อง .m4a — เซิร์ฟเวอร์รับตาม ChatMessage::AUDIO_EXTENSIONS และ
// ตัดสั้นกว่า AUDIO_MIN_MS / ยาวกว่า AUDIO_MAX_SECONDS ทิ้ง ค่าสองตัวนี้ต้องตรงกัน

/// อัดได้ยาวสุดเท่านี้ ครบแล้วหยุดและส่งเอง — ตรงกับ ChatMessage::AUDIO_MAX_SECONDS
const kVoiceMaxDuration = Duration(seconds: 120);

/// สั้นกว่านี้ถือว่าแตะพลาด ไม่ส่ง (เซิร์ฟเวอร์รับขั้นต่ำ 500ms)
const kVoiceMinDuration = Duration(milliseconds: 800);

/// "0:07" / "1:12"
String formatVoiceDuration(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

/// ไฟล์เสียงที่อัดเสร็จแล้ว พร้อมส่ง
class VoiceClip {
  final String path;
  final int durationMs;

  const VoiceClip({required this.path, required this.durationMs});
}

/// ตัวอัดเสียง — แยกเป็น interface ให้เทสสลับใส่ตัวปลอมได้ (ปลั๊กอินไม่มีในเทส)
abstract class VoiceRecorder {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();

  /// ตัวสร้างที่แอปใช้จริง — เทสแทนที่ได้
  static VoiceRecorder Function() factory = RecordVoiceRecorder.new;
}

class RecordVoiceRecorder implements VoiceRecorder {
  final _recorder = AudioRecorder();

  // เสียงพูดโมโน 64kbps — 2 นาทีราว 1 MB ส่งผ่านเน็ตมือถือบนดอยไหว
  static const _config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 64000,
    sampleRate: 44100,
    numChannels: 1,
  );

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(_config, path: path);

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();
}

enum VoiceStartResult { started, denied, failed }

/// สถานะการอัดของช่องพิมพ์หนึ่งช่อง — นับเวลา, หยุดเองเมื่อครบเวลา, ทิ้งไฟล์ที่สั้นเกิน
class VoiceRecordingController extends ChangeNotifier {
  VoiceRecordingController({
    Future<String> Function()? newPath,
    DateTime Function()? clock,
  }) : _newPath = newPath ?? _defaultPath,
       _clock = clock ?? DateTime.now;

  final Future<String> Function() _newPath;

  /// นาฬิกาที่ใช้นับความยาว — เทสใส่นาฬิกาปลอมเพื่อเดินเวลาเอง
  final DateTime Function() _clock;
  VoiceRecorder? _recorder;
  DateTime? _startedAt;
  Timer? _ticker;
  bool _busy = false;
  bool _disposed = false;

  /// ครบ [kVoiceMaxDuration] แล้วหยุดเอง — ช่องพิมพ์ส่งคลิปนี้ต่อ
  ValueChanged<VoiceClip>? onAutoStop;

  bool get isRecording => _recorder != null;
  Duration get elapsed {
    final started = _startedAt;
    return started == null ? Duration.zero : _clock().difference(started);
  }

  static Future<String> _defaultPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/voice-${DateTime.now().microsecondsSinceEpoch}.m4a';
  }

  Future<VoiceStartResult> start() async {
    if (_busy || isRecording) return VoiceStartResult.failed;
    _busy = true;
    final recorder = VoiceRecorder.factory();
    try {
      if (!await recorder.hasPermission()) {
        await recorder.dispose();
        return VoiceStartResult.denied;
      }
      await recorder.start(await _newPath());
      if (_disposed) {
        await recorder.cancel();
        await recorder.dispose();
        return VoiceStartResult.failed;
      }
      _recorder = recorder;
      _startedAt = _clock();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (elapsed >= kVoiceMaxDuration) {
          _autoStop();
        } else {
          notifyListeners();
        }
      });
      notifyListeners();
      return VoiceStartResult.started;
    } catch (e) {
      debugPrint('[Voice] start failed: $e');
      try {
        await recorder.dispose();
      } catch (_) {}
      return VoiceStartResult.failed;
    } finally {
      _busy = false;
    }
  }

  Future<void> _autoStop() async {
    final clip = await stop();
    if (clip != null) onAutoStop?.call(clip);
  }

  /// หยุดแล้วคืนคลิป — สั้นเกินไป (แตะพลาด) คืน null และลบไฟล์ทิ้ง
  Future<VoiceClip?> stop() async {
    final recorder = _recorder;
    if (recorder == null) return null;
    final duration = elapsed;
    _reset();
    try {
      final path = await recorder.stop();
      if (path == null || path.isEmpty) return null;
      if (duration < kVoiceMinDuration) {
        _deleteQuietly(path);
        return null;
      }
      return VoiceClip(
        path: path,
        durationMs: duration > kVoiceMaxDuration
            ? kVoiceMaxDuration.inMilliseconds
            : duration.inMilliseconds,
      );
    } catch (e) {
      debugPrint('[Voice] stop failed: $e');
      return null;
    } finally {
      unawaited(recorder.dispose().catchError((_) {}));
    }
  }

  /// ทิ้งการอัดนี้ (ปลั๊กอินลบไฟล์ให้)
  Future<void> cancel() async {
    final recorder = _recorder;
    if (recorder == null) return;
    _reset();
    try {
      await recorder.cancel();
    } catch (_) {
      // ไม่มีอะไรให้ทำต่อ — ไฟล์ชั่วคราวระบบล้างเอง
    } finally {
      unawaited(recorder.dispose().catchError((_) {}));
    }
  }

  void _reset() {
    _ticker?.cancel();
    _ticker = null;
    _startedAt = null;
    _recorder = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(cancel());
    _ticker?.cancel();
    super.dispose();
  }
}

void _deleteQuietly(String path) {
  try {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  } catch (_) {}
}

/// ลบไฟล์เสียงชั่วคราวหลังส่งสำเร็จ
void deleteVoiceClip(String? path) {
  if (path == null || path.isEmpty) return;
  _deleteQuietly(path);
}

/// แถบแทนช่องพิมพ์ระหว่างอัด — ทิ้ง · เวลา · ส่ง
class ChatVoiceRecordingBar extends StatelessWidget {
  final VoiceRecordingController controller;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  const ChatVoiceRecordingBar({
    super.key,
    required this.controller,
    required this.onCancel,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final elapsed = controller.elapsed;
        final left = kVoiceMaxDuration - elapsed;
        final nearEnd = left <= const Duration(seconds: 10);
        return Row(
          children: [
            IconButton(
              tooltip: 'ทิ้งข้อความเสียง',
              onPressed: onCancel,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 26,
                color: AppTheme.errorColor,
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.subtleSurface(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Row(
                  children: [
                    const _RecordingDot(),
                    const SizedBox(width: 10),
                    Text(
                      formatVoiceDuration(elapsed),
                      style: appFont(
                        fontSize: AppText.sizeSubtitle,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface(context),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        nearEnd
                            ? 'อีก ${left.inSeconds < 0 ? 0 : left.inSeconds} วินาทีส่งเอง'
                            : 'กำลังอัดเสียง…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          fontSize: AppText.sizeLabel,
                          fontWeight: FontWeight.w600,
                          color: nearEnd
                              ? AppTheme.errorColor
                              : AppTheme.mutedText(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppTheme.primaryColor,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onSend,
                child: const Padding(
                  padding: EdgeInsets.all(11),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 20,
                    semanticLabel: 'ส่งข้อความเสียง',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// จุดแดงกะพริบระหว่างอัด
class _RecordingDot extends StatefulWidget {
  const _RecordingDot();

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_blink),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppTheme.errorColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// ปุ่มไมค์ในช่องพิมพ์ (ขึ้นแทนปุ่มส่งตอนยังไม่ได้พิมพ์อะไร)
class ChatVoiceMicButton extends StatelessWidget {
  final VoidCallback? onTap;

  const ChatVoiceMicButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(11),
          child: Icon(
            Icons.mic_rounded,
            color: Colors.white,
            size: 20,
            semanticLabel: 'อัดข้อความเสียง',
          ),
        ),
      ),
    );
  }
}

// ── การเล่น ──────────────────────────────────────────────────────────────

/// ตัวเล่นตัวเดียวทั้งแอป — กดเล่นข้อความใหม่ ข้อความเดิมหยุดเอง (แบบ LINE)
class ChatVoicePlayback extends ChangeNotifier {
  ChatVoicePlayback._();

  static final instance = ChatVoicePlayback._();

  // เสียงพูดผ่านลำโพง และเล่นได้แม้เปิดโหมดเงียบ — ผู้ใช้กดเล่นเองทุกครั้ง
  static final _context = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
  );

  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subs = [];
  String? _key;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _playing = false;
  bool _loading = false;

  String? get currentKey => _key;
  Duration get position => _position;
  Duration? get duration => _duration;
  bool isPlaying(String key) => _key == key && _playing;
  bool isLoading(String key) => _key == key && _loading;

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer(playerId: 'chat_voice');
    _subs
      ..add(
        player.onPositionChanged.listen((p) {
          _position = p;
          notifyListeners();
        }),
      )
      ..add(
        player.onDurationChanged.listen((d) {
          _duration = d;
          notifyListeners();
        }),
      )
      ..add(
        player.onPlayerComplete.listen((_) {
          _playing = false;
          _position = Duration.zero;
          notifyListeners();
        }),
      );
    _player = player;
    return player;
  }

  /// เล่น/หยุดชั่วคราวของข้อความ [key] (url หรือ path) — ข้อความอื่นที่เล่นอยู่หยุด
  Future<void> toggle(String key, {String? url, String? path}) async {
    final player = _ensurePlayer();
    try {
      if (_key == key && _playing) {
        await player.pause();
        _playing = false;
        notifyListeners();
        return;
      }
      if (_key == key && !_playing && _position > Duration.zero) {
        _playing = true;
        notifyListeners();
        await player.resume();
        return;
      }
      await player.stop();
      _key = key;
      _position = Duration.zero;
      _duration = null;
      _loading = true;
      _playing = true;
      notifyListeners();
      await player.setAudioContext(_context);
      final source = path != null ? DeviceFileSource(path) : UrlSource(url!);
      await player.play(source);
    } catch (e) {
      debugPrint('[Voice] play failed: $e');
      _playing = false;
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// ออกจากห้องแชท — เสียงไม่ควรเล่นค้างไปหน้าอื่น
  Future<void> stop() async {
    if (_player == null || _key == null) return;
    _playing = false;
    _position = Duration.zero;
    _key = null;
    notifyListeners();
    try {
      await _player?.stop();
    } catch (_) {}
  }
}

/// บับเบิลข้อความเสียง — ปุ่มเล่น แถบความคืบหน้า และเวลา
class ChatVoiceBubble extends StatelessWidget {
  final String? url;
  final String? localPath;
  final int durationMs;

  /// สีตัวอักษร/ไอคอนของบับเบิล (ขาวบนบับเบิลของเรา)
  final Color foreground;

  const ChatVoiceBubble({
    super.key,
    this.url,
    this.localPath,
    required this.durationMs,
    required this.foreground,
  });

  String get _key => (localPath?.isNotEmpty ?? false) ? localPath! : url ?? '';

  Future<void> _toggle(BuildContext context) async {
    HapticFeedback.selectionClick();
    try {
      await ChatVoicePlayback.instance.toggle(
        _key,
        url: (localPath?.isNotEmpty ?? false) ? null : url,
        path: (localPath?.isNotEmpty ?? false) ? localPath : null,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เล่นข้อความเสียงไม่ได้ ลองอีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playback = ChatVoicePlayback.instance;
    final total = Duration(milliseconds: durationMs);
    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final active = playback.currentKey == _key && _key.isNotEmpty;
        final playing = playback.isPlaying(_key);
        final loading = playback.isLoading(_key);
        final length = (active ? playback.duration : null) ?? total;
        final position = active ? playback.position : Duration.zero;
        final progress = length.inMilliseconds <= 0
            ? 0.0
            : (position.inMilliseconds / length.inMilliseconds).clamp(0.0, 1.0);
        return Semantics(
          label: 'ข้อความเสียง ${formatVoiceDuration(total)}',
          button: true,
          child: InkWell(
            onTap: _key.isEmpty ? null : () => _toggle(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: SizedBox(
              width: 200,
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: loading
                        ? Padding(
                            padding: const EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: foreground,
                            ),
                          )
                        : Icon(
                            playing
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            size: 34,
                            color: foreground,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        color: foreground,
                        backgroundColor: foreground.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatVoiceDuration(
                      active && position > Duration.zero ? position : total,
                    ),
                    style: appFont(
                      fontSize: AppText.sizeCaption,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
