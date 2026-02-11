class QiblaInfo {
  final double bearingDegrees; // 0..360, from north clockwise
  final double distanceMeters; // optional distance to Kaaba

  QiblaInfo({required this.bearingDegrees, required this.distanceMeters});
}
