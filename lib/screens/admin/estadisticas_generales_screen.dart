
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:asistencia_qr/core/theme/app_theme.dart';
import 'package:asistencia_qr/core/widgets/fondo_vinotinto.dart';

class EstadisticasGeneralesScreen extends StatelessWidget {
  const EstadisticasGeneralesScreen({super.key});

  Widget _tarjeta(
    String titulo,
    int cantidad,
    IconData icono,
  ) {
    return Card(
      color: crema,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: verde.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icono, color: verde, size: 27),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  color: vinotintoMedio,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              cantidad.toString(),
              style: const TextStyle(
                color: verde,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cargando() {
    return const Center(
      child: CircularProgressIndicator(color: crema),
    );
  }

  Widget _error() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No se pudieron cargar las estadísticas. '
          'Verifica los permisos de Firestore.',
          textAlign: TextAlign.center,
          style: TextStyle(color: crema, fontSize: 15),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Estadísticas generales',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: vinotintoOscuro,
        foregroundColor: crema,
      ),
      body: FondoVinotinto(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('usuarios').snapshots(),
          builder: (context, usuariosSnapshot) {
            if (usuariosSnapshot.hasError) return _error();
            if (!usuariosSnapshot.hasData) return _cargando();

            final usuarios = usuariosSnapshot.data!.docs;

            final estudiantes = usuarios
                .where((doc) => doc.data()['rol'] == 'Estudiante')
                .length;

            final docentes = usuarios
                .where((doc) => doc.data()['rol'] == 'Docente')
                .length;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db.collection('solicitudes_docente').snapshots(),
              builder: (context, solicitudesSnapshot) {
                if (solicitudesSnapshot.hasError) return _error();
                if (!solicitudesSnapshot.hasData) return _cargando();

                final pendientes = solicitudesSnapshot.data!.docs
                    .where((doc) => doc.data()['estado'] == 'Pendiente')
                    .length;

                return StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: db.collection('clases').snapshots(),
                  builder: (context, clasesSnapshot) {
                    if (clasesSnapshot.hasError) return _error();
                    if (!clasesSnapshot.hasData) return _cargando();

                    final clases = clasesSnapshot.data!.docs;

                    final clasesActivas = clases
                        .where((doc) => doc.data()['activa'] == true)
                        .length;

                    final clasesInactivas =
                        clases.length - clasesActivas;

                    return StreamBuilder<
                        QuerySnapshot<Map<String, dynamic>>>(
                      stream: db.collection('asistencias').snapshots(),
                      builder: (context, asistenciasSnapshot) {
                        if (asistenciasSnapshot.hasError) {
                          return _error();
                        }

                        if (!asistenciasSnapshot.hasData) {
                          return _cargando();
                        }

                        final asistencias =
                            asistenciasSnapshot.data!.docs.length;

                        return ListView(
                          padding: const EdgeInsets.all(18),
                          children: [
                            const Text(
                              'Resumen de la institución',
                              style: TextStyle(
                                color: crema,
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Información actualizada en tiempo real '
                              'desde la base de datos.',
                              style: TextStyle(
                                color: crema,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 20),

                            _tarjeta(
                              'Usuarios registrados',
                              usuarios.length,
                              Icons.people_alt_rounded,
                            ),
                            _tarjeta(
                              'Estudiantes',
                              estudiantes,
                              Icons.school_rounded,
                            ),
                            _tarjeta(
                              'Docentes',
                              docentes,
                              Icons.person_rounded,
                            ),
                            _tarjeta(
                              'Solicitudes pendientes',
                              pendientes,
                              Icons.pending_actions_rounded,
                            ),
                            _tarjeta(
                              'Total de clases',
                              clases.length,
                              Icons.menu_book_rounded,
                            ),
                            _tarjeta(
                              'Clases activas',
                              clasesActivas,
                              Icons.check_circle_outline_rounded,
                            ),
                            _tarjeta(
                              'Clases inactivas',
                              clasesInactivas,
                              Icons.pause_circle_outline_rounded,
                            ),
                            _tarjeta(
                              'Asistencias registradas',
                              asistencias,
                              Icons.fact_check_rounded,
                            ),
                            const SizedBox(height: 12),
                            const Center(
                              child: Text(
                                'Asistencia Virtual',
                                style: TextStyle(
                                  color: crema,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
