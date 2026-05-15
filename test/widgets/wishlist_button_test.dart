import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/providers/wishlist_provider.dart';
import 'package:luilaykhao_app/widgets/wishlist_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, WishlistProvider provider) {
  return ChangeNotifierProvider<WishlistProvider>.value(
    value: provider,
    child: MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows outline heart when not in wishlist', (tester) async {
    final provider = WishlistProvider();
    await provider.load();

    await tester.pumpWidget(_wrap(
      const WishlistButton(trip: {'slug': 'a', 'title': 'A'}),
      provider,
    ));
    await tester.pump();

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
  });

  testWidgets('flips to filled heart after tap', (tester) async {
    final provider = WishlistProvider();
    await provider.load();

    await tester.pumpWidget(_wrap(
      const WishlistButton(trip: {'slug': 'a', 'title': 'A'}),
      provider,
    ));
    await tester.pump();

    await tester.tap(find.byType(WishlistButton));
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(provider.contains('a'), isTrue);
  });

  testWidgets('renders nothing when trip has no slug', (tester) async {
    final provider = WishlistProvider();
    await provider.load();

    await tester.pumpWidget(_wrap(
      const WishlistButton(trip: {'title': 'no slug'}),
      provider,
    ));
    await tester.pump();

    expect(find.byType(InkWell), findsNothing);
  });
}
