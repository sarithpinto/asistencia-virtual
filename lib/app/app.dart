import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:asistencia_qr/core/theme/app_theme.dart';
import 'package:asistencia_qr/screens/auth/login_screen.dart';
import 'providers.dart';

class AsistenciaVirtualApp extends StatelessWidget {
  const AsistenciaVirtualApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: obtenerProviders(),
      child: MaterialApp(
        title: 'Asistencia Virtual',
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        home: const LoginScreen(),
      ),
    );
  }
}
