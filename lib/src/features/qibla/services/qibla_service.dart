import 'dart:math' as math;

import '../models/qibla_model.dart';

class QiblaService {
  static const _kaabaLat = 21.422487;
  static const _kaabaLon = 39.826206;

  QiblaInfo compute(double lat, double lon) {
    final bearing = _calculateBearing(lat, lon, _kaabaLat, _kaabaLon);
    final distance = _haversineDistanceMeters(lat, lon, _kaabaLat, _kaabaLon);
    return QiblaInfo(bearingDegrees: bearing, distanceMeters: distance);
  }

  double _toRad(double deg) => deg * math.pi / 180.0;
  double _toDeg(double rad) => rad * 180.0 / math.pi;

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final phi1 = _toRad(lat1);
    final phi2 = _toRad(lat2);
    final deltaLambda = _toRad(lon2 - lon1);

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
    var theta = math.atan2(y, x);
    var bearing = (_toDeg(theta) + 360.0) % 360.0;
    return bearing;
  }

  double _haversineDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }
}
