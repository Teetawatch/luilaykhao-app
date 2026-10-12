import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/chat_voice.dart';

/// ตัวอัดปลอม — เขียนไฟล์จริงลงโฟลเดอร์ชั่วคราว จะได้เช็คว่าไฟล์ถูกลบตอนทิ้ง
class _FakeRecorder implements VoiceRecorder {
  _FakeRecorder({this.permitted = true});

  final bool permitted;
  String? path;
  bool cancelled = false;
  bool disposed = false;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<void> start(String path) async {
    this.path = path;
    File(path).writeAsBytesSync([0, 1, 2]);
  }

  @override
  Future<String?> stop() async => path;

  @override
  Future<void> cancel() async {
    cancelled = true;
    if (path != null && File(path!).existsSync()) File(path!).deleteSync();
  }

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  late Directory dir;
  late DateTime now;
  late _FakeRecorder recorder;
  var fileNo = 0;

  VoiceRecordingController controller() => VoiceRecordingController(
    newPath: () async => '${dir.path}/clip-${fileNo++}.m4a',
    clock: () => now,
  );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('voice_test');
    now = DateTime(2026, 10, 12, 21);
    recorder = _FakeRecorder();
    VoiceRecorder.factory = () => recorder;
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('formats durations as m:ss', () {
    expect(formatVoiceDuration(Duration.zero), '0:00');
    expect(formatVoiceDuration(const Duration(milliseconds: 12400)), '0:12');
    expect(formatVoiceDuration(const Duration(seconds: 72)), '1:12');
    expect(formatVoiceDuration(const Duration(seconds: -3)), '0:00');
  });

  test('records, then hands back the clip with its length', () async {
    final c = controller();
    expect(await c.start(), VoiceStartResult.started);
    expect(c.isRecording, isTrue);

    now = now.add(const Duration(seconds: 7, milliseconds: 300));
    expect(c.elapsed, const Duration(seconds: 7, milliseconds: 300));

    final clip = await c.stop();
    expect(clip, isNotNull);
    expect(clip!.durationMs, 7300);
    expect(File(clip.path).existsSync(), isTrue);
    expect(c.isRecording, isFalse);
    expect(recorder.disposed, isTrue);
    c.dispose();
  });

  test(
    'a mis-tap shorter than the minimum is dropped and its file deleted',
    () async {
      final c = controller();
      await c.start();
      now = now.add(const Duration(milliseconds: 300));

      expect(await c.stop(), isNull);
      expect(File(recorder.path!).existsSync(), isFalse);
      c.dispose();
    },
  );

  test('cancel throws the recording away', () async {
    final c = controller();
    await c.start();
    now = now.add(const Duration(seconds: 5));

    await c.cancel();
    expect(c.isRecording, isFalse);
    expect(recorder.cancelled, isTrue);
    expect(File(recorder.path!).existsSync(), isFalse);
    // ยกเลิกแล้วกดส่งตามหลัง — ไม่มีอะไรให้ส่ง
    expect(await c.stop(), isNull);
    c.dispose();
  });

  test('no microphone permission means nothing starts', () async {
    recorder = _FakeRecorder(permitted: false);
    final c = controller();

    expect(await c.start(), VoiceStartResult.denied);
    expect(c.isRecording, isFalse);
    expect(recorder.path, isNull);
    c.dispose();
  });

  testWidgets('stops and hands over the clip by itself at the time limit', (
    tester,
  ) async {
    final c = controller();
    VoiceClip? auto;
    c.onAutoStop = (clip) => auto = clip;

    await c.start();
    now = now.add(kVoiceMaxDuration + const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(c.isRecording, isFalse);
    expect(auto, isNotNull);
    expect(auto!.durationMs, kVoiceMaxDuration.inMilliseconds);
    c.dispose();
  });

  testWidgets('recording bar shows the clock and wires cancel / send', (
    tester,
  ) async {
    final c = controller();
    await c.start();
    now = now.add(const Duration(seconds: 9));
    var cancelled = false;
    var sent = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatVoiceRecordingBar(
            controller: c,
            onCancel: () => cancelled = true,
            onSend: () => sent = true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('0:09'), findsOneWidget);
    expect(find.text('กำลังอัดเสียง…'), findsOneWidget);

    // ใกล้ครบเวลา บอกว่าจะส่งเอง
    now = now.add(const Duration(seconds: 105));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('1:54'), findsOneWidget);
    expect(find.text('อีก 6 วินาทีส่งเอง'), findsOneWidget);

    await tester.tap(find.byTooltip('ทิ้งข้อความเสียง'));
    expect(cancelled, isTrue);
    await tester.tap(find.bySemanticsLabel('ส่งข้อความเสียง'));
    expect(sent, isTrue);

    await c.cancel();
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('voice bubble shows the length before it is played', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatVoiceBubble(
            url: 'https://cdn.example.com/chat/audio/a.m4a',
            durationMs: 72000,
            foreground: Colors.black,
          ),
        ),
      ),
    );

    expect(find.text('1:12'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^ข้อความเสียง 1:12')), findsOneWidget);
  });

  testWidgets('mic button is tappable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatVoiceMicButton(onTap: () => tapped = true)),
      ),
    );
    await tester.tap(find.bySemanticsLabel('อัดข้อความเสียง'));
    expect(tapped, isTrue);
  });
}
