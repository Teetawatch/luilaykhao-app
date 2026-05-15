import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../config/api_config.dart';
import 'api_client.dart';

typedef RealtimeEventHandler = void Function(Map<String, dynamic> payload);

class _Subscription {
  final String channel;
  final Map<String, Set<RealtimeEventHandler>> handlers = {};
  bool authenticated = false;

  _Subscription(this.channel);
}

/// Pusher-protocol client for Laravel Reverb.
///
/// Supports public, private, and presence channels. Authentication for private
/// channels uses the backend's `/api/v1/broadcasting/auth` endpoint with the
/// user's Sanctum token.
class RealtimeService {
  RealtimeService._();
  static final instance = RealtimeService._();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  String? _socketId;
  int _reconnectAttempts = 0;
  bool _connecting = false;
  bool _disposed = false;

  final Map<String, _Subscription> _subscriptions = {};
  ApiClient? _api;

  bool get isConnected => _socketId != null;

  void attachApi(ApiClient api) {
    _api = api;
  }

  Future<void> connect() async {
    if (!ApiConfig.hasRealtimeConfig) return;
    if (_connecting || _channel != null) return;
    _connecting = true;

    try {
      _channel = WebSocketChannel.connect(ApiConfig.reverbUri);
      _sub = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onClose,
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Realtime connect error: $e');
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _channel = null;
    _socketId = null;
    for (final sub in _subscriptions.values) {
      sub.authenticated = false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
  }

  /// Subscribe to a channel + event. Returns a disposer.
  Future<VoidCallback> subscribe({
    required String channel,
    required String event,
    required RealtimeEventHandler handler,
  }) async {
    final sub = _subscriptions.putIfAbsent(
      channel,
      () => _Subscription(channel),
    );
    sub.handlers.putIfAbsent(event, () => <RealtimeEventHandler>{}).add(handler);

    if (_channel == null) {
      await connect();
    }
    if (isConnected && !sub.authenticated) {
      await _sendSubscribe(sub);
    }

    return () => unsubscribe(channel: channel, event: event, handler: handler);
  }

  void unsubscribe({
    required String channel,
    required String event,
    required RealtimeEventHandler handler,
  }) {
    final sub = _subscriptions[channel];
    if (sub == null) return;
    sub.handlers[event]?.remove(handler);
    if (sub.handlers[event]?.isEmpty ?? false) {
      sub.handlers.remove(event);
    }
    if (sub.handlers.isEmpty) {
      _subscriptions.remove(channel);
      if (isConnected) {
        _send({
          'event': 'pusher:unsubscribe',
          'data': {'channel': channel},
        });
      }
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return;
      final event = decoded['event']?.toString() ?? '';
      final channel = decoded['channel']?.toString() ?? '';
      final dataRaw = decoded['data'];
      final data = dataRaw is String
          ? _safeDecode(dataRaw)
          : (dataRaw is Map ? Map<String, dynamic>.from(dataRaw) : <String, dynamic>{});

      switch (event) {
        case 'pusher:connection_established':
          _socketId = data['socket_id']?.toString();
          _reconnectAttempts = 0;
          _startPing();
          _resubscribeAll();
          return;
        case 'pusher:error':
          debugPrint('Realtime error: $data');
          return;
        case 'pusher:pong':
          return;
      }

      if (channel.isEmpty) return;
      final sub = _subscriptions[channel];
      if (sub == null) return;

      final normalized = _normalizeEvent(event);
      final handlers = sub.handlers[normalized] ?? sub.handlers[event];
      if (handlers == null) return;
      for (final h in List.of(handlers)) {
        h(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      debugPrint('Realtime parse error: $e');
    }
  }

  // Laravel broadcasts events like "App\\Events\\SeatLocked" — accept both
  // fully-qualified and short names.
  String _normalizeEvent(String event) {
    if (event.contains('\\')) {
      final parts = event.split('\\');
      return parts.last;
    }
    return event;
  }

  Map<String, dynamic> _safeDecode(String raw) {
    if (raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }

  void _onError(Object err, StackTrace s) {
    debugPrint('Realtime socket error: $err');
    _scheduleReconnect();
  }

  void _onClose() {
    _channel = null;
    _sub = null;
    _socketId = null;
    _pingTimer?.cancel();
    for (final sub in _subscriptions.values) {
      sub.authenticated = false;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    if (!ApiConfig.hasRealtimeConfig) return;
    _reconnectTimer?.cancel();
    _reconnectAttempts = (_reconnectAttempts + 1).clamp(1, 6);
    final delay = Duration(seconds: 2 * _reconnectAttempts);
    _reconnectTimer = Timer(delay, connect);
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _send({'event': 'pusher:ping', 'data': {}});
    });
  }

  Future<void> _resubscribeAll() async {
    for (final sub in _subscriptions.values) {
      await _sendSubscribe(sub);
    }
  }

  Future<void> _sendSubscribe(_Subscription sub) async {
    final isPrivate = sub.channel.startsWith('private-');
    final isPresence = sub.channel.startsWith('presence-');
    final payload = <String, dynamic>{'channel': sub.channel};

    if (isPrivate || isPresence) {
      final auth = await _authChannel(sub.channel);
      if (auth == null) return;
      payload['auth'] = auth;
    }

    _send({'event': 'pusher:subscribe', 'data': payload});
    sub.authenticated = true;
  }

  Future<String?> _authChannel(String channel) async {
    final api = _api;
    final socketId = _socketId;
    if (api == null || socketId == null) return null;
    if (api.token == null || api.token!.isEmpty) return null;

    try {
      final response = await api.post(
        'broadcasting/auth',
        body: {'socket_id': socketId, 'channel_name': channel},
      );
      if (response is Map && response['auth'] != null) {
        return response['auth']?.toString();
      }
    } catch (e) {
      debugPrint('Broadcasting auth failed for $channel: $e');
    }
    return null;
  }

  void _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('Realtime send error: $e');
    }
  }
}
