import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';

import 'package:asistencia_qr/core/theme/app_theme.dart';
import 'package:asistencia_qr/core/theme/app_styles.dart';
import 'package:asistencia_qr/core/widgets/fondo_vinotinto.dart';

class EscanearQrScreen extends StatefulWidget {
  const EscanearQrScreen({super.key});

  @override
  State<EscanearQrScreen> createState() => _EscanearQrScreenState();
}

class _EscanearQrScreenState extends State<EscanearQrScreen> {
  final MobileScannerController _controlador = MobileScannerController();
  final NetworkInfo _informacionRed = NetworkInfo();

  bool _procesando = false;
  bool _asistenciaRegistrada = false;

  static const double _radioPermitidoMetros = 25;

  static const Set<String> _redesInstitucionales = {
    '#SOYUTEISTA',
    '#SOYUTEISTA_5G',
  };

  String _mensaje = 'Apunta la cámara al código QR del docente.';
  String _pasoActual = 'iniciar';

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  // Normaliza el SSID porque Android puede devolverlo entre comillas.
  String _normalizarNombreRed(String nombre) {
    return nombre.replaceAll('"', '').trim();
  }

  // Verifica que el dispositivo esté conectado a una red institucional.
  Future<void> _verificarRedInstitucional() async {
    String? nombreRed;

    try {
      nombreRed = await _informacionRed.getWifiName();
    } catch (e) {
      debugPrint('ERROR AL CONSULTAR WIFI: $e');
      throw Exception(
        'No fue posible comprobar la red Wi-Fi. '
        'Verifica que el Wi-Fi y la ubicación estén activados.',
      );
    }

    if (nombreRed == null || nombreRed.trim().isEmpty) {
      throw Exception(
        'No se pudo identificar la red Wi-Fi. '
        'Conéctate a la red institucional y verifica que la ubicación '
        'de tu celular esté activada.',
      );
    }

    final redActual = _normalizarNombreRed(nombreRed);

    debugPrint('RED WIFI DETECTADA: $redActual');

    if (!_redesInstitucionales.contains(redActual)) {
      throw Exception(
        'No estás conectado a la red institucional.\n\n'
        'Conéctate a #SOYUTEISTA o #SOYUTEISTA_5G '
        'para registrar tu asistencia.\n\n'
        'Red detectada: $redActual',
      );
    }
  }

  Future<void> _verificarUbicacion(
    double latitudDocente,
    double longitudDocente,
  ) async {
    final servicioActivo = await Geolocator.isLocationServiceEnabled();

    if (!servicioActivo) {
      throw Exception(
        'Activa la ubicación GPS de tu celular para registrar la asistencia.',
      );
    }

    LocationPermission permiso = await Geolocator.checkPermission();

    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    if (permiso == LocationPermission.denied) {
      throw Exception(
        'Debes permitir el acceso a la ubicación para registrar asistencia.',
      );
    }

    if (permiso == LocationPermission.deniedForever) {
      throw Exception(
        'El permiso GPS está bloqueado. '
        'Actívalo desde los ajustes de la aplicación.',
      );
    }

    final posicionEstudiante = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );

    debugPrint(
      'GPS ESTUDIANTE: '
      'lat=${posicionEstudiante.latitude}, '
      'lon=${posicionEstudiante.longitude}, '
      'precision=${posicionEstudiante.accuracy} metros',
    );

    if (posicionEstudiante.accuracy > 100) {
      throw Exception(
        'La ubicación GPS no es suficientemente precisa '
        '(${posicionEstudiante.accuracy.toStringAsFixed(0)} m). '
        'Intenta nuevamente en un lugar con mejor señal.',
      );
    }

    final distancia = Geolocator.distanceBetween(
      posicionEstudiante.latitude,
      posicionEstudiante.longitude,
      latitudDocente,
      longitudDocente,
    );

    if (distancia > _radioPermitidoMetros) {
      throw Exception(
        'Estás fuera del rango permitido del docente. '
        'Distancia aproximada: ${distancia.toStringAsFixed(1)} metros. '
        'Distancia máxima: '
        '${_radioPermitidoMetros.toStringAsFixed(0)} metros.',
      );
    }
  }

  Future<bool> _verificarInscripcion({
    required FirebaseFirestore firestore,
    required String estudianteId,
    required String claseId,
  }) async {
    final consulta = await firestore
        .collection('inscripciones')
        .where('estudianteId', isEqualTo: estudianteId)
        .get();

    return consulta.docs.any((documento) {
      final datos = documento.data();

      return datos['claseId'] == claseId && datos['estado'] == 'Activa';
    });
  }

  Future<void> _procesarCodigo(String codigo) async {
    if (_procesando || _asistenciaRegistrada) return;

    _procesando = true;
    _pasoActual = 'consultar perfil';

    if (mounted) {
      setState(() {
        _mensaje = 'Verificando el código QR...';
      });
    }

    try {
      final usuario = FirebaseAuth.instance.currentUser;

      if (usuario == null) {
        throw Exception('Debes iniciar sesión para registrar asistencia.');
      }

      final firestore = FirebaseFirestore.instance;

      // 1. Verificar el perfil del estudiante.
      final perfil = await firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .get();

      if (!perfil.exists || perfil.data()?['rol'] != 'Estudiante') {
        throw Exception('Esta función está disponible para estudiantes.');
      }

      // 2. Buscar una sesión QR activa.
      _pasoActual = 'buscar QR';

      final consulta = await firestore
          .collection('sesiones_qr')
          .where('token', isEqualTo: codigo)
          .where('activa', isEqualTo: true)
          .limit(1)
          .get();

      if (consulta.docs.isEmpty) {
        throw Exception('El QR no es válido o la sesión ya no está activa.');
      }

      final sesion = consulta.docs.first;
      final datos = sesion.data();

      final expiracion = datos['fechaExpiracion'];

      if (expiracion is! Timestamp) {
        throw Exception(
          'La sesión QR no tiene una fecha de vencimiento válida.',
        );
      }

      // Comprobar que el QR todavía no haya vencido.
      if (expiracion.toDate().isBefore(DateTime.now())) {
        throw Exception(
          'Este código QR ya venció. '
          'Solicita al docente que genere uno nuevo.',
        );
      }

      final claseId = datos['claseId'];
      final salon = datos['salon'];
      final docenteId = datos['docenteId'];

      final latitudDocente = datos['latitudDocente'];
      final longitudDocente = datos['longitudDocente'];

      if (latitudDocente is! num || longitudDocente is! num) {
        throw Exception(
          'La sesión QR no tiene una ubicación válida del docente. '
          'Pídele que genere un nuevo código QR.',
        );
      }

      if (claseId is! String || salon is! String || docenteId is! String) {
        throw Exception('La sesión QR contiene datos incompletos.');
      }

      // 3. Verificar la inscripción del estudiante.
      _pasoActual = 'verificar inscripción';

      if (mounted) {
        setState(() {
          _mensaje = 'Verificando tu inscripción en la clase...';
        });
      }

      final estaInscrito = await _verificarInscripcion(
        firestore: firestore,
        estudianteId: usuario.uid,
        claseId: claseId,
      );

      if (!estaInscrito) {
        throw Exception(
          'No estás inscrito en esta clase. '
          'Entra en "Mis clases" e inscríbete antes de registrar '
          'tu asistencia.',
        );
      }

      // 4. Verificar la ubicación GPS.
      _pasoActual = 'verificar ubicación';

      if (mounted) {
        setState(() {
          _mensaje = 'Verificando tu ubicación GPS...';
        });
      }

      await _verificarUbicacion(
        latitudDocente.toDouble(),
        longitudDocente.toDouble(),
      );

      // 5. Verificar la red institucional.
      _pasoActual = 'verificar red institucional';

      if (mounted) {
        setState(() {
          _mensaje = 'Comprobando la conexión institucional...';
        });
      }

      await _verificarRedInstitucional();

      // 6. Preparar un registro único por estudiante y sesión.
      final asistenciaId = '${sesion.id}_${usuario.uid}';

      final referencia = firestore.collection('asistencias').doc(asistenciaId);

      // 7. Comprobar si ya existe la asistencia.
      _pasoActual = 'consultar asistencia existente';

      final existente = await referencia.get();

      if (existente.exists) {
        if (mounted) {
          setState(() {
            _asistenciaRegistrada = true;
            _mensaje = 'Ya registraste tu asistencia a esta sesión.';
          });
        }
        return;
      }

      // 8. Guardar la asistencia usando la hora del servidor.
      _pasoActual = 'guardar asistencia';

      await referencia.set({
        'estudianteId': usuario.uid,
        'sesionId': sesion.id,
        'claseId': claseId,
        'salon': salon,
        'docenteId': docenteId,
        'fechaRegistro': FieldValue.serverTimestamp(),
        'estado': 'Presente',
        'redInstitucional': _normalizarNombreRed(
          (await _informacionRed.getWifiName()) ?? '',
        ),
      });

      if (mounted) {
        setState(() {
          _asistenciaRegistrada = true;
          _mensaje = '¡Asistencia registrada correctamente!';
        });
      }
    } on FirebaseException catch (e) {
      debugPrint('ERROR FIREBASE: ${e.code} - ${e.message}');

      if (mounted) {
        setState(() {
          _mensaje =
              'Firebase rechazó la operación.\n\n'
              'Paso: $_pasoActual\n'
              'Código: ${e.code}\n'
              'Detalle: ${e.message ?? 'Sin detalle adicional'}';
        });
      }
    } catch (e) {
      debugPrint('ERROR ASISTENCIA: $e');

      if (mounted) {
        setState(() {
          _mensaje = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      _procesando = false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Escanear código QR',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: crema,
        foregroundColor: verde,
      ),
      body: FondoVinotinto(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const SizedBox(height: 12),
              const Icon(Icons.qr_code_scanner_rounded, color: crema, size: 58),
              const SizedBox(height: 14),
              const Text(
                'Registra tu asistencia',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: crema,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Escanea el código QR que muestra tu docente. '
                'Recuerda que es temporal.',
                textAlign: TextAlign.center,
                style: TextStyle(color: crema, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 26),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppStyles.radioEscaner),
                child: Container(
                  height: 330,
                  color: Colors.black,
                  child: _asistenciaRegistrada
                      ? const Center(
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF8BC79B),
                            size: 100,
                          ),
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            MobileScanner(
                              controller: _controlador,
                              onDetect: (captura) {
                                if (_procesando || _asistenciaRegistrada) {
                                  return;
                                }

                                for (final codigo in captura.barcodes) {
                                  final valor = codigo.rawValue;

                                  if (valor != null && valor.isNotEmpty) {
                                    _procesarCodigo(valor);
                                    break;
                                  }
                                }
                              },
                            ),
                            IgnorePointer(
                              child: Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF8BC79B),
                                    width: 4,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppStyles.radioMarcoEscaner,
                                  ),
                                ),
                              ),
                            ),
                            if (_procesando)
                              Container(
                                color: Colors.black45,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: crema,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: AppStyles.paddingEstado,
                decoration: BoxDecoration(
                  color: crema,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Icon(
                      _asistenciaRegistrada
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      color: verde,
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _mensaje,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: verde,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    if (_asistenciaRegistrada) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Volver al menú'),
                        style: FilledButton.styleFrom(
                          backgroundColor: verde,
                          foregroundColor: crema,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
