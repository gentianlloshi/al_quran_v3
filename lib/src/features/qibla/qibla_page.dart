import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cubit/qibla_cubit.dart';
import 'services/qibla_service.dart';
import 'widgets/qibla_compass.dart';

class QiblaPage extends StatelessWidget {
  const QiblaPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => QiblaCubit(QiblaService())..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Qibla')),
        body: Center(
          child: BlocBuilder<QiblaCubit, QiblaState>(builder: (context, state) {
            if (state.loading) return const CircularProgressIndicator();
            if (state.error != null) return Text('Error: ${state.error}');
            if (state.qibla == null) return const Text('No Qibla data');

            final q = state.qibla!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QiblaCompass(bearingToQibla: q.bearingDegrees),
                const SizedBox(height: 16),
                Text('Bearing: ${q.bearingDegrees.toStringAsFixed(1)}°'),
                const SizedBox(height: 8),
                Text('Distance: ${(q.distanceMeters/1000).toStringAsFixed(2)} km'),
              ],
            );
          }),
        ),
      ),
    );
  }
}
