import 'package:flutter/material.dart';

/// Pads a small control out to the 44dp minimum touch target **without
/// changing how it looks**.
///
/// Several controls in the app — the search-field clear button, star pickers,
/// close buttons on sheets — were drawn at 20–36dp and tapped at that size
/// too. Both Apple (44pt) and Material (48dp) put the floor well above that,
/// and the gap shows up as taps that miss.
///
/// The child keeps its own size: [SizedBox] takes the 44dp box and [Center]
/// hands the child loose constraints, so only the *hit* area grows. Pair it
/// with `HitTestBehavior.opaque` on a [GestureDetector] so the transparent
/// margin around the glyph is tappable too — an [InkWell] already fills its
/// box, and gets a correctly sized ripple as a bonus.
class MinTapTarget extends StatelessWidget {
  /// The floor both platforms agree is reachable.
  static const double minSize = 44;

  final Widget child;

  /// What a screen reader should announce. An icon-only control has no text to
  /// fall back on, so without this TalkBack/VoiceOver reads nothing at all.
  final String? semanticLabel;

  const MinTapTarget({super.key, required this.child, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final box = SizedBox(
      width: minSize,
      height: minSize,
      child: Center(child: child),
    );
    if (semanticLabel == null) return box;
    return Semantics(button: true, label: semanticLabel, child: box);
  }
}
