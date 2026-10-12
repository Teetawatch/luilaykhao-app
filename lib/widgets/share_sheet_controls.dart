/// ชิ้นส่วนเครื่องมือใต้พรีวิวของ sheet แชร์การ์ด — ใช้ร่วมกันระหว่างการ์ดเหรียญ
/// ([MedalShareSheet]) กับการ์ดนับถอยหลัง/สรุปทริป ([TripStoryShareSheet])
/// สองใบจึงจับแล้วรู้สึกเป็นเครื่องมือชุดเดียวกัน
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// หัวของ sheet แชร์การ์ด — ขีดจับ ชื่อ และปุ่มปิด
///
/// sheet แชร์สูงเกือบเต็มจอเพื่อให้พรีวิวการ์ดใหญ่พอ แทบไม่เหลือพื้นที่นอก sheet
/// ให้แตะปิด และไม่ใช่ทุกคนรู้ว่าต้องปัดลง ปุ่ม X จึงต้องมองเห็นได้เสมอ
class ShareSheetHeader extends StatelessWidget {
  final String title;

  const ShareSheetHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 4,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: AppTheme.mutedText(context).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appFont(
                  fontSize: AppText.sizeSubtitle,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface(context),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'ปิด',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).maybePop();
                },
                behavior: HitTestBehavior.opaque,
                // พื้นที่แตะ 44×44 ตามขั้นต่ำของ iOS แม้วงที่เห็นจะเล็กกว่า
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.subtleSurface(context),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.border(context)),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// แท็บเลือกหมวดเครื่องมือ — แยกเป็นหมวดเพื่อให้ sheet ไม่สูงจนดันพรีวิว
/// การ์ดให้เล็กจนมองไม่เห็นว่ากำลังปรับอะไร
class ShareSheetTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  const ShareSheetTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: GestureDetector(
                  onTap: () => onSelected(i),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected
                          ? AppTheme.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        fontSize: AppText.sizeLabel,
                        fontWeight: FontWeight.w800,
                        color: i == selected
                            ? Colors.white
                            : AppTheme.onSurface(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// แถวชิปเลื่อนแนวนอน
class ShareChipRow extends StatelessWidget {
  final List<Widget> children;

  const ShareChipRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

/// ชิปเลือกหนึ่งในหลายตัว — มีจุดสี ไอคอน หรือวงหมุนนำหน้าได้
class SharePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? swatch;
  final bool busy;

  const SharePill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.swatch,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : AppTheme.onSurface(context);

    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.primaryColor
                : AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: active ? AppTheme.primaryColor : AppTheme.border(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (swatch != null)
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 16, color: fg),
              if (busy || swatch != null || icon != null)
                const SizedBox(width: 6),
              Text(
                label,
                style: appFont(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ชิปเปิด/ปิดชิ้นส่วนบนการ์ด
class ShareToggle extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;

  const ShareToggle({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = on ? AppTheme.primaryColor : AppTheme.mutedText(context);

    return Semantics(
      toggled: on,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: on
                ? AppTheme.tintOf(context, AppTheme.primaryColor)
                : AppTheme.subtleSurface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: on ? AppTheme.primaryColor : AppTheme.border(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 16,
                color: fg,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: appFont(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: on
                      ? AppTheme.onSurface(context)
                      : AppTheme.mutedText(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// แถบเลื่อน 0–1 — [onChanged] ทุกเฟรมที่ลาก [onSettled] ตอนปล่อยนิ้ว (ค่อยจำ)
class ShareSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onSettled;

  const ShareSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onSettled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: appFont(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText(context),
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppTheme.primaryColor,
              inactiveTrackColor: AppTheme.border(context),
              thumbColor: AppTheme.primaryColor,
              // แบนตามธีมของแอป — thumb มาตรฐานมีเงาติดมาด้วย
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 9,
                elevation: 0,
                pressedElevation: 0,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              overlayColor: AppTheme.primaryColor.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              onChanged: onChanged,
              onChangeEnd: (_) {
                HapticFeedback.selectionClick();
                onSettled();
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// ลิงก์ตัวหนังสือสีแบรนด์เล็ก ๆ ท้ายแถว
class ShareTextAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const ShareTextAction({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(
          label,
          style: appFont(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}

/// คำอธิบายตัวเล็กกลางแถว
class ShareHint extends StatelessWidget {
  final String text;

  const ShareHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: appFont(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.mutedText(context),
        ),
      ),
    );
  }
}
