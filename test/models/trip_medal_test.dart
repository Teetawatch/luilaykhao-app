import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/models/trip_medal.dart';

Map<String, dynamic> medalJson({Map<String, dynamic> overrides = const {}}) => {
  'id': 7,
  'seen': false,
  'booking_ref': 'LLK-20260902-0001',
  'finisher_no': 27,
  'finisher_label': 'Finisher #27',
  'earned_on': '2026-09-05',
  'earned_label': '5 กันยายน 2569',
  'date_label': '2 – 5 กันยายน 2569',
  'holder_name': 'ต้น',
  'design': {
    'name': 'เดินป่าลาวใต้ ที่ราบสูงโบลาเวน',
    'icon': 'coffee',
    'color': '#7C4A2D',
    'image_url': null,
    'is_custom': false,
  },
  'trip': {
    'id': 3,
    'title': 'เดินป่าลาวใต้ ที่ราบสูงโบลาเวน 4 วัน 3 คืน',
    'slug': 'bolaven',
    'location': 'ปากเซ',
    'country_flag': '🇱🇦',
    'country_name': 'ลาว',
    'distance_km': 32.5,
    'elevation_gain_m': 1200,
    'duration_days': 4,
    'cover_image': 'https://media.example/cover.jpg',
  },
  'attempt': 2,
  'attempts_of_trip': 3,
  'share_url': 'https://luilaykhao.com/m/abc123',
  ...overrides,
};

void main() {
  test('อ่านเหรียญครบทุกช่องจาก API', () {
    final medal = TripMedal.fromJson(medalJson());

    expect(medal.id, 7);
    expect(medal.seen, isFalse);
    expect(medal.finisherNo, 27);
    expect(medal.finisherLabel, 'Finisher #27');
    expect(medal.earnedOn, DateTime(2026, 9, 5));
    expect(medal.holderName, 'ต้น');
    expect(medal.design.name, 'เดินป่าลาวใต้ ที่ราบสูงโบลาเวน');
    expect(medal.design.icon, 'coffee');
    expect(medal.design.color, const Color(0xFF7C4A2D));
    expect(medal.design.isCustom, isFalse);
    expect(medal.distanceKm, 32.5);
    expect(medal.elevationGainM, 1200);
    expect(medal.attempt, 2);
    expect(medal.attemptsOfTrip, 3);
    expect(medal.shareUrl, 'https://luilaykhao.com/m/abc123');
  });

  test('ทริปต่างประเทศใช้ธง+ชื่อประเทศเป็นบรรทัดสถานที่', () {
    expect(TripMedal.fromJson(medalJson()).placeLabel, '🇱🇦 ลาว');

    final domestic = TripMedal.fromJson(
      medalJson(
        overrides: {
          'trip': {'location': 'เชียงใหม่', 'country_flag': null},
        },
      ),
    );
    expect(domestic.placeLabel, 'เชียงใหม่');
  });

  test('ค่าที่ขาด/เสียไม่ทำให้พัง', () {
    final medal = TripMedal.fromJson(const {
      'id': '9',
      'finisher_no': '3',
      'date_label': '-',
      'design': {'color': 'not-a-colour', 'image_url': ''},
    });

    expect(medal.id, 9);
    expect(medal.finisherLabel, 'Finisher #3');
    expect(medal.dateLabel, isEmpty);
    expect(medal.holderName, 'นักเดินทาง');
    expect(medal.design.color, const Color(0xFF15803D));
    expect(medal.design.imageUrl, isNull);
    expect(medal.distanceKm, isNull);
    expect(medal.attempt, 1);
  });

  test('ภาพเหรียญออกแบบเองทำให้เป็นเหรียญ custom', () {
    final medal = TripMedal.fromJson(
      medalJson(
        overrides: {
          'design': {
            'name': 'พิชิตโบลาเวน',
            'icon': 'coffee',
            'color': '#7C4A2D',
            'image_url': 'https://media.example/medal.png',
          },
        },
      ),
    );

    expect(medal.design.isCustom, isTrue);
  });

  test('อ่านทรงและผิวเหรียญ — ทรงไม่รู้จัก = แบบของทริป', () {
    final medal = TripMedal.fromJson(
      medalJson(overrides: {'shape': 'shield', 'finish': 'platinum'}),
    );
    expect(medal.shape, MedalShape.shield);
    expect(medal.finish, MedalFinish.platinum);

    final unknown = TripMedal.fromJson(
      medalJson(overrides: {'shape': 'octagon', 'finish': 'diamond'}),
    );
    expect(unknown.shape, isNull);
    // ผิวไม่รู้จัก/เซิร์ฟเวอร์เก่า: คิดจากครั้งที่เอง (ครั้งที่ 2 = ทอง)
    expect(unknown.finish, MedalFinish.gold);

    final fifth = TripMedal.fromJson(medalJson(overrides: {'attempt': 5}));
    expect(fifth.finish, MedalFinish.obsidian);
  });

  test('ผิวตามครั้งที่: 1–2 ทอง · 3–4 แพลทินัม · 5+ ดำทอง', () {
    expect(
      [for (var i = 1; i <= 6; i++) MedalFinish.forAttempt(i)],
      [
        MedalFinish.gold,
        MedalFinish.gold,
        MedalFinish.platinum,
        MedalFinish.platinum,
        MedalFinish.obsidian,
        MedalFinish.obsidian,
      ],
    );
    expect(MedalFinish.gold.next, MedalFinish.platinum);
    expect(MedalFinish.obsidian.next, isNull);
  });

  test('เปลี่ยนทรง/ทำเครื่องหมายเห็นแล้ว ไม่ทำข้อมูลอื่นหาย', () {
    final medal = TripMedal.fromJson(
      medalJson(overrides: {'shape': 'coin', 'finish': 'platinum'}),
    );

    final seen = medal.markSeen();
    expect(seen.seen, isTrue);
    expect(seen.shape, MedalShape.coin);
    expect(seen.finish, MedalFinish.platinum);

    final reshaped = seen.withShape(MedalShape.hexagon);
    expect(reshaped.shape, MedalShape.hexagon);
    expect(reshaped.seen, isTrue);
    expect(reshaped.finisherNo, 27);
    expect(seen.withShape(null).shape, isNull);
  });

  test('ตู้เหรียญนับเหรียญที่ยังไม่เห็น และทำเครื่องหมายเห็นแล้วได้', () {
    final cabinet = MedalCabinet.fromJson({
      'medals': [
        medalJson(),
        medalJson(overrides: {'id': 8, 'seen': true}),
        'garbage',
      ],
      'trips_count': 1,
    });

    expect(cabinet.medals, hasLength(2));
    expect(cabinet.unseen.map((m) => m.id), [7]);
    expect(cabinet.markAllSeen().unseen, isEmpty);
    expect(cabinet.tripsCount, 1);
  });
}
