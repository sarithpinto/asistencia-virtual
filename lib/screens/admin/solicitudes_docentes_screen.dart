import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:asistencia_qr/core/theme/app_theme.dart';
import 'package:asistencia_qr/core/widgets/fondo_vinotinto.dart';

class SolicitudesDocentesScreen extends StatefulWidget {
  const SolicitudesDocentesScreen({super.key});

  @override
  State<SolicitudesDocentesScreen> createState() =>
      _SolicitudesDocentesScreenState();
}

class _SolicitudesDocentesScreenState extends State<SolicitudesDocentesScreen> {
  final Set<String> _procesando = {};

  Future<void> _procesarSolicitud({
    required String solicitudId,
    required String estado,
  }) async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) return;

    setState(() {
      _procesando.add(solicitudId);
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final solicitudRef = firestore
          .collection('solicitudes_docente')
          .doc(solicitudId);

      final batch = firestore.batch();

      if (estado == 'Aprobada') {
        final usuarioRef = firestore.collection('usuarios').doc(solicitudId);

        // Cambia el rol del usuario a Docente.
        batch.update(usuarioRef, {'rol': 'Docente'});
      }

      // Actualiza el estado de la solicitud.
      batch.update(solicitudRef, {
        'estado': estado,
        'fechaRevision': FieldValue.serverTimestamp(),
        'revisadoPor': usuario.uid,
      });

      // Ambas operaciones se guardan juntas.
      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            estado == 'Aprobada'
                ? 'Solicitud aprobada. El usuario ahora es docente.'
                : 'La solicitud fue rechazada.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo procesar la solicitud: ${e.message ?? e.code}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ocurrió un error inesperado: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _procesando.remove(solicitudId);
        });
      }
    }
  }

  Widget _crearBoton({
    required String texto,
    required IconData icono,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icono, size: 18),
        label: Text(texto),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: crema,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _construirSolicitud(String solicitudId, Map<String, dynamic> datos) {
    final nombre = datos['nombre'] as String? ?? 'Sin nombre';
    final correo = datos['correo'] as String? ?? 'Sin correo';
    final estaProcesando = _procesando.contains(solicitudId);

    return Card(
      color: crema,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: verde,
                  child: Icon(Icons.person_rounded, color: crema),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    nombre,
                    style: const TextStyle(
                      color: verde,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.email_outlined,
                  color: vinotintoMedio,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    correo,
                    style: const TextStyle(color: vinotintoMedio, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Estado: Pendiente de revisión',
              style: TextStyle(
                color: vinotintoMedio,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _crearBoton(
                  texto: 'Aprobar',
                  icono: Icons.check_circle_outline,
                  color: verde,
                  onPressed: estaProcesando
                      ? null
                      : () => _procesarSolicitud(
                          solicitudId: solicitudId,
                          estado: 'Aprobada',
                        ),
                ),
                const SizedBox(width: 10),
                _crearBoton(
                  texto: 'Rechazar',
                  icono: Icons.cancel_outlined,
                  color: vinotintoMedio,
                  onPressed: estaProcesando
                      ? null
                      : () => _procesarSolicitud(
                          solicitudId: solicitudId,
                          estado: 'Rechazada',
                        ),
                ),
              ],
            ),
            if (estaProcesando) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                color: verde,
                backgroundColor: Color(0xFFD8CCBC),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: vinotintoOscuro,
        foregroundColor: crema,
        title: const Text('Solicitudes de docentes'),
      ),
      body: FondoVinotinto(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('solicitudes_docente')
                .where('estado', isEqualTo: 'Pendiente')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No se pudieron cargar las solicitudes.\n'
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: crema),
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: crema),
                );
              }

              final solicitudes = snapshot.data?.docs ?? [];

              if (solicitudes.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_rounded, color: crema, size: 58),
                        SizedBox(height: 16),
                        Text(
                          'No hay solicitudes pendientes',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: crema,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Cuando alguien solicite autorización '
                          'para ser docente, aparecerá aquí.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: crema,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Solicitudes pendientes: ${solicitudes.length}',
                    style: const TextStyle(
                      color: crema,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...solicitudes.map(
                    (solicitud) =>
                        _construirSolicitud(solicitud.id, solicitud.data()),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
