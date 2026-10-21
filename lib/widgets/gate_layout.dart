import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// โครงหน้าจอ "หยุดก่อน" แบบเต็มจอ (บังคับอัปเดต / ปิดปรับปรุง) — เนื้อหาอยู่กลางจอ
/// ทั้งแนวตั้งและแนวนอนเสมอ กว้างไม่เกิน [maxWidth] บนแท็บเล็ต และเลื่อนได้เมื่อจอเตี้ย
/// (มือถือแนวนอน / ตัวอักษรใหญ่) แทนที่จะล้นจอ
class GateLayout extends StatelessWidget {
  final List<Widget> children;

  static const double maxWidth = 420;

  const GateLayout({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              // สูงอย่างน้อยเท่าจอ เนื้อหาจึงอยู่กลางจอได้ แต่ยังเลื่อนได้เมื่อยาวกว่าจอ
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 48).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
