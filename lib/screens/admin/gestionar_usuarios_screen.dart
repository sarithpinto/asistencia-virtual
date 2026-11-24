import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:asistencia_qr/core/theme/app_theme.dart';
import 'package:asistencia_qr/core/widgets/fondo_vinotinto.dart';

class GestionarUsuariosScreen extends StatefulWidget {
  const GestionarUsuariosScreen({super.key});

  @override
  State<GestionarUsuariosScreen> createState() =>
      _GestionarUsuariosScreenState();
}

class _GestionarUsuariosScreenState extends State<GestionarUsuariosScreen> {
  final TextEditingController _busquedaController = TextEditingController();

  String _busqueda = '';
  final Set<String> _procesando = {};

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cambiarRol(String uid, String nombre, String rolActual) async {
    final nuevoRol = rolActual == 'Estudiante' ? 'Docente' : 'Estudiante';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: crema,
        title: const Text('Cambiar rol', style: TextStyle(color: verde)),
        content: Text(
          '¿Deseas cambiar el rol de $nombre '
          'de $rolActual a $nuevoRol?',
          style: const TextStyle(color: vinotintoMedio),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: verde,
              foregroundColor: crema,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _procesando.add(uid));

    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
        'rol': nuevoRol,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El usuario ahora tiene el rol $nuevoRol.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cambiar el rol: ${e.message ?? e.code}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _procesando.remove(uid));
      }
    }
  }

  Widget _crearUsuario(String uid, Map<String, dynamic> datos) {
    final nombre = datos['nombre'] as String? ?? 'Sin nombre';
    final correo = datos['correo'] as String? ?? 'Sin correo';
    final rol = datos['rol'] as String? ?? 'Sin rol';

    final esMiCuenta = uid == FirebaseAuth.instance.currentUser?.uid;
    final esAdministrador = rol == 'Administrador';
    final estaProcesando = _procesando.contains(uid);

    return Card(
      color: crema,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: verde,
                  child: Icon(Icons.person, color: crema),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          color: verde,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        correo,
                        style: const TextStyle(
                          color: vinotintoMedio,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Rol: ',
                  style: TextStyle(
                    color: vinotintoMedio,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: verde.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    rol,
                    style: const TextStyle(
                      color: verde,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (!esAdministrador && !esMiCuenta) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: estaProcesando
                      ? null
                      : () => _cambiarRol(uid, nombre, rol),
                  icon: estaProcesando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.swap_horiz),
                  label: Text(
                    'Cambiar a ${rol == 'Estudiante' ? 'Docente' : 'Estudiante'}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: verde,
                    side: const BorderSide(color: verde),
                  ),
                ),
              ),
            ] else if (esMiCuenta) ...[
              const SizedBox(height: 8),
              const Text(
                'Tu cuenta administradora está protegida.',
                style: TextStyle(color: vinotintoMedio, fontSize: 12),
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
        title: const Text('Gestionar usuarios'),
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
                    setState(() => _busqueda = valor.toLowerCase());
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o correo',
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
                      .collection('usuarios')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'No se pudieron cargar los usuarios.',
                          style: TextStyle(color: crema),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: crema),
                      );
                    }

                    final usuarios =
                        snapshot.data?.docs.where((doc) {
                          final datos = doc.data();
                          final nombre = (datos['nombre'] ?? '')
                              .toString()
                              .toLowerCase();
                          final correo = (datos['correo'] ?? '')
                              .toString()
                              .toLowerCase();

                          return nombre.contains(_busqueda) ||
                              correo.contains(_busqueda);
                        }).toList() ??
                        [];

                    if (usuarios.isEmpty) {
                      return const Center(
                        child: Text(
                          'No se encontraron usuarios.',
                          style: TextStyle(color: crema),
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        Text(
                          'Usuarios registrados: ${usuarios.length}',
                          style: const TextStyle(
                            color: crema,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...usuarios.map(
                          (doc) => _crearUsuario(doc.id, doc.data()),
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
