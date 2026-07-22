import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One recorded GPS fix along a walk.
class TrekPoint {
  final double lat;
  final double lng;
  final double? ele;
  final DateTime at;

  const TrekPoint({
    required this.lat,
    required this.lng,
    required this.at,
    this.ele,
  });

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    if (ele != null) 'ele': ele,
    'at': at.toIso8601String(),
  };

  static TrekPoint? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final lat = double.tryParse('${raw['lat']}');
    final lng = double.tryParse('${raw['lng']}');
    final at = DateTime.tryParse('${raw['at']}');
    if (lat == null || lng == null || at == null) return null;
    return TrekPoint(
      lat: lat,
      lng: lng,
      ele: double.tryParse('${raw['ele']}'),
      at: at,
    );
  }
}

/// Records the customer's own walk during a trip so their Passport can show the
/// distance they actually covered rather than the route's published estimate.
///
/// Deliberately independent of [CustomerLocationService], which exists to place
/// the user on the tracking map: this one is about accumulating a trace over
/// hours, so it filters noisy fixes, survives the app being killed (every point
/// is written to disk as it arrives), and reports its own moving time.
///
/// Nothing is sent anywhere until the customer chooses to save the walk.
class TrekRecorderService extends ChangeNotifier {
  TrekRecorderService._();
  static final TrekRecorderService instance = TrekRecorderService._();

  /// Fixes worse than this are dropped — a 60m-accurate point in a forest can
  /// sit 60m off the trail and inflate the distance with pure jitter.
  static const double _maxAccuracyM = 35;

  /// Two fixes closer together than this are treated as standing still.
  static const double _minStepM = 8;

  /// A gap longer than this is a pause, not walking, and is excluded from
  /// moving time (lunch, waiting for the group, sleeping at camp).
  static const Duration _pauseThreshold = Duration(minutes: 3);

  static const String _storeKeyPrefix = 'trek_recording_v1.';

  StreamSubscription<Position>? _sub;
  String? _bookingRef;
  final List<TrekPoint> _points = [];
  DateTime? _startedAt;
  Duration _movingTime = Duration.zero;
  bool _saving = false;

  bool get isRecording => _sub != null;
  String? get bookingRef => _bookingRef;
  List<TrekPoint> get points => List.unmodifiable(_points);
  DateTime? get startedAt => _startedAt;
  Duration get movingTime => _movingTime;
  bool get saving => _saving;

  /// Distance walked so far, in kilometres.
  double get distanceKm {
    var meters = 0.0;
    for (var i = 1; i < _points.length; i++) {
      meters += _metersBetween(_points[i - 1], _points[i]);
    }
    return meters / 1000;
  }

  /// Elevation climbed so far, ignoring the vertical jitter GPS is prone to.
  int get elevationGainM {
    double? reference;
    var gain = 0.0;
    for (final p in _points) {
      final ele = p.ele;
      if (ele == null) continue;
      if (reference == null) {
        reference = ele;
        continue;
      }
      final delta = ele - reference;
      if (delta.abs() < 3) continue;
      if (delta > 0) gain += delta;
      reference = ele;
    }
    return gain.round();
  }

  String get _storeKey => '$_storeKeyPrefix${_bookingRef ?? ''}';

  /// Picks up a recording that was interrupted (app killed, phone died) so a
  /// day's walk is never lost to a crash halfway up.
  Future<bool> restore(String bookingRef) async {
    if (isRecording) return _bookingRef == bookingRef;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_storeKeyPrefix$bookingRef');
    if (raw == null) return false;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _bookingRef = bookingRef;
      _points
        ..clear()
        ..addAll(
          (decoded['points'] as List? ?? const [])
              .map(TrekPoint.fromJson)
              .whereType<TrekPoint>(),
        );
      _startedAt = DateTime.tryParse('${decoded['started_at']}');
      _movingTime = Duration(seconds: decoded['moving_seconds'] as int? ?? 0);
      notifyListeners();
      return _points.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns false when location permission is unavailable.
  Future<bool> start(String bookingRef) async {
    if (isRecording) return true;

    if (!await _ensurePermission()) return false;

    if (_bookingRef != bookingRef) {
      _points.clear();
      _movingTime = Duration.zero;
      _startedAt = null;
    }

    _bookingRef = bookingRef;
    _startedAt ??= DateTime.now();

    _sub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 5,
          ),
        ).listen(
          _onPosition,
          onError: (Object e) =>
              debugPrint('[TrekRecorder] position stream error: $e'),
        );

    notifyListeners();
    return true;
  }

  Future<void> pause() async {
    await _sub?.cancel();
    _sub = null;
    notifyListeners();
  }

  /// Clears the recording and its saved copy. Irreversible on purpose — it is
  /// only reachable behind a confirmation in the UI.
  Future<void> discard() async {
    await pause();
    final ref = _bookingRef;
    _points.clear();
    _movingTime = Duration.zero;
    _startedAt = null;
    _bookingRef = null;
    if (ref != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_storeKeyPrefix$ref');
    }
    notifyListeners();
  }

  /// Hands the recorded points to [upload], and only clears local state once
  /// that succeeds — a failed upload leaves the walk intact to retry.
  Future<bool> save(
    Future<void> Function(Map<String, dynamic> payload) upload,
  ) async {
    if (_points.length < 2 || _saving) return false;

    _saving = true;
    notifyListeners();

    try {
      await upload({
        'points': [
          for (final p in _points)
            {'lat': p.lat, 'lng': p.lng, if (p.ele != null) 'ele': p.ele},
        ],
        'started_at': _startedAt?.toIso8601String(),
        'ended_at': _points.last.at.toIso8601String(),
        'moving_seconds': _movingTime.inSeconds,
      });
      await discard();
      return true;
    } catch (_) {
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void _onPosition(Position position) {
    if (position.accuracy > _maxAccuracyM) return;

    final point = TrekPoint(
      lat: position.latitude,
      lng: position.longitude,
      ele: position.altitude,
      at: position.timestamp,
    );

    if (_points.isNotEmpty) {
      final last = _points.last;
      if (_metersBetween(last, point) < _minStepM) return;

      final gap = point.at.difference(last.at);
      if (gap > Duration.zero && gap <= _pauseThreshold) {
        _movingTime += gap;
      }
    }

    _points.add(point);
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    if (_bookingRef == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storeKey,
        jsonEncode({
          'points': [for (final p in _points) p.toJson()],
          'started_at': _startedAt?.toIso8601String(),
          'moving_seconds': _movingTime.inSeconds,
        }),
      );
    } catch (e) {
      debugPrint('[TrekRecorder] persist failed: $e');
    }
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static double _metersBetween(TrekPoint a, TrekPoint b) {
    const earthRadius = 6371000.0;
    final dLat = _deg2rad(b.lat - a.lat);
    final dLng = _deg2rad(b.lng - a.lng);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(a.lat)) *
            math.cos(_deg2rad(b.lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  static double _deg2rad(double deg) => deg * math.pi / 180;
}
