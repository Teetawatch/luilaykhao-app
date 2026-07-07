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
  final type = _normalizePaymentType(booking, paymentType);
  if (type == 'installment') return _installmentAmount(booking);
  if (type == 'deposit') return _depositAmount(booking);
  if (type == 'split') return _splitOwnShare(booking);
  return _asNum(booking['total_amount']);
}

String _normalizePaymentType(Map<String, dynamic> booking, String paymentType) {
  if (paymentType == 'installment' &&
      _installmentAvailable(booking) &&
      _availableInstallmentCounts(booking).isNotEmpty) {
    return 'installment';
  }
  if (paymentType == 'deposit' && _depositAvailable(booking)) {
    return 'deposit';
  }
  if (paymentType == 'split' && _splitAvailable(booking)) {
    return 'split';
  }
  return 'full';
}

/// แบ่งจ่ายกับเพื่อน: ต้องมีผู้เดินทางอย่างน้อย 2 คน และไม่ใช่จอยทริป
bool _splitAvailable(Map<String, dynamic> booking) {
  if (_asBool(booking['is_join_trip'])) return false;
  return _splitPassengerCount(booking) >= 2;
}

int _splitPassengerCount(Map<String, dynamic> booking) =>
    asList(booking['passengers']).length;

/// ส่วนของเจ้าของตอนเลือก "แบ่งจ่ายกับเพื่อน" = ยอดรวม ÷ จำนวนผู้เดินทาง
num _splitOwnShare(Map<String, dynamic> booking) {
  final total = _asNum(booking['total_amount']);
  final count = _splitPassengerCount(booking);
  if (count <= 1) return total;
  return ((total / count) * 100).round() / 100;
}

bool _installmentAvailable(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  if (!_asBool(schedule['installment_enabled'])) return false;
  if (_installmentCount(booking) <= 1) return false;
  return true;
}

int _daysUntilTrip(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  // นับถึงวันออกรถจริง (อาจเป็นคืนก่อนวันทริป)
  final dep = scheduleDepartsAt(schedule) ??
      DateTime.tryParse(textOf(schedule['departure_date']));
  if (dep == null) return 9999;
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final depDate = DateTime(dep.year, dep.month, dep.day);
  final diff = depDate.difference(todayDate).inDays;
  return diff < 0 ? 0 : diff;
}

int _maxAllowedInstallmentCount(Map<String, dynamic> booking) {
  final days = _daysUntilTrip(booking);
  final interval = _installmentInterval(booking);
  if (days <= 0) return 1;
  return (days / interval).floor() + 1;
}

/// Returns the feasible installment counts (2..min(scheduleMax, timeBased)).
List<int> _availableInstallmentCounts(Map<String, dynamic> booking) {
  final scheduleMax = _installmentCount(booking);
  final maxAllowed = _maxAllowedInstallmentCount(booking);
  final max = scheduleMax < maxAllowed ? scheduleMax : maxAllowed;
  if (max < 2) return [];
  return List.generate(max - 1, (i) => i + 2);
}

/// True when installment is enabled by schedule but no feasible count exists due to departure proximity.
bool _installmentNotAvailable(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  if (!_asBool(schedule['installment_enabled'])) return false;
  return _availableInstallmentCounts(booking).isEmpty;
}

bool _depositAvailable(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  if (!_asBool(schedule['deposit_enabled'])) return false;
  if (_asBool(booking['is_join_trip'])) return false;
  return _depositAmount(booking) > 0;
}

num _depositAmount(Map<String, dynamic> booking) {
  final schedule = asMap(booking['schedule']);
  final total = _asNum(booking['total_amount']);
  if (total <= 0) return 0;

  final stored = _asNum(booking['deposit_amount']);
  if (stored > 0) return stored;

  final type = textOf(schedule['deposit_type']);
  if (type == 'percent') {
    final percent = _asNum(schedule['deposit_percent']);
    if (percent <= 0) return 0;
    final amount = ((total * percent) / 100).round();
    return amount > total ? total : amount;
  }
  if (type == 'amount') {
    final amount = _asNum(schedule['deposit_amount']);
    if (amount <= 0) return 0;
    return amount > total ? total : amount;
  }
  return 0;
}

num _balanceAmount(Map<String, dynamic> booking) {
  final stored = _asNum(booking['balance_amount']);
  if (stored > 0) return stored;
  final total = _asNum(booking['total_amount']);
  final deposit = _depositAmount(booking);
  final balance = total - deposit;
  return balance < 0 ? 0 : balance;
}

DateTime? _balanceDueDate(Map<String, dynamic> booking) {
  final stored = textOf(booking['balance_due_at']);
  if (stored.isNotEmpty) {
    final parsed = DateTime.tryParse(stored);
    if (parsed != null) return parsed;
  }
  final schedule = asMap(booking['schedule']);
  final depDate = scheduleDepartsAt(schedule) ??
      DateTime.tryParse(textOf(schedule['departure_date']));
  if (depDate == null) return null;
  return depDate.subtract(const Duration(days: 15));
}

String _balanceDueDateText(Map<String, dynamic> booking) {
  final date = _balanceDueDate(booking);
  if (date == null) return '-';
  return DateFormat('d MMM yyyy', 'th_TH').format(date);
}

int _depositPercentApprox(Map<String, dynamic> booking) {
  final total = _asNum(booking['total_amount']);
  if (total <= 0) return 0;
  final deposit = _depositAmount(booking);
  return ((deposit / total) * 100).round();
}

/// True when the booking is on a deposit plan and the balance has not been paid yet.
bool _balanceUnpaid(Map<String, dynamic> booking) {
  if (textOf(booking['payment_type']) != 'deposit') return false;
  if (textOf(booking['balance_paid_at']).isNotEmpty) return false;
  return _asNum(booking['balance_amount']) > 0;
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

/// The actual installment record (id/amount/due_date/status) for a given number.
Map<String, dynamic> _installmentRecord(Map<String, dynamic> booking, int no) {
  for (final item in asList(booking['installment_payments'])) {
    final inst = asMap(item);
    if ((int.tryParse(textOf(inst['installment_no'])) ?? -1) == no) {
      return inst;
    }
  }
  return <String, dynamic>{};
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
