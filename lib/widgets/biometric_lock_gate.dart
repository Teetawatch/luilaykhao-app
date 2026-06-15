import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';

/// Wraps the app and forces a biometric prompt before showing children when
/// the user has opted in. Falls through transparently when biometric isn't
/// enabled or supported.
class BiometricLockGate extends StatefulWidget {
  final Widget child;
  const BiometricLockGate({super.key, required this.child});

  @override
  State<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends State<BiometricLockGate> {
  bool _checked = false;
  bool _locked = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
  }

  Future<void> _evaluate() async {
    final app = context.read<AppProvider>();
    if (!app.isLoggedIn) {
      if (mounted) setState(() => _checked = true);
      return;
    }
    final enabled = await BiometricService.instance.isEnabled();
    final supported = enabled
        ? await BiometricService.instance.isSupported()
        : false;
    if (!mounted) return;
    if (!enabled || !supported) {
      setState(() {
        _checked = true;
        _locked = false;
      });
      return;
    }
    setState(() {
      _checked = true;
      _locked = true;
    });
    _prompt();
  }

  Future<void> _prompt() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final ok = await BiometricService.instance.authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      if (ok) _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: Material(
              color: AppTheme.background(context),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 72,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'ปลดล็อกแอป',
                        style: appFont(
                          color: AppTheme.onSurface(context),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ใช้ลายนิ้วมือหรือใบหน้าของคุณเพื่อเข้าใช้งาน',
                        textAlign: TextAlign.center,
                        style: appFont(
                          color: AppTheme.mutedText(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _authenticating ? null : _prompt,
                        icon: const Icon(Icons.fingerprint_rounded),
                        label: Text(
                          _authenticating ? 'กำลังตรวจสอบ…' : 'ยืนยันตัวตน',
                          style: appFont(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () async {
                          await context.read<AppProvider>().logout();
                          if (!mounted) return;
                          setState(() => _locked = false);
                        },
                        child: Text(
                          'ใช้บัญชีอื่น',
                          style: appFont(
                            color: AppTheme.mutedText(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
