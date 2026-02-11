import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

class QiblaCompass extends StatefulWidget {
  final double bearingToQibla; // degrees 0..360
  const QiblaCompass({Key? key, required this.bearingToQibla}) : super(key: key);

  @override
  State<QiblaCompass> createState() => _QiblaCompassState();
}

class _QiblaCompassState extends State<QiblaCompass> {
  double _heading = 0; // device heading
  StreamSubscription<double?>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        setState(() => _heading = event.heading!);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Compute rotation so needle points to Qibla
    final rotationDegrees = (widget.bearingToQibla - _heading + 360) % 360;
    final rotation = rotationDegrees * (math.pi / 180);

    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
          ),
          Transform.rotate(
            angle: rotation,
            child: Icon(Icons.navigation, size: 120, color: Colors.redAccent),
          ),
          Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle)),
        ],
      ),
    );
  }
}
