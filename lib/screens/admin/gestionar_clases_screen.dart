import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:asistencia_qr/core/theme/app_theme.dart';
import 'package:asistencia_qr/core/widgets/fondo_vinotinto.dart';

class GestionarClasesScreen extends StatefulWidget {
  const GestionarClasesScreen({super.key});

  @override
  State<GestionarClasesScreen> createState() => _GestionarClasesScreenState();
}

class _GestionarClasesScreenState extends State<GestionarClasesScreen> {
  final TextEditingController _busquedaController = TextEditingController();

  String _busqueda = '';
  final Set<String> _procesando = {};

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  List<String> _obtenerSalones(Map<String, dynamic> datos) {
    final salones = datos['salones'];

    if (salones is List) {
      return salones
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    final salon = datos['salon'];

    if (salon is String) {
      return salon
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return [];
  }

  Future<void> _cambiarEstado(
    String claseId,
    String nombre,
    bool activa,
  ) async {
    final nuevoEstado = !activa;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: crema,
        title: Text(
          nuevoEstado ? 'Activar clase' : 'Desactivar clase',
          style: const TextStyle(color: verde, fontWeight: FontWeight.bold),
        ),
        content: Text(
          nuevoEstado
              ? '¿Deseas activar "$nombre"? Se podrán generar nuevas sesiones QR.'
              : '¿Deseas desactivar "$nombre"? No se podrán generar nuevas sesiones QR.',
          style: const TextStyle(color: vinotintoMedio),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: verde,
              foregroundColor: crema,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _procesando.add(claseId));

    try {
      await FirebaseFirestore.instance.collection('clases').doc(claseId).update(
        {'activa': nuevoEstado},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nuevoEstado
                ? 'La clase fue activada correctamente.'
                : 'La clase fue desactivada correctamente.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cambiar el estado: ${e.message ?? e.code}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _procesando.remove(claseId));
      }
    }
  }

  Widget _crearTarjeta(String id, Map<String, dynamic> datos) {
    final nombre = datos['nombre']?.toString() ?? 'Sin nombre';
    final grupo = datos['grupo']?.toString() ?? 'Sin grupo';
    final docente =
        datos['docenteNombre']?.toString() ?? 'Docente no identificado';
    final docenteId = datos['docenteId']?.toString() ?? '';
    final activa = datos['activa'] == true;
    final salones = _obtenerSalones(datos);
    final procesando = _procesando.contains(id);

    return Card(
      color: crema,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: verde.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: verde,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    nombre,
                    style: const TextStyle(
                      color: verde,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: activa
                        ? Colors.green.withValues(alpha: 0.12)
                        : vinotintoMedio.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    activa ? 'Activa' : 'Inactiva',
                    style: TextStyle(
                      color: activa ? Colors.green.shade800 : vinotintoMedio,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _dato(Icons.groups_rounded, 'Grupo: $grupo'),
            const SizedBox(height: 8),
            _dato(Icons.person_rounded, 'Docente: $docente'),
            const SizedBox(height: 8),
            _dato(
              Icons.location_on_outlined,
              'Salones: ${salones.isEmpty ? 'No definidos' : salones.join(', ')}',
            ),
            const SizedBox(height: 8),
            _dato(
              Icons.fingerprint_rounded,
              'ID docente: ${docenteId.isEmpty ? 'No disponible' : docenteId}',
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: procesando
                    ? null
                    : () => _cambiarEstado(id, nombre, activa),
                icon: procesando
                    ? const SizedBox(
                        height: 17,
                        width: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        activa
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                      ),
                label: Text(activa ? 'Desactivar clase' : 'Activar clase'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: activa ? vinotintoMedio : verde,
                  side: BorderSide(color: activa ? vinotintoMedio : verde),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dato(IconData icono, String texto) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: vinotintoMedio),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(color: vinotintoMedio, fontSize: 13),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestionar clases',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: vinotintoOscuro,
        foregroundColor: crema,
      ),
      body: FondoVinotinto(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                child: TextField(
                  controller: _busquedaController,
                  onChanged: (valor) {
                    setState(() => _busqueda = valor.toLowerCase().trim());
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar asignatura, grupo o docente',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: crema,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _busqueda.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _busquedaController.clear();
                              setState(() => _busqueda = '');
                            },
                            icon: const Icon(Icons.close),
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('clases')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No se pudieron cargar las clases. '
                            'Verifica los permisos de Firestore.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: crema),
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: crema),
                      );
                    }

                    final clases =
                        snapshot.data?.docs.where((doc) {
                          final datos = doc.data();

                          final nombre = (datos['nombre'] ?? '')
                              .toString()
                              .toLowerCase();
                          final grupo = (datos['grupo'] ?? '')
                              .toString()
                              .toLowerCase();
                          final docente = (datos['docenteNombre'] ?? '')
                              .toString()
                              .toLowerCase();

                          return nombre.contains(_busqueda) ||
                              grupo.contains(_busqueda) ||
                              docente.contains(_busqueda);
                        }).toList() ??
                        [];

                    if (clases.isEmpty) {
                      return const Center(
                        child: Text(
                          'No se encontraron clases registradas.',
                          style: TextStyle(color: crema),
                        ),
                      );
                    }

                    final activas = clases
                        .where((doc) => doc.data()['activa'] == true)
                        .length;

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                      children: [
                        Text(
                          'Clases encontradas: ${clases.length}',
                          style: const TextStyle(
                            color: crema,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Activas: $activas  •  Inactivas: ${clases.length - activas}',
                          style: const TextStyle(color: crema, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ...clases.map(
                          (doc) => _crearTarjeta(doc.id, doc.data()),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
