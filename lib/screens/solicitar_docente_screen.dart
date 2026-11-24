import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:asistencia_qr/core/theme/app_theme.dart';
import 'package:asistencia_qr/core/widgets/fondo_vinotinto.dart';

class SolicitarDocenteScreen extends StatefulWidget {
  const SolicitarDocenteScreen({super.key});

  @override
  State<SolicitarDocenteScreen> createState() => _SolicitarDocenteScreenState();
}

class _SolicitarDocenteScreenState extends State<SolicitarDocenteScreen> {
  bool _cargando = true;
  bool _enviando = false;

  String _nombre = '';
  String _correo = '';
  String? _estadoSolicitud;
  String? _mensajeError;

  @override
  void initState() {
    super.initState();
    _cargarInformacion();
  }

  Future<void> _cargarInformacion() async {
    try {
      final usuario = FirebaseAuth.instance.currentUser;

      if (usuario == null) {
        throw Exception('No hay una sesión iniciada.');
      }

      final perfil = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .get();

      if (!perfil.exists) {
        throw Exception('No se encontró tu perfil de usuario.');
      }

      final datos = perfil.data()!;

      final solicitud = await FirebaseFirestore.instance
          .collection('solicitudes_docente')
          .doc(usuario.uid)
          .get();

      if (!mounted) return;

      setState(() {
        _nombre = datos['nombre']?.toString() ?? '';
        _correo = datos['correo']?.toString() ?? usuario.email ?? '';

        if (solicitud.exists) {
          _estadoSolicitud =
              solicitud.data()?['estado']?.toString() ?? 'Pendiente';
        }

        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _mensajeError = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _enviarSolicitud() async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) return;

    setState(() {
      _enviando = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('solicitudes_docente')
          .doc(usuario.uid)
          .set({
            'usuarioId': usuario.uid,
            'nombre': _nombre,
            'correo': _correo,
            'estado': 'Pendiente',
            'fechaSolicitud': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      setState(() {
        _estadoSolicitud = 'Pendiente';
        _enviando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu solicitud fue enviada correctamente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _enviando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar la solicitud: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _crearEstado(String titulo, String descripcion, IconData icono) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: crema,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icono, color: verde, size: 48),
          const SizedBox(height: 14),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: verde,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            descripcion,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: vinotintoMedio,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Solicitar ser docente',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: crema,
        foregroundColor: verde,
      ),
      body: FondoVinotinto(
        child: SafeArea(
          child: _cargando
              ? const Center(child: CircularProgressIndicator(color: crema))
              : ListView(
                  padding: const EdgeInsets.all(22),
                  children: [
                    const SizedBox(height: 15),
                    const Text(
                      'Solicitud de cambio de rol',
                      style: TextStyle(
                        color: crema,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Desde aquí puedes solicitar al administrador '
                      'que tu cuenta sea habilitada como docente.',
                      style: TextStyle(color: crema, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 25),
                    if (_mensajeError != null)
                      _crearEstado(
                        'No se pudo cargar tu información',
                        _mensajeError!,
                        Icons.error_outline_rounded,
                      )
                    else if (_estadoSolicitud == 'Pendiente')
                      _crearEstado(
                        'Solicitud pendiente',
                        'Tu solicitud ya fue enviada y está esperando '
                            'la revisión del administrador.',
                        Icons.hourglass_top_rounded,
                      )
                    else if (_estadoSolicitud == 'Aprobada')
                      _crearEstado(
                        'Solicitud aprobada',
                        'Tu solicitud fue aprobada. Cierra sesión e '
                            'inicia nuevamente para actualizar tu acceso.',
                        Icons.check_circle_outline_rounded,
                      )
                    else if (_estadoSolicitud == 'Rechazada')
                      _crearEstado(
                        'Solicitud no aprobada',
                        'El administrador rechazó tu solicitud. '
                            'Si necesitas más información, comunícate '
                            'con la institución.',
                        Icons.info_outline_rounded,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: crema,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Datos de tu cuenta',
                              style: TextStyle(
                                color: verde,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Nombre completo',
                              style: TextStyle(
                                color: vinotintoMedio,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _nombre,
                              style: const TextStyle(
                                color: verde,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Divider(height: 25),
                            const Text(
                              'Correo electrónico',
                              style: TextStyle(
                                color: vinotintoMedio,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _correo,
                              style: const TextStyle(
                                color: verde,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 25),
                            const Text(
                              'Al enviar esta solicitud, el administrador '
                              'podrá revisar tus datos y decidir si aprueba '
                              'tu cambio de rol.',
                              style: TextStyle(
                                color: vinotintoMedio,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _enviando ? null : _enviarSolicitud,
                                icon: _enviando
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded),
                                label: Text(
                                  _enviando
                                      ? 'Enviando...'
                                      : 'Enviar solicitud',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: verde,
                                  foregroundColor: crema,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
