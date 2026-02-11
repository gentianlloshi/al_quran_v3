import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/qibla_model.dart';
import '../services/qibla_service.dart';
import '../../prayer_time/services/location_service.dart';

class QiblaState {
  final QiblaInfo? qibla;
  final double? deviceHeading; // degrees from north
  final bool loading;
  final String? error;
  QiblaState({this.qibla, this.deviceHeading, this.loading = false, this.error});
}

class QiblaCubit extends Cubit<QiblaState> {
  final QiblaService service;
  QiblaCubit(this.service) : super(QiblaState());

  Future<void> load() async {
    emit(QiblaState(loading: true));
    try {
      final pos = await LocationService.getCurrentPosition();
      final q = service.compute(pos.latitude, pos.longitude);
      emit(QiblaState(qibla: q, loading: false));
    } catch (e) {
      emit(QiblaState(error: e.toString()));
    }
  }

  void updateHeading(double heading) {
    emit(QiblaState(qibla: state.qibla, deviceHeading: heading));
  }
}
