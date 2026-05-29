import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-booking pre-trip checklist state, persisted locally.
///
/// The checklist is intentionally device-local: the items themselves come from
/// the trip's `preparations` (shared by everyone), while what each traveller
/// has ticked off — and any personal items they add — is private and used only
/// to nudge themselves before departure. Keeping it on-device avoids a backend
/// round-trip, works offline, and matches the "personal" framing.
class ChecklistState {
  /// Labels of trip-provided preparation items the user has checked.
  final Set<String> checkedPrep;

  /// User-added personal items, each with its own checked flag.
  final List<ChecklistCustomItem> customItems;

  const ChecklistState({
    this.checkedPrep = const {},
    this.customItems = const [],
  });

  static const empty = ChecklistState();

  ChecklistState copyWith({
    Set<String>? checkedPrep,
    List<ChecklistCustomItem>? customItems,
  }) {
    return ChecklistState(
      checkedPrep: checkedPrep ?? this.checkedPrep,
      customItems: customItems ?? this.customItems,
    );
  }

  Map<String, dynamic> toJson() => {
    'checked_prep': checkedPrep.toList(),
    'custom_items': customItems.map((e) => e.toJson()).toList(),
  };

  factory ChecklistState.fromJson(Map<String, dynamic> json) {
    return ChecklistState(
      checkedPrep: (json['checked_prep'] as List? ?? [])
          .map((e) => e.toString())
          .toSet(),
      customItems: (json['custom_items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ChecklistCustomItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class ChecklistCustomItem {
  final String id;
  final String label;
  final bool checked;

  const ChecklistCustomItem({
    required this.id,
    required this.label,
    this.checked = false,
  });

  ChecklistCustomItem copyWith({String? label, bool? checked}) {
    return ChecklistCustomItem(
      id: id,
      label: label ?? this.label,
      checked: checked ?? this.checked,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'checked': checked,
  };

  factory ChecklistCustomItem.fromJson(Map<String, dynamic> json) {
    return ChecklistCustomItem(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      checked: json['checked'] == true,
    );
  }
}

class ChecklistStorage {
  ChecklistStorage._();
  static final ChecklistStorage instance = ChecklistStorage._();

  static String _key(String bookingRef) => 'checklist_v1_$bookingRef';

  /// Legacy key used by the in-sheet checklist before this feature — a plain
  /// StringList of checked preparation labels. Read once and folded into the
  /// new format so users don't lose what they'd already ticked.
  static String _legacyKey(String bookingRef) => 'prep_checklist_$bookingRef';

  Future<ChecklistState> read(String bookingRef) async {
    if (bookingRef.isEmpty) return ChecklistState.empty;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(bookingRef));
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return ChecklistState.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    // Fall back to the legacy checklist the first time around.
    final legacy = prefs.getStringList(_legacyKey(bookingRef));
    if (legacy != null && legacy.isNotEmpty) {
      return ChecklistState(checkedPrep: legacy.toSet());
    }
    return ChecklistState.empty;
  }

  Future<void> write(String bookingRef, ChecklistState state) async {
    if (bookingRef.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(bookingRef), jsonEncode(state.toJson()));
  }

  Future<void> clear(String bookingRef) async {
    if (bookingRef.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(bookingRef));
  }
}
