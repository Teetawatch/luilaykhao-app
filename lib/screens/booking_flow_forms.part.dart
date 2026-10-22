part of 'booking_flow_screen.dart';

class _PremiumTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  const _PremiumTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.validator,
    this.autofillHints,
    this.textInputAction,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle(context)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          minLines: maxLines > 1 ? maxLines : 1,
          textCapitalization: textCapitalization,
          keyboardType: keyboardType,
          validator: validator,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          decoration: _fieldDecoration(
            context: context,
            icon: icon,
            hint: hint,
          ),
          style: appFont(
            color: _premiumText(context),
            fontSize: AppText.sizeBody,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Tap-to-pick birth date field, styled to match [_PremiumTextField]. Backed by a
/// [ValueNotifier] so it stays in sync when the traveler card autofills from the
/// user's profile/wallet, and integrates with the surrounding [Form] for validation.
/// บังคับตัวพิมพ์ใหญ่ให้ช่องที่ต้องตรงหน้าพาสปอร์ต
///
/// TextCapitalization เป็นแค่คำใบ้ให้คีย์บอร์ด ผู้ใช้กดปิด Caps เองได้และการ
/// วางข้อความก็ข้ามมันไปเลย ตัวนี้จึงแปลงค่าจริงในช่องอีกชั้น
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _PremiumDatePicker extends StatelessWidget {
  final ValueNotifier<DateTime?> value;
  final String label;
  final IconData icon;
  final String? Function(DateTime?)? validator;
  /// ตั้งค่าเริ่มต้นไว้เป็นวันเกิด (อดีตเท่านั้น) — วันหมดอายุพาสปอร์ตส่งค่าพวกนี้
  /// เข้ามาเพื่อกลับทิศเป็นอนาคต โดยไม่ต้องมีวิดเจ็ตซ้ำอีกตัว
  final bool future;
  final DateTime? firstDate;
  final String helpText;
  final String hint;

  const _PremiumDatePicker({
    required this.value,
    required this.label,
    required this.icon,
    this.validator,
    this.future = false,
    this.firstDate,
    this.helpText = 'เลือกวัน/เดือน/ปีเกิด',
    this.hint = 'แตะเพื่อเลือกวันเกิด',
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: value,
      builder: (context, current, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _labelStyle(context)),
            const SizedBox(height: 8),
            FormField<DateTime>(
              // Re-create when the value changes so initialValue applies and any
              // prior validation error clears once a date is chosen.
              key: ValueKey(current),
              initialValue: current,
              validator: validator,
              builder: (field) {
                return InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  onTap: () async {
                    final now = DateTime.now();
                    final earliest = future
                        ? (firstDate ?? now)
                        : DateTime(now.year - 100);
                    final latest = future
                        ? DateTime(now.year + 20, now.month, now.day)
                        : now;
                    // initialDate ต้องอยู่ในช่วง ไม่งั้น showDatePicker โยน assert
                    final preferred = current ??
                        (future
                            ? earliest
                            : DateTime(now.year - 25, now.month, now.day));
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: preferred.isBefore(earliest)
                          ? earliest
                          : (preferred.isAfter(latest) ? latest : preferred),
                      firstDate: earliest,
                      lastDate: latest,
                      helpText: helpText,
                    );
                    if (picked != null) {
                      value.value =
                          DateTime(picked.year, picked.month, picked.day);
                    }
                  },
                  child: InputDecorator(
                    isEmpty: current == null,
                    decoration: _fieldDecoration(
                      context: context,
                      icon: icon,
                      hint: hint,
                    ).copyWith(
                      errorText: field.errorText,
                      suffixIcon: Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: _mutedTextColor(context),
                      ),
                    ),
                    child: current == null
                        ? null
                        : Text(
                            _birthDateLabel(current),
                            style: appFont(
                              color: _premiumText(context),
                              fontSize: AppText.sizeBody,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  /// What this step does, e.g. "เพิ่มจำนวน" — a bare +/- glyph announces as
  /// nothing useful, and this stepper sets what the customer pays for.
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const _CounterButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: isPrimary ? _softAccent : Colors.white,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.62),
          foregroundColor: isPrimary ? Colors.white : _premiumText(context),
          disabledForegroundColor: _mutedTextColor(context).withValues(alpha: 0.35),
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

class _SummaryMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SummaryMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _mutedTextColor(context), size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: appFont(
              color: _mutedTextColor(context),
              fontSize: AppText.sizeLabel,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isTotal;

  /// ยอดเป็นตัวเลข — ใส่แล้วตัวเลขจะวิ่งไปค่าใหม่ตอนยอดเปลี่ยน (เพิ่ม add-on,
  /// ใส่โค้ดส่วนลด) แทน [value] ที่เป็นข้อความตายตัว
  final num? amount;

  const _PriceRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isTotal = false,
    this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: appFont(
              color: isTotal ? _premiumText(context) : _mutedTextColor(context),
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: isTotal ? -0.2 : 0,
            ),
          ),
        ),
        CountUpText(
          value: amount ?? 0,
          format: (shown) => amount == null ? value : money(shown),
          style: appFont(
            color: valueColor ?? _premiumText(context),
            fontSize: isTotal ? 20 : 14,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
            letterSpacing: isTotal ? -0.4 : 0,
          ),
        ),
      ],
    );
  }
}

class _CompactNotice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CompactNotice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _fieldBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: _cardBorder(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _mutedTextColor(context), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: appFont(
                color: _mutedTextColor(context),
                fontWeight: FontWeight.w700,
                fontSize: AppText.sizeLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripImageFallback extends StatelessWidget {
  const _TripImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFECFDF5),
      child: const Center(
        child: Icon(Icons.landscape_rounded, color: _softAccent, size: 34),
      ),
    );
  }
}

