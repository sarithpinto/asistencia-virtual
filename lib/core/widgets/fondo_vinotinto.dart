import 'package:flutter/material.dart';

import 'package:asistencia_qr/core/theme/app_theme.dart';

class FondoVinotinto extends StatelessWidget {
  final Widget child;

  const FondoVinotinto({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            vinotintoOscuro,
            vinotintoMedio,
            vinotintoPrincipal,
            vinotintoOscuro,
          ],
          stops: [0.0, 0.35, 0.65, 1.0],
        ),
      ),
      child: child,
    );
  }
}
