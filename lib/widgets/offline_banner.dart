import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';

enum _BannerPhase { hidden, offlineToast, offlineStrip, backOnline }

/// Tells the user when the device loses — and regains — network.
///
/// Two surfaces, one per job:
/// - **Events** ("just went offline", "back online") drop in as a floating
///   pill under the status bar, then leave on their own. It overlays the app
///   bar only briefly, the way a toast does; tapping dismisses it early.
/// - **State** ("still offline") is a slim strip under the status bar that
///   pushes the whole app down through `MediaQuery.padding.top`, so it never
///   covers a title — most app bars here are centred, right where a
///   persistent pill would sit.
///
/// Flaps shorter than [showDelay] (wifi → cellular hand-offs briefly report
/// `none`) never show anything, and "back online" only appears if the user
/// was actually told they were offline.
class OfflineBanner extends StatefulWidget {
  final Widget child;

  /// Defaults to [ConnectivityService.instance.isOnline]; injectable for tests.
  final ValueListenable<bool>? isOnline;

  final Duration showDelay;
  final Duration toastFor;
  final Duration backOnlineFor;

  const OfflineBanner({
    super.key,
    required this.child,
    this.isOnline,
    this.showDelay = const Duration(milliseconds: 800),
    this.toastFor = const Duration(seconds: 4),
    this.backOnlineFor = const Duration(milliseconds: 2500),
  });

  /// Height the strip adds to `MediaQuery.padding.top` while offline.
  static const double stripHeight = 28;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  late ValueListenable<bool> _source;
  _BannerPhase _phase = _BannerPhase.hidden;

  /// What the pill keeps drawing while it slides away — otherwise its content
  /// would change before the exit animation even starts.
  bool _pillOnline = false;

  Timer? _showTimer;
  Timer? _phaseTimer;

  @override
  void initState() {
    super.initState();
    _source = widget.isOnline ?? ConnectivityService.instance.isOnline;
    _source.addListener(_onConnectivityChanged);
    if (!_source.value) _scheduleOffline(toast: true);
  }

  @override
  void didUpdateWidget(covariant OfflineBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.isOnline ?? ConnectivityService.instance.isOnline;
    if (!identical(next, _source)) {
      _source.removeListener(_onConnectivityChanged);
      _source = next..addListener(_onConnectivityChanged);
      _onConnectivityChanged();
    }
  }

  @override
  void dispose() {
    _source.removeListener(_onConnectivityChanged);
    _showTimer?.cancel();
    _phaseTimer?.cancel();
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (_source.value) {
      _showTimer?.cancel();
      if (_phase == _BannerPhase.offlineToast ||
          _phase == _BannerPhase.offlineStrip) {
        _setPhase(_BannerPhase.backOnline, then: widget.backOnlineFor);
      }
    } else if (_phase == _BannerPhase.hidden) {
      _scheduleOffline(toast: true);
    } else if (_phase == _BannerPhase.backOnline) {
      // Dropped again right after recovering: the user has just seen the
      // toast, so go straight back to the quiet strip.
      _phaseTimer?.cancel();
      _scheduleOffline(toast: false);
    }
  }

  void _scheduleOffline({required bool toast}) {
    _showTimer?.cancel();
    _showTimer = Timer(widget.showDelay, () {
      if (!mounted || _source.value) return;
      if (toast) {
        _setPhase(_BannerPhase.offlineToast, then: widget.toastFor);
      } else {
        _setPhase(_BannerPhase.offlineStrip);
      }
    });
  }

  /// Moves to [phase]; with [then], advances to the phase that follows it
  /// once that long has passed.
  void _setPhase(_BannerPhase phase, {Duration? then}) {
    _phaseTimer?.cancel();
    setState(() {
      _phase = phase;
      if (phase == _BannerPhase.offlineToast) _pillOnline = false;
      if (phase == _BannerPhase.backOnline) _pillOnline = true;
    });
    if (then != null) _phaseTimer = Timer(then, _advance);
  }

  void _advance() {
    if (!mounted) return;
    switch (_phase) {
      case _BannerPhase.offlineToast:
        _setPhase(_BannerPhase.offlineStrip);
      case _BannerPhase.backOnline:
        _setPhase(_BannerPhase.hidden);
      case _BannerPhase.hidden:
      case _BannerPhase.offlineStrip:
        break;
    }
  }

  void _dismissToast() {
    if (_phase == _BannerPhase.offlineToast) _advance();
  }

  @override
  Widget build(BuildContext context) {
    final pillVisible =
        _phase == _BannerPhase.offlineToast ||
        _phase == _BannerPhase.backOnline;
    final stripVisible = _phase == _BannerPhase.offlineStrip;
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: stripVisible ? OfflineBanner.stripHeight : 0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: widget.child,
      builder: (context, strip, child) {
        return Stack(
          children: [
            // Always wrapped (even at 0) so the subtree keeps its place and
            // state when the strip comes and goes.
            MediaQuery(
              data: media.copyWith(
                padding: media.padding.copyWith(top: topInset + strip),
                viewPadding: media.viewPadding.copyWith(
                  top: media.viewPadding.top + strip,
                ),
              ),
              child: child!,
            ),
            if (strip > 0)
              Positioned(
                top: topInset,
                left: 0,
                right: 0,
                height: strip,
                child: const ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.bottomCenter,
                    minHeight: OfflineBanner.stripHeight,
                    maxHeight: OfflineBanner.stripHeight,
                    child: _OfflineStrip(),
                  ),
                ),
              ),
            Positioned(
              top: topInset + 8,
              left: 16,
              right: 16,
              child: IgnorePointer(
                ignoring: !pillVisible,
                child: Center(
                  child: AnimatedSlide(
                    offset: pillVisible ? Offset.zero : const Offset(0, -1.6),
                    duration: const Duration(milliseconds: 320),
                    curve: pillVisible
                        ? Curves.easeOutBack
                        : Curves.easeInCubic,
                    child: AnimatedOpacity(
                      opacity: pillVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        // Mounted above the Navigator, so there is no Material
                        // ancestor — without one Text falls back to
                        // WidgetsApp's yellow-underlined error style.
                        child: Material(
                          type: MaterialType.transparency,
                          child: _StatusPill(
                            online: _pillOnline,
                            onTap: _dismissToast,
                          ),
                        ),
                      ),
                    ),
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

/// Inverse surface (dark on a light app, light on a dark one) — neutral
/// rather than alarm-red: being offline isn't an error the user made, and
/// cached screens still work.
Color _inverseFill(BuildContext context) =>
    AppTheme.isDark(context) ? AppTheme.slate100 : AppTheme.slate900;

Color _inverseText(BuildContext context) =>
    AppTheme.isDark(context) ? AppTheme.slate900 : Colors.white;

class _StatusPill extends StatelessWidget {
  final bool online;
  final VoidCallback onTap;

  const _StatusPill({required this.online, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fill = online ? AppTheme.primaryColor : _inverseFill(context);
    final fg = online ? Colors.white : _inverseText(context);
    final title = online
        ? 'กลับมาออนไลน์แล้ว'
        : 'ไม่มีการเชื่อมต่ออินเทอร์เน็ต';
    final subtitle = online ? null : 'ข้อมูลบางส่วนอาจยังไม่อัปเดต';

    return Semantics(
      liveRegion: true,
      label: subtitle == null ? title : '$title $subtitle',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          padding: EdgeInsets.fromLTRB(6, 6, subtitle == null ? 14 : 18, 6),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: online
                        ? Colors.white.withValues(alpha: 0.22)
                        : AppTheme.warningColor,
                    shape: BoxShape.circle,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      key: ValueKey(online),
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appFont(
                          color: fg,
                          fontSize: AppText.sizeLabel,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appFont(
                            color: fg.withValues(alpha: 0.72),
                            fontSize: AppText.sizeCaption,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip();

  @override
  Widget build(BuildContext context) {
    final fg = _inverseText(context);
    return Semantics(
      label: 'ออฟไลน์อยู่ ข้อมูลบางส่วนอาจยังไม่อัปเดต',
      excludeSemantics: true,
      // Material (not ColoredBox): this sits above the Navigator, where Text
      // has no Material ancestor to inherit a sane default style from.
      child: Material(
        color: _inverseFill(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: AppTheme.warningColor,
                size: 14,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'ออฟไลน์อยู่'),
                      TextSpan(
                        text: '  ·  ข้อมูลบางส่วนอาจยังไม่อัปเดต',
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    color: fg,
                    fontSize: AppText.sizeCaption,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
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
