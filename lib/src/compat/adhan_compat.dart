import 'package:adhan_dart/adhan_dart.dart';

// Compatibility layer for older fork-specific API used in this project.

/// Enum used by the app originally. Map these to real CalculationMethodParameters.
enum CalculationMethodEnum {
  muslimWorldLeague,
  egyptian,
  karachi,
  ummAlQura,
  dubai,
  qatar,
  kuwait,
  moonsightingCommittee,
  singapore,
  turkiye,
  tehran,
  northAmerica,
  other,
}

/// Convert the app's enum to the real `CalculationParameters` from `adhan_dart`.
CalculationParameters calcParamsFromEnum(CalculationMethodEnum method) {
  switch (method) {
    case CalculationMethodEnum.muslimWorldLeague:
      return CalculationMethodParameters.muslimWorldLeague();
    case CalculationMethodEnum.egyptian:
      return CalculationMethodParameters.egyptian();
    case CalculationMethodEnum.karachi:
      return CalculationMethodParameters.karachi();
    case CalculationMethodEnum.ummAlQura:
      return CalculationMethodParameters.ummAlQura();
    case CalculationMethodEnum.dubai:
      return CalculationMethodParameters.dubai();
    case CalculationMethodEnum.qatar:
      return CalculationMethodParameters.qatar();
    case CalculationMethodEnum.kuwait:
      return CalculationMethodParameters.kuwait();
    case CalculationMethodEnum.moonsightingCommittee:
      return CalculationMethodParameters.moonsightingCommittee();
    case CalculationMethodEnum.singapore:
      return CalculationMethodParameters.singapore();
    case CalculationMethodEnum.turkiye:
      return CalculationMethodParameters.turkiye();
    case CalculationMethodEnum.tehran:
      return CalculationMethodParameters.tehran();
    case CalculationMethodEnum.northAmerica:
      return CalculationMethodParameters.northAmerica();
    case CalculationMethodEnum.other:
    default:
      return CalculationMethodParameters.other();
  }
}

extension PrayerTimesCompat on PrayerTimes {
  /// Returns Duration until next prayer, or null if unavailable.
  Duration? timeUntilNextPrayer({DateTime? now}) {
    final DateTime tNow = now ?? DateTime.now();
    final Prayer? next = nextPrayer(date: tNow);
    if (next == null) return null;
    final DateTime? nextTime = timeForPrayer(next);
    if (nextTime == null) return null;
    return nextTime.difference(tNow);
  }

  /// Returns fraction (0.0-1.0) of time left until next prayer, or null.
  double? percentageOfTimeLeftUntilNextPrayer({DateTime? now}) {
    final DateTime tNow = now ?? DateTime.now();
    final Prayer? next = nextPrayer(date: tNow);
    final Prayer? current = currentPrayer(date: tNow);
    if (next == null || current == null) return null;
    final DateTime? nextTime = timeForPrayer(next);
    final DateTime? currentTime = timeForPrayer(current);
    if (nextTime == null || currentTime == null) return null;
    final total = nextTime.difference(currentTime).inSeconds;
    if (total <= 0) return null;
    final left = nextTime.difference(tNow).inSeconds;
    return left / total;
  }

  /// Return simple sentinel if now is inside a forbidden time, otherwise null.
  /// This mirrors older behavior where null meant "not forbidden".
  String? isInsideForbiddenTimeSimple(DateTime now) {
    // Sunrise forbidden window: sunrise .. sunrise + 15min
    if (now.isAfter(sunrise) && now.isBefore(sunrise.add(const Duration(minutes: 15)))) {
      return 'sunrise';
    }
    // Noon forbidden: dhuhr - 8min .. dhuhr
    if (now.isAfter(dhuhr.subtract(const Duration(minutes: 8))) && now.isBefore(dhuhr)) {
      return 'noon';
    }
    // Sunset forbidden: maghrib - 15min .. maghrib
    if (now.isAfter(maghrib.subtract(const Duration(minutes: 15))) && now.isBefore(maghrib)) {
      return 'sunset';
    }
    return null;
  }

  /// Approximate `tahajjud` time as the last third of the night midpoint.
  DateTime get tahajjud {
    final SunnahTimes s = SunnahTimes(this);
    return s.lastThirdOfTheNight;
  }

  /// Approximate `dhuha` as midpoint between sunrise and dhuhr.
  DateTime get dhuha => DateTime.fromMillisecondsSinceEpoch(
        sunrise.millisecondsSinceEpoch + (dhuhr.millisecondsSinceEpoch - sunrise.millisecondsSinceEpoch) ~/ 2,
      );

  /// noon maps to dhuhr
  DateTime get noon => dhuhr;

  /// sunset maps to maghrib
  DateTime get sunset => maghrib;
}
