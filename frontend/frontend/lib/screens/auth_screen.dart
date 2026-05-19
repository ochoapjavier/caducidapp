// frontend/lib/screens/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:frontend/widgets/app_toast.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Clave para identificar y validar nuestro formulario
  final _formKey = GlobalKey<FormState>();

  // Estado para saber si estamos en modo Login o Registro
  var _isLoginMode = true;

  // Estado para mostrar un indicador de carga mientras se procesa la petición
  var _isLoading = false;

  // Variables para almacenar los datos del formulario
  String _userEmail = '';
  String _userPassword = '';
  
  // Variable para almacenar la versión de la app
  String _appVersion = '';

  // Instancia de FirebaseAuth
  final _firebaseAuth = FirebaseAuth.instance;
  
  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${packageInfo.version} (Build ${packageInfo.buildNumber})';
        });
      }
    } catch (e) {
      debugPrint('Error loading app version: $e');
    }
  }

  void _submitAuthForm() async {
    // Primero, validamos el formulario
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return; // Si no es válido, no hacemos nada
    }

    // Si es válido, guardamos los valores
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true; // Empezamos a cargar
    });

    try {
      if (_isLoginMode) {
        // Modo Login
        UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: _userEmail,
          password: _userPassword,
        );
        
        // Verificar si el email está verificado
        if (!userCredential.user!.emailVerified) {
          // Guardar referencia al usuario ANTES de hacer signOut
          final user = userCredential.user!;
          final userEmail = user.email ?? _userEmail;
          
          // Cerrar sesión si no está verificado
          await _firebaseAuth.signOut();
          
          if (mounted) {
            // Usar WidgetsBinding para asegurar que el dialog se muestre después del frame actual
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              
              showDialog(
                context: context,
                barrierDismissible: false, // No se puede cerrar tocando fuera
                builder: (ctx) => AlertDialog(
                  title: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(child: Text('Email no verificado')),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Por favor, verifica tu email antes de iniciar sesión.'),
                      SizedBox(height: 12),
                      Text(
                        ' Email enviado a:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        userEmail,
                        style: TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '📬 Revisa tu bandeja de entrada',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '⚠️ Si no lo ves, revisa SPAM',
                        style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                      },
                      child: Text('Cerrar'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          // Reautenticar temporalmente para enviar email
                          UserCredential tempCred = await _firebaseAuth.signInWithEmailAndPassword(
                            email: _userEmail,
                            password: _userPassword,
                          );
                          await tempCred.user!.sendEmailVerification();
                          await _firebaseAuth.signOut();
                          
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          if (mounted) {
                            AppToast.show(
                              context,
                              message:
                                  '✉️ Email reenviado. Revisa tu bandeja (y spam).',
                              type: AppToastType.success,
                              duration: const Duration(seconds: 5),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            AppToast.show(
                              context,
                              message:
                                  'Error al reenviar. Espera unos minutos e intenta de nuevo.',
                              type: AppToastType.error,
                              duration: const Duration(seconds: 5),
                            );
                          }
                        }
                      },
                      icon: Icon(Icons.email),
                      label: Text('Reenviar email'),
                    ),
                  ],
                ),
              );
            });
          }
          return; // Salir de la función
        }
        // Si el login es exitoso y el email está verificado, el stream de autenticación
        // se encargará de navegar a la pantalla principal.
      } else {
        // Modo Registro
        UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: _userEmail,
          password: _userPassword,
        );
        
        // Enviar email de verificación
        await userCredential.user!.sendEmailVerification();
        
        // Mostrar mensaje de éxito con instrucciones
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.email, color: Colors.green),
                  SizedBox(width: 8),
                  Text('¡Cuenta creada!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Te hemos enviado un email de verificación a:'),
                  SizedBox(height: 8),
                  Text(
                    _userEmail,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '📬 Revisa tu bandeja de entrada',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '⚠️ Si no lo ves, revisa la carpeta de SPAM',
                    style: TextStyle(color: Colors.orange[700]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '⏱️ El enlace expira en 1 hora',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  child: Text('Entendido'),
                ),
              ],
            ),
          );
        }
        
        // Cerrar sesión automáticamente hasta que verifique el email
        await _firebaseAuth.signOut();
      }
    } on FirebaseAuthException catch (error) {
      // Si Firebase devuelve un error (ej: email ya existe, contraseña incorrecta)
      var message = 'Ocurrió un error inesperado. Inténtalo de nuevo.';

      // Traducimos los códigos de error de Firebase a mensajes amigables
      switch (error.code) {
        case 'invalid-credential':
          message = 'El correo o la contraseña no son correctos. Por favor, verifica tus datos.';
          break;
        case 'user-not-found':
          message = 'No se encontró un usuario con ese correo electrónico.';
          break;
        case 'wrong-password':
          message = 'La contraseña no es correcta.';
          break;
        case 'email-already-in-use':
          message = 'Ya existe una cuenta con este correo electrónico.';
          break;
        case 'weak-password':
          message = 'La contraseña es demasiado débil. Debe tener al menos 6 caracteres.';
          break;
        case 'invalid-email':
          message = 'El formato del correo electrónico no es válido.';
          break;
        case 'too-many-requests':
          message = 'Demasiados intentos. Por favor, espera unos minutos e inténtalo de nuevo.';
          break;
      }

      // Mostramos el error al usuario en un SnackBar
      if (mounted) {
        AppToast.show(
          context,
          message: message,
          type: AppToastType.error,
        );
      }
    } catch (error) {
      // Para cualquier otro tipo de error
      if (mounted) {
        AppToast.show(
          context,
          message: 'Ocurrió un error inesperado.',
          type: AppToastType.error,
        );
      }
    } finally {
      // Pase lo que pase, dejamos de cargar
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resetPassword() {
    // Guardamos el email del formulario para no tener que volver a escribirlo
    _formKey.currentState?.save();
    if (_userEmail.isEmpty || !_userEmail.contains('@')) {
      AppToast.show(
        context,
        message: 'Por favor, introduce un email válido para restablecer la contraseña.',
        type: AppToastType.error,
      );
        return;
    }

    _firebaseAuth.sendPasswordResetEmail(email: _userEmail);

    AppToast.show(
      context,
      message: 'Se ha enviado un enlace para restablecer la contraseña a tu correo.',
      type: AppToastType.success,
    );
}

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // Título de la pantalla
                          Text(
                            _isLoginMode ? 'Bienvenido de nuevo' : 'Crea tu cuenta',
                            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isLoginMode ? 'Inicia sesión para continuar' : 'Regístrate para empezar a gestionar tu inventario',
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.65)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                
                          // Campo de Email
                          TextFormField(
                            key: const ValueKey('email'),
                            validator: (value) => (value == null || !value.contains('@')) ? 'Por favor, introduce un email válido.' : null,
                            onSaved: (value) => _userEmail = value!,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Campo de Contraseña
                          TextFormField(
                            key: const ValueKey('password'),
                            validator: (value) => (value == null || value.length < 7) ? 'La contraseña debe tener al menos 7 caracteres.' : null,
                            onSaved: (value) => _userPassword = value!,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                
                          if (_isLoginMode)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _resetPassword,
                                child: const Text('¿Olvidaste tu contraseña?'),
                              ),
                            ),
                          const SizedBox(height: 16),
                
                          // Botón principal y Spinner
                          if (_isLoading)
                            const Center(child: CircularProgressIndicator())
                          else
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _submitAuthForm,
                              child: Text(_isLoginMode ? 'Iniciar Sesión' : 'Registrarse'),
                            ),
                          const SizedBox(height: 8),
                
                          // Botón para cambiar de modo
                          if (!_isLoading)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_isLoginMode ? '¿No tienes una cuenta?' : '¿Ya tienes una cuenta?'),
                                TextButton(
                                  onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
                                  child: Text(_isLoginMode ? 'Regístrate' : 'Inicia Sesión'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Mostrar versión de la app
                if (_appVersion.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      _appVersion,
                      style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}