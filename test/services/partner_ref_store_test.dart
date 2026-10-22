import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/services/partner_ref_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('normalizes the code the same way the server does', () {
    expect(PartnerRefStore.normalize(' page-pa 1 '), 'PAGEPA1');
    expect(PartnerRefStore.normalize(null), '');
    expect(PartnerRefStore.normalize('A' * 30).length, 20);
  });

  test('the latest link wins and keeps its source', () async {
    await PartnerRefStore.remember('first');
    await PartnerRefStore.remember('second', source: 'code');

    final ref = await PartnerRefStore.read();
    expect(ref?.code, 'SECOND');
    expect(ref?.source, 'code');
  });

  test('blank codes are ignored', () async {
    await PartnerRefStore.remember('keep');
    await PartnerRefStore.remember('  ');

    expect((await PartnerRefStore.read())?.code, 'KEEP');
  });

  test('a code older than 30 days is dropped', () async {
    SharedPreferences.setMockInitialValues({
      'partner_ref_v1': jsonEncode({
        'code': 'OLD',
        'source': 'link',
        'at': DateTime.now()
            .subtract(const Duration(days: 31))
            .toIso8601String(),
      }),
    });

    expect(await PartnerRefStore.read(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('partner_ref_v1'), isNull);
  });
}
