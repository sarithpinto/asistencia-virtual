import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:asistencia_qr/providers/sesion_provider.dart';

import 'package:asistencia_qr/core/theme/app_theme.dart';
import 'package:asistencia_qr/core/theme/app_styles.dart';
import 'package:asistencia_qr/core/widgets/fondo_vinotinto.dart';
import 'package:asistencia_qr/core/widgets/decoracion_campo.dart';

import 'register_screen.dart';

import 'package:asistencia_qr/screens/panel_principal_screen.dart';
import 'package:asistencia_qr/screens/admin/admin_panel_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _cargando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate() || _cargando) return;

    setState(() => _cargando = true);

    try {
      final credencial = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final usuario = credencial.user;

      if (usuario == null) {
        throw Exception('No se pudo identificar al usuario.');
      }

      final perfil = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .get();

      if (!perfil.exists) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        _mostrarMensaje(
          'Esta cuenta no tiene un perfil registrado en el sistema.',
        );
        return;
      }

      final rol = perfil.data()?['rol'];

      if (rol != 'Estudiante' && rol != 'Docente' && rol != 'Administrador') {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        _mostrarMensaje('El rol de esta cuenta no es válido.');
        return;
      }

      if (!mounted) return;

      // Guardar el usuario y su rol en Provider.
      context.read<SesionProvider>().establecerSesion(
        usuario: usuario,
        rol: rol,
      );

      if (rol == 'Administrador') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PanelPrincipalScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String mensaje;

      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          mensaje = 'Correo o contraseña incorrectos.';
          break;
        case 'invalid-email':
          mensaje = 'El correo no es válido.';
          break;
        case 'too-many-requests':
          mensaje = 'Demasiados intentos. Inténtalo más tarde.';
          break;
        case 'network-request-failed':
          mensaje = 'Revisa tu conexión a internet.';
          break;
        case 'operation-not-allowed':
          mensaje = 'Activa Email/Password en Firebase.';
          break;
        default:
          mensaje = e.message ?? 'No se pudo iniciar sesión.';
      }

      _mostrarMensaje(mensaje);
    } on FirebaseException catch (e) {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      _mostrarMensaje(
        e.code == 'permission-denied'
            ? 'No se permite consultar tu perfil. Revisa las reglas.'
            : 'No se pudo consultar el perfil del usuario.',
      );
    } catch (_) {
      if (!mounted) return;
      _mostrarMensaje('Ocurrió un error al iniciar sesión.');
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  void _abrirCambioContrasena() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CambiarContrasenaScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FondoVinotinto(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        color: crema,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 22,
                            offset: const Offset(0, 9),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: verde,
                        size: 46,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'ASISTENCIA',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                        color: crema,
                      ),
                    ),
                    const Text(
                      'V I R T U A L',
                      style: TextStyle(
                        fontSize: 13,
                        color: crema,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: AppStyles.paddingTarjeta,
                      decoration: BoxDecoration(
                        color: crema,
                        borderRadius: BorderRadius.circular(
                          AppStyles.radioTarjeta,
                        ),
                        border: Border.all(color: const Color(0xFFE2D8C9)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              '¡Bienvenido!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color: verde,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ingresa a tu cuenta institucional',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: vinotintoMedio,
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'Correo institucional',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: verde,
                              ),
                            ),
                            const SizedBox(height: 9),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: verde),
                              decoration: decoracionCampo(
                                'Correo institucional',
                                Icons.mail_outline_rounded,
                                sugerencia: 'nombre@institucion.edu.co',
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
                            const SizedBox(height: 20),
                            const Text(
                              'Contraseña',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: verde,
                              ),
                            ),
                            const SizedBox(height: 9),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _iniciarSesion(),
                              style: const TextStyle(color: verde),
                              decoration: decoracionCampo(
                                'Contraseña',
                                Icons.lock_outline_rounded,
                                sugerencia: 'Ingresa tu contraseña',
                                sufijo: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: verde,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Ingresa tu contraseña';
                                }

                                if (value.length < 6) {
                                  return 'Mínimo 6 caracteres';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _cargando
                                    ? null
                                    : _abrirCambioContrasena,
                                child: const Text(
                                  '¿Olvidaste tu contraseña?',
                                  style: TextStyle(color: verde),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _cargando ? null : _iniciarSesion,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: verde,
                                  foregroundColor: crema,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppStyles.radioMediano,
                                    ),
                                  ),
                                ),
                                child: _cargando
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: crema,
                                        ),
                                      )
                                    : const Text(
                                        'Iniciar sesión',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  '¿No tienes una cuenta? ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: vinotintoMedio,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Crear cuenta',
                                    style: TextStyle(
                                      color: verde,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Tu asistencia, más fácil y organizada.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: crema, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CambiarContrasenaScreen extends StatefulWidget {
  const CambiarContrasenaScreen({super.key});

  @override
  State<CambiarContrasenaScreen> createState() =>
      _CambiarContrasenaScreenState();
}

class _CambiarContrasenaScreenState extends State<CambiarContrasenaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _actualController = TextEditingController();
  final _nuevaController = TextEditingController();
  final _confirmarController = TextEditingController();

  bool _cargando = false;
  bool _verActual = false;
  bool _verNueva = false;
  bool _verConfirmar = false;

  @override
  void dispose() {
    _emailController.dispose();
    _actualController.dispose();
    _nuevaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _cambiarContrasena() async {
    if (!_formKey.currentState!.validate() || _cargando) return;

    setState(() => _cargando = true);

    try {
      final email = _emailController.text.trim();

      final credencial = EmailAuthProvider.credential(
        email: email,
        password: _actualController.text,
      );

      final usuario = FirebaseAuth.instance.currentUser;

      if (usuario != null && usuario.email == email) {
        await usuario.reauthenticateWithCredential(credencial);
        await usuario.updatePassword(_nuevaController.text);
      } else {
        final resultado = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: email,
              password: _actualController.text,
            );

        await resultado.user!.updatePassword(_nuevaController.text);
        await FirebaseAuth.instance.signOut();
      }

      if (!mounted) return;

      _mensaje(
        '¡Contraseña actualizada correctamente! Ya puedes iniciar sesión.',
      );

      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String mensaje;

      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          mensaje = 'La contraseña actual es incorrecta.';
          break;
        case 'user-not-found':
          mensaje = 'No existe una cuenta con ese correo.';
          break;
        case 'invalid-email':
          mensaje = 'El correo no es válido.';
          break;
        case 'weak-password':
          mensaje = 'La nueva contraseña es demasiado débil.';
          break;
        case 'requires-recent-login':
          mensaje = 'Vuelve a iniciar sesión e inténtalo nuevamente.';
          break;
        case 'too-many-requests':
          mensaje = 'Demasiados intentos. Inténtalo más tarde.';
          break;
        case 'network-request-failed':
          mensaje = 'Revisa tu conexión a internet.';
          break;
        default:
          mensaje = 'No se pudo cambiar la contraseña.';
      }

      _mensaje(mensaje);
    } catch (_) {
      if (!mounted) return;
      _mensaje('Ocurrió un error al cambiar la contraseña.');
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FondoVinotinto(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: AppStyles.paddingTarjeta,
                  decoration: BoxDecoration(
                    color: crema,
                    borderRadius: BorderRadius.circular(AppStyles.radioTarjeta),
                    border: Border.all(color: const Color(0xFFE2D8C9)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.lock_reset_rounded,
                          size: 54,
                          color: verde,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Cambiar contraseña',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: verde,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Ingresa tu correo y tu contraseña actual para establecer una nueva.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: vinotintoMedio),
                        ),
                        const SizedBox(height: 26),
                        _campo(
                          controller: _emailController,
                          etiqueta: 'Correo institucional',
                          icono: Icons.mail_outline_rounded,
                          teclado: TextInputType.emailAddress,
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
                        const SizedBox(height: 18),
                        _campo(
                          controller: _actualController,
                          etiqueta: 'Contraseña actual',
                          icono: Icons.lock_outline_rounded,
                          visible: _verActual,
                          cambiarVisible: () {
                            setState(() => _verActual = !_verActual);
                          },
                        ),
                        const SizedBox(height: 18),
                        _campo(
                          controller: _nuevaController,
                          etiqueta: 'Nueva contraseña',
                          icono: Icons.lock_reset_rounded,
                          visible: _verNueva,
                          cambiarVisible: () {
                            setState(() => _verNueva = !_verNueva);
                          },
                          validator: (value) {
                            if (value == null || value.length < 6) {
                              return 'Mínimo 6 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        _campo(
                          controller: _confirmarController,
                          etiqueta: 'Confirmar nueva contraseña',
                          icono: Icons.verified_user_outlined,
                          visible: _verConfirmar,
                          cambiarVisible: () {
                            setState(() => _verConfirmar = !_verConfirmar);
                          },
                          validator: (value) {
                            if (value != _nuevaController.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _cargando ? null : _cambiarContrasena,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: verde,
                              foregroundColor: crema,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppStyles.radioMediano,
                                ),
                              ),
                            ),
                            child: _cargando
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      color: crema,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Cambiar contraseña',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _cargando
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text(
                            'Volver al inicio de sesión',
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

  Widget _campo({
    required TextEditingController controller,
    required String etiqueta,
    required IconData icono,
    TextInputType teclado = TextInputType.text,
    bool visible = false,
    VoidCallback? cambiarVisible,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: teclado,
      obscureText: cambiarVisible != null && !visible,
      style: const TextStyle(color: verde),
      decoration: decoracionCampo(
        etiqueta,
        icono,
        sufijo: cambiarVisible == null
            ? null
            : IconButton(
                onPressed: cambiarVisible,
                icon: Icon(
                  visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: verde,
                ),
              ),
      ),
      validator:
          validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'Completa este campo';
            }
            return null;
          },
    );
  }
}
