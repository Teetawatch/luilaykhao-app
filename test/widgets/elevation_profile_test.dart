import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/widgets/elevation_profile_chart.dart';

void main() {
  Map<String, dynamic> track({
    bool hasElevation = true,
    List<Map<String, dynamic>>? points,
  }) => {
    'has_elevation': hasElevation,
    'distance_km': 2.2,
    'elevation_gain_m': 440,
    'elevation_loss_m': 40,
    'max_elevation_m': 900,
    'min_elevation_m': 500,
    'steepest': {
      'from_km': 1.1,
      'to_km': 1.7,
      'rise_m': 240,
      'grade_percent': 43.2,
    },
    'points':
        points ??
        [
          {'lat': 18.5, 'lng': 98.5, 'ele': 500, 'km': 0},
          {'lat': 18.51, 'lng': 98.5, 'ele': 700, 'km': 1.1},
          {'lat': 18.52, 'lng': 98.5, 'ele': 900, 'km': 2.2},
        ],
  };

  group('RouteTrack.parse', () {
    test('reads the profile the backend sends', () {
      final parsed = RouteTrack.parse(track())!;

      expect(parsed.points, hasLength(3));
      expect(parsed.points.first.km, 0);
      expect(parsed.points.last.elevation, 900);
      expect(parsed.elevationGainM, 440);
      expect(parsed.elevationLossM, 40);
      expect(parsed.steepest!.gradePercent, 43.2);
      expect(parsed.steepest!.riseM, 240);
    });

    test('hides itself when the route carries no elevation', () {
      expect(RouteTrack.parse(track(hasElevation: false)), isNull);
    });

    test('hides itself when there are too few points to draw a line', () {
      final single = track(
        points: [
          {'lat': 18.5, 'lng': 98.5, 'ele': 500, 'km': 0},
        ],
      );
      expect(RouteTrack.parse(single), isNull);
    });

    test('skips points with a missing height instead of plotting them at zero', () {
      final gappy = track(
        points: [
          {'lat': 18.5, 'lng': 98.5, 'ele': 500, 'km': 0},
          {'lat': 18.51, 'lng': 98.5, 'ele': null, 'km': 1.1},
          {'lat': 18.52, 'lng': 98.5, 'ele': 900, 'km': 2.2},
        ],
      );

      final parsed = RouteTrack.parse(gappy)!;
      expect(parsed.points, hasLength(2));
      expect(parsed.points.map((p) => p.elevation), [500, 900]);
    });

    test('returns null for anything that is not a track', () {
      expect(RouteTrack.parse(null), isNull);
      expect(RouteTrack.parse('nope'), isNull);
      expect(RouteTrack.parse(const {}), isNull);
    });

    test('tolerates a track with no steepest segment', () {
      final flat = Map<String, dynamic>.from(track())..remove('steepest');
      expect(RouteTrack.parse(flat)!.steepest, isNull);
    });
  });
}
