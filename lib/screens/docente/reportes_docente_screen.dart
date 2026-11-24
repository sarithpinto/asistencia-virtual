import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:asistencia_qr/core/theme/app_theme.dart';
import 'package:asistencia_qr/core/theme/app_styles.dart';
import 'package:asistencia_qr/core/widgets/fondo_vinotinto.dart';
import 'package:asistencia_qr/core/widgets/decoracion_campo.dart';

class ReportesDocenteScreen extends StatefulWidget {
  const ReportesDocenteScreen({super.key});

  @override
  State<ReportesDocenteScreen> createState() => _ReportesDocenteScreenState();
}

class _ReportesDocenteScreenState extends State<ReportesDocenteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _grupoController = TextEditingController();
  final _salonesController = TextEditingController();

  bool _guardando = false;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _clasesStream;

  @override
  void initState() {
    super.initState();

    final usuario = FirebaseAuth.instance.currentUser;

    _clasesStream = usuario == null
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance
              .collection('clases')
              .where('docenteId', isEqualTo: usuario.uid)
              .snapshots();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _grupoController.dispose();
    _salonesController.dispose();
    super.dispose();
  }

  // Lee las clases nuevas y también las antiguas,
  // que solo guardaban un campo llamado "salon".
  List<String> _obtenerSalones(Map<String, dynamic> datos) {
    final salonesGuardados = datos['salones'];

    if (salonesGuardados is List) {
      return salonesGuardados
          .whereType<String>()
          .map((salon) => salon.trim())
          .where((salon) => salon.isNotEmpty)
          .toList();
    }

    final salonAnterior = datos['salon'];

    if (salonAnterior is String && salonAnterior.trim().isNotEmpty) {
      return salonAnterior
          .split(',')
          .map((salon) => salon.trim())
          .where((salon) => salon.isNotEmpty)
          .toList();
    }

    return [];
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _guardarClase(
    BuildContext dialogContext,
    StateSetter actualizarDialogo, {
    String? claseId,
  }) async {
    if (!_formKey.currentState!.validate() || _guardando) return;

    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      _mostrarMensaje('Debes iniciar sesión para guardar la clase.');
      return;
    }

    final nombre = _nombreController.text.trim();
    final grupo = _grupoController.text.trim();

    final salones = _salonesController.text
        .split(',')
        .map((salon) => salon.trim())
        .where((salon) => salon.isNotEmpty)
        .toSet()
        .toList();

    if (salones.isEmpty) {
      _mostrarMensaje('Escribe al menos un salón.');
      return;
    }

    actualizarDialogo(() {
      _guardando = true;
    });

    try {
      final baseDatos = FirebaseFirestore.instance;

      final perfil = await baseDatos
          .collection('usuarios')
          .doc(usuario.uid)
          .get();

      if (!perfil.exists || perfil.data()?['rol'] != 'Docente') {
        throw Exception('La cuenta no tiene un perfil válido de docente.');
      }

      final referencia = claseId == null
          ? baseDatos.collection('clases').doc()
          : baseDatos.collection('clases').doc(claseId);

      if (claseId != null) {
        final documentoExistente = await referencia.get();

        if (!documentoExistente.exists ||
            documentoExistente.data()?['docenteId'] != usuario.uid) {
          throw Exception('No puedes editar esta clase o ya no existe.');
        }

        // Actualizamos únicamente los datos editables.
        await referencia.update({
          'nombre': nombre,
          'grupo': grupo,
          'salon': salones.join(', '),
          'salones': salones,
        });
      } else {
        await referencia.set({
          'nombre': nombre,
          'grupo': grupo,

          // Compatibilidad con la versión anterior.
          'salon': salones.join(', '),

          // Nueva lista de salones.
          'salones': salones,

          'docenteId': usuario.uid,
          'docenteNombre':
              perfil.data()?['nombre'] ?? usuario.displayName ?? 'Docente',
          'activa': true,
          'fechaCreacion': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }

      _mostrarMensaje(
        claseId == null
            ? '¡Clase creada correctamente!'
            : '¡Clase actualizada correctamente!',
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      final mensaje = e.code == 'permission-denied'
          ? 'Firebase rechazó la operación. Revisa las reglas de Firestore.'
          : 'Error de Firebase: ${e.message ?? e.code}';

      _mostrarMensaje(mensaje);
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'No se pudo guardar la clase: '
        '${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      _guardando = false;

      if (mounted) {
        setState(() {});
      }

      if (dialogContext.mounted) {
        actualizarDialogo(() {
          _guardando = false;
        });
      }
    }
  }

  void _mostrarFormulario({String? claseId, Map<String, dynamic>? datos}) {
    _nombreController.text = datos?['nombre']?.toString() ?? '';
    _grupoController.text = datos?['grupo']?.toString() ?? '';

    final salones = datos == null ? <String>[] : _obtenerSalones(datos);

    _salonesController.text = salones.join(', ');
    _guardando = false;

    final editando = claseId != null;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, actualizarDialogo) => AlertDialog(
          backgroundColor: crema,
          title: Text(
            editando ? 'Editar clase' : 'Crear nueva clase',
            style: const TextStyle(color: verde, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nombreController,
                    enabled: !_guardando,
                    textCapitalization: TextCapitalization.words,
                    decoration: decoracionCampo(
                      'Nombre de la asignatura',
                      Icons.menu_book_rounded,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Escribe la asignatura'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _grupoController,
                    enabled: !_guardando,
                    textCapitalization: TextCapitalization.characters,
                    decoration: decoracionCampo(
                      'Grupo o código',
                      Icons.groups_rounded,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Escribe el grupo'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _salonesController,
                    enabled: !_guardando,
                    textCapitalization: TextCapitalization.characters,
                    decoration: decoracionCampo(
                      'Salones o aulas',
                      Icons.location_on_outlined,
                    ),

                    validator: (value) {
                      final salones = (value ?? '')
                          .split(',')
                          .map((salon) => salon.trim())
                          .where((salon) => salon.isNotEmpty)
                          .toList();

                      if (salones.isEmpty) {
                        return 'Escribe al menos un salón';
                      }

                      return null;
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6, left: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Puedes escribir varios salones separados por comas. Ejemplo: 204C, 302A',
                        style: TextStyle(color: vinotintoMedio, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ejemplo: 204C, 302A',
                      style: TextStyle(color: vinotintoMedio, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _guardando ? null : () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: vinotintoMedio),
              ),
            ),
            ElevatedButton(
              onPressed: _guardando
                  ? null
                  : () => _guardarClase(
                      dialogContext,
                      actualizarDialogo,
                      claseId: claseId,
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: verde,
                foregroundColor: crema,
              ),
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: crema,
                      ),
                    )
                  : Text(editando ? 'Guardar cambios' : 'Crear clase'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarEliminarClase(
    String claseId,
    String nombreClase,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: crema,
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: vinotintoMedio,
          size: 42,
        ),
        title: const Text(
          '¿Eliminar esta clase?',
          textAlign: TextAlign.center,
          style: TextStyle(color: verde, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar "$nombreClase"? '
          'Esta acción no se puede deshacer.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: vinotintoMedio, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: vinotintoMedio),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Eliminar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: vinotintoMedio,
              foregroundColor: crema,
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      _mostrarMensaje('Debes iniciar sesión para eliminar una clase.');
      return;
    }

    try {
      final referencia = FirebaseFirestore.instance
          .collection('clases')
          .doc(claseId);

      final documento = await referencia.get();

      if (!mounted) return;

      if (!documento.exists || documento.data()?['docenteId'] != usuario.uid) {
        _mostrarMensaje('No puedes eliminar esta clase o ya no existe.');
        return;
      }

      await referencia.delete();

      if (!mounted) return;

      _mostrarMensaje('La clase "$nombreClase" fue eliminada.');
    } on FirebaseException catch (e) {
      if (!mounted) return;

      _mostrarMensaje('No se pudo eliminar la clase: ${e.message ?? e.code}');
    } catch (_) {
      _mostrarMensaje('Ocurrió un error al eliminar la clase.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      return const Scaffold(body: Center(child: Text('Debes iniciar sesión.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis clases',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: crema,
        foregroundColor: verde,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: verde,
        foregroundColor: crema,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crear clase'),
      ),
      body: FondoVinotinto(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _clasesStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No se pudieron cargar las clases. '
                    'Revisa la conexión y los permisos de Firebase.',
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

            final clases = snapshot.data?.docs ?? [];

            if (clases.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        color: crema,
                        size: 68,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Todavía no tienes clases',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: crema,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Crea tu primera clase con el botón inferior.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: crema, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 100),
              itemCount: clases.length,
              itemBuilder: (context, index) {
                final documento = clases[index];
                final datos = documento.data();
                final salones = _obtenerSalones(datos);

                return Card(
                  color: crema,
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppStyles.radioTarjeta),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: AppStyles.paddingMediano,
                      decoration: BoxDecoration(
                        color: verde.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(
                          AppStyles.radioMediano,
                        ),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: verde,
                        size: 30,
                      ),
                    ),
                    title: Text(
                      datos['nombre']?.toString() ?? 'Sin nombre',
                      style: const TextStyle(
                        color: verde,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Grupo: ${datos['grupo'] ?? 'No definido'}\n'
                        'Salones: ${salones.isEmpty ? 'No definidos' : salones.join(', ')}',
                        style: const TextStyle(
                          color: vinotintoMedio,
                          height: 1.6,
                        ),
                      ),
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Opciones de la clase',
                      color: crema,
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: vinotintoMedio,
                        size: 27,
                      ),
                      onSelected: (opcion) {
                        if (opcion == 'editar') {
                          _mostrarFormulario(
                            claseId: documento.id,
                            datos: datos,
                          );
                        } else if (opcion == 'eliminar') {
                          _confirmarEliminarClase(
                            documento.id,
                            datos['nombre']?.toString() ?? 'esta clase',
                          );
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'editar',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, color: verde),
                              SizedBox(width: 10),
                              Text('Editar clase'),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'eliminar',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                color: vinotintoMedio,
                              ),
                              SizedBox(width: 10),
                              Text('Eliminar clase'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
