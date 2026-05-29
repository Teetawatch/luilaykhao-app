part of 'booking_flow_screen.dart';

class _HalalFoodSelector extends StatelessWidget {
  final ValueNotifier<bool> selected;
  final ValueChanged<bool> onChanged;

  const _HalalFoodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: selected,
      builder: (context, wantsHalal, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ต้องการอาหารฮาลาล', style: _labelStyle(context)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _HalalChoiceButton(
                    label: 'ต้องการ',
                    icon: Icons.check_circle_outline_rounded,
                    selected: wantsHalal,
                    onTap: () => onChanged(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HalalChoiceButton(
                    label: 'ไม่ต้องการ',
                    icon: Icons.cancel_outlined,
                    selected: !wantsHalal,
                    onTap: () => onChanged(false),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HalalChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _HalalChoiceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? _softAccent.withValues(alpha: 0.10)
              : _fieldBackground(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _softAccent : _cardBorder(context),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? _softAccent : _mutedTextColor(context), size: 18),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.anuphan(
                  color: selected ? _softAccent : _mutedTextColor(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumDropdown<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;
  final DropdownButtonBuilder? selectedItemBuilder;

  const _PremiumDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.selectedItemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle(context)),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          decoration: _fieldDecoration(
            context: context,
            icon: icon,
            hint: label,
          ),
          style: GoogleFonts.anuphan(
            color: _premiumText(context),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          dropdownColor: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(18),
          selectedItemBuilder: selectedItemBuilder,
          items: items,
          onChanged: items.isEmpty ? null : onChanged,
          validator: validator,
        ),
      ],
    );
  }
}

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
          style: GoogleFonts.anuphan(
            color: _premiumText(context),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const _CounterButton({
    required this.icon,
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
            style: GoogleFonts.anuphan(
              color: _mutedTextColor(context),
              fontSize: 12.5,
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

  const _PriceRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.anuphan(
              color: isTotal ? _premiumText(context) : _mutedTextColor(context),
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: isTotal ? -0.2 : 0,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.anuphan(
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _mutedTextColor(context), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.anuphan(
                color: _mutedTextColor(context),
                fontWeight: FontWeight.w700,
                fontSize: 13,
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
      color: const Color(0xFFE7F3EF),
      child: const Center(
        child: Icon(Icons.landscape_rounded, color: _softAccent, size: 34),
      ),
    );
  }
}

