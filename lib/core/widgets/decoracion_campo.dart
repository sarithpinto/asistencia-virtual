import 'package:flutter/material.dart';

import 'package:asistencia_qr/core/theme/app_theme.dart';

InputDecoration decoracionCampo(
  String etiqueta,
  IconData icono, {
  String? sugerencia,
  Widget? sufijo,
}) {
  return InputDecoration(
    labelText: etiqueta,
    hintText: sugerencia,
    labelStyle: const TextStyle(color: vinotintoMedio),
    hintStyle: const TextStyle(color: Color(0xFF81776C)),
    prefixIcon: Icon(icono, color: verde),
    suffixIcon: sufijo,
    filled: true,
    fillColor: cremaClaro,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: bordeCrema),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: bordeCrema),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: verde, width: 1.7),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
  );
}
