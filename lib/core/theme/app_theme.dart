import 'package:flutter/material.dart';

// =====================================================
// PALETA DE COLORES
// =====================================================

const Color vinotintoOscuro = Color(0xFF200D0D);
const Color vinotintoMedio = Color(0xFF431C1C);
const Color vinotintoPrincipal = Color(0xFF4B1818);

const Color crema = Color(0xFFF5EFE6);
const Color verde = Color(0xFF0E2E20);
const Color cremaClaro = Color(0xFFFCF9F4);
const Color bordeCrema = Color(0xFFD8CCBC);

// =====================================================
// TEMA GENERAL DE LA APLICACIÓN
// =====================================================

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: crema,
  colorScheme: ColorScheme.fromSeed(
    seedColor: verde,
    primary: verde,
    surface: crema,
  ),
  fontFamily: 'Roboto',
  appBarTheme: const AppBarTheme(
    backgroundColor: crema,
    foregroundColor: verde,
    elevation: 0,
  ),
);
