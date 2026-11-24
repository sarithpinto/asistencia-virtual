import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:asistencia_qr/core/theme/app_theme.dart';
import 'package:asistencia_qr/core/widgets/fondo_vinotinto.dart';
import 'package:asistencia_qr/core/widgets/decoracion_campo.dart';

class EstudiantesScreen extends StatefulWidget {
  const EstudiantesScreen({super.key});

  @override
  State<EstudiantesScreen> createState() => _EstudiantesScreenState();
}

class _EstudiantesScreenState extends State<EstudiantesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarController = TextEditingController();

  bool _mostrarPassword = false;
  bool _mostrarConfirmacion = false;
  bool _cargando = false;
  bool _solicitarSerDocente = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _crearCuenta() async {
    if (!_formKey.currentState!.validate() || _cargando) return;

    final nombre = _nombreController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (password != _confirmarController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden.')),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      final credencial = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final usuario = credencial.user;

      if (usuario == null) {
        throw Exception('No se pudo crear el usuario.');
      }

      await usuario.updateDisplayName(nombre);

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .set({
            'nombre': nombre,
            'correo': email,
            'rol': 'Estudiante',
            'fechaCreacion': FieldValue.serverTimestamp(),
          });

      // Si la persona indicó que es docente,
      // se crea también su solicitud de autorización.
      if (_solicitarSerDocente) {
        await FirebaseFirestore.instance
            .collection('solicitudes_docente')
            .doc(usuario.uid)
            .set({
              'usuarioId': usuario.uid,
              'nombre': nombre,
              'correo': email,
              'estado': 'Pendiente',
              'fechaSolicitud': FieldValue.serverTimestamp(),
            });
      }

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      final mensaje = _solicitarSerDocente
          ? '¡Cuenta creada! Tu solicitud para ser docente '
                'fue enviada al administrador.'
          : '¡Cuenta creada correctamente! Ahora puedes iniciar sesión.';

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String mensaje;

      switch (e.code) {
        case 'email-already-in-use':
          mensaje = 'Este correo ya está registrado.';
          break;
        case 'invalid-email':
          mensaje = 'El correo no es válido.';
          break;
        case 'weak-password':
          mensaje = 'La contraseña es demasiado débil.';
          break;
        case 'operation-not-allowed':
          mensaje = 'Activa Email/Password en Firebase.';
          break;
        default:
          mensaje = e.message ?? 'No se pudo crear la cuenta.';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'permission-denied'
                ? 'La cuenta puede haberse creado, pero no se pudo '
                      'guardar el perfil o la solicitud en Firestore. '
                      'Revisa las reglas.'
                : 'No se pudo guardar la información en Firestore.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un error al crear la cuenta.')),
      );
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: vinotintoOscuro,
        foregroundColor: crema,
        title: const Text('Crear cuenta'),
      ),
      body: FondoVinotinto(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: crema,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE2D8C9)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 52,
                          color: verde,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Únete a Asistencia Virtual',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: verde,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Crea tu cuenta de estudiante para continuar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: vinotintoMedio, fontSize: 13),
                        ),
                        const SizedBox(height: 24),

                        TextFormField(
                          controller: _nombreController,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(color: verde),
                          decoration: decoracionCampo(
                            'Nombre completo',
                            Icons.person_outline_rounded,
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Ingresa tu nombre'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: verde),
                          decoration: decoracionCampo(
                            'Correo institucional',
                            Icons.mail_outline_rounded,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresa tu correo';
                            }

                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(value.trim())) {
                              return 'Ingresa un correo válido';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_mostrarPassword,
                          style: const TextStyle(color: verde),
                          decoration: decoracionCampo(
                            'Contraseña',
                            Icons.lock_outline_rounded,
                            sufijo: IconButton(
                              icon: Icon(
                                _mostrarPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: verde,
                              ),
                              onPressed: () {
                                setState(() {
                                  _mostrarPassword = !_mostrarPassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.length < 6
                              ? 'Usa al menos 6 caracteres'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _confirmarController,
                          obscureText: !_mostrarConfirmacion,
                          style: const TextStyle(color: verde),
                          decoration: decoracionCampo(
                            'Confirmar contraseña',
                            Icons.lock_reset_rounded,
                            sufijo: IconButton(
                              icon: Icon(
                                _mostrarConfirmacion
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: verde,
                              ),
                              onPressed: () {
                                setState(() {
                                  _mostrarConfirmacion = !_mostrarConfirmacion;
                                });
                              },
                            ),
                          ),
                          validator: (value) =>
                              value != _passwordController.text
                              ? 'Las contraseñas no coinciden'
                              : null,
                        ),

                        const SizedBox(height: 20),

                        // Acceso opcional para quienes solicitan
                        // autorización para ser docentes.
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _cargando
                              ? null
                              : () {
                                  setState(() {
                                    _solicitarSerDocente =
                                        !_solicitarSerDocente;
                                  });
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.school_rounded,
                                  color: verde,
                                  size: 23,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '¿Eres docente? Solicita autorización aquí',
                                    style: TextStyle(
                                      color: verde,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                      decorationColor: verde,
                                    ),
                                  ),
                                ),
                                Icon(
                                  _solicitarSerDocente
                                      ? Icons.check_circle_rounded
                                      : Icons.arrow_forward_ios_rounded,
                                  color: verde,
                                  size: 19,
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_solicitarSerDocente) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EFE8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: verde.withValues(alpha: 0.25),
                              ),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: verde,
                                  size: 21,
                                ),
                                SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    'Tu cuenta se creará como estudiante '
                                    'y se enviará una solicitud al '
                                    'administrador. Solo podrás acceder '
                                    'como docente cuando sea aprobada.',
                                    style: TextStyle(
                                      color: verde,
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _cargando ? null : _crearCuenta,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: verde,
                              foregroundColor: crema,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _cargando
                                ? const CircularProgressIndicator(color: crema)
                                : Text(
                                    _solicitarSerDocente
                                        ? 'Crear cuenta y solicitar autorización'
                                        : 'Crear cuenta',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        TextButton(
                          onPressed: _cargando
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text(
                            '¿Ya tienes cuenta? Iniciar sesión',
                            style: TextStyle(color: verde),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
