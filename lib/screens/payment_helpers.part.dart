part of 'payment_screen.dart';

class _InstallmentPreview {
  final int no;
  final String dueDate;
  final num amount;

  const _InstallmentPreview({
    required this.no,
    required this.dueDate,
    required this.amount,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Pure helper functions
// ─────────────────────────────────────────────────────────────────────────────

num _amountDue(Map<String, dynamic> booking, String paymentType) {
  if (_normalizePaymentType(booking, paymentType) == 'installment') {
    return _installmentAmount(booking);
  }
  return _asNum(booking['total_amount']);
}

String _normalizePaymentType(Map<String, dynamic> booking, String paymentType) {
  if (paymentType == 'installment' && _installmentAvailable(booking)) {
    return 'installment';
  }
  return 'full';
}

bool _installmentAvailable(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  return _asBool(schedule['installment_enabled']) &&
      _installmentCount(booking) > 1;
}

num _installmentAmount(Map<String, dynamic> booking) {
  final total = _asNum(booking['total_amount']);
  final count = _installmentCount(booking);
  if (count <= 1) return total;
  return ((total / count) * 100).round() / 100;
}

int _installmentCount(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  return int.tryParse(
        textOf(booking['installment_count'] ?? schedule['installment_count']),
      ) ??
      2;
}

int _installmentInterval(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  return int.tryParse(
        textOf(
          booking['installment_interval_days'] ??
              schedule['installment_interval_days'],
        ),
      ) ??
      30;
}

List<_InstallmentPreview> _installmentSchedule(Map<String, dynamic> booking) {
  final total = _asNum(booking['total_amount']);
  final count = _installmentCount(booking);
  final interval = _installmentInterval(booking);
  final per = _installmentAmount(booking);
  final today = DateTime.now();
  return List.generate(count, (index) {
    final no = index + 1;
    final dueDate = today.add(Duration(days: index * interval));
    final amount = no == count
        ? ((total - per * (count - 1)) * 100).round() / 100
        : per;
    return _InstallmentPreview(
      no: no,
      dueDate: DateFormat('yyyy-MM-dd').format(dueDate),
      amount: amount,
    );
  });
}

String _statusLabel(String status) => switch (status) {
  'pending' => 'รอชำระเงิน',
  'confirmed' => 'ยืนยันแล้ว',
  'cancelled' => 'ยกเลิกแล้ว',
  'pending_review' => 'รอตรวจสอบ',
  _ => status,
};

Color _statusColor(String status) => switch (status) {
  'confirmed' => _accent,
  'cancelled' => AppTheme.errorColor,
  'pending' => AppTheme.warningColor,
  _ => AppTheme.warningColor,
};

num _asNum(dynamic value) => num.tryParse(value?.toString() ?? '') ?? 0;

bool _asBool(dynamic value) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

String _buildPromptPayPayload(String identifier, num amount) {
  final cleanId = identifier.replaceAll(RegExp(r'\D'), '');
  var normalized = cleanId;
  var typeTag = '03';
  if (cleanId.length == 10 && cleanId.startsWith('0')) {
    normalized = '0066${cleanId.substring(1)}';
    typeTag = '01';
  } else if (cleanId.length == 13) {
    typeTag = '02';
  }

  String tag(String id, String value) =>
      '$id${value.length.toString().padLeft(2, '0')}$value';

  final merchantAccountInfo =
      tag('00', 'A000000677010111') + tag(typeTag, normalized);
  final payload =
      '${tag('00', '01')}${tag('01', '12')}${tag('29', merchantAccountInfo)}${tag('53', '764')}${tag('54', amount.toStringAsFixed(2))}${tag('58', 'TH')}${tag('62', tag('07', 'LUILAYKHAO'))}6304';
  return payload + _crc16(payload);
}

String _crc16(String value) {
  var crc = 0xFFFF;
  for (final codeUnit in value.codeUnits) {
    crc ^= codeUnit << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1;
    }
  }
  return (crc & 0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0');
}
