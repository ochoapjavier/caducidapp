// frontend/lib/screens/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // Instancia de FirebaseAuth
  final _firebaseAuth = FirebaseAuth.instance;

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
        await _firebaseAuth.signInWithEmailAndPassword(
          email: _userEmail,
          password: _userPassword,
        );
        // Si el login es exitoso, el stream de autenticación (que configuraremos después)
        // se encargará de navegar a la pantalla principal.
      } else {
        // Modo Registro
        await _firebaseAuth.createUserWithEmailAndPassword(
          email: _userEmail,
          password: _userPassword,
        );
        // Tras el registro, Firebase automáticamente inicia sesión con el nuevo usuario.
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
      }

      // Mostramos el error al usuario en un SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (error) {
      // Para cualquier otro tipo de error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ocurrió un error inesperado.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor, introduce un email válido para restablecer la contraseña.')),
        );
        return;
    }

    _firebaseAuth.sendPasswordResetEmail(email: _userEmail);

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se ha enviado un enlace para restablecer la contraseña a tu correo.')),
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
            child: Card(
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
          ),
        ),
      ),
    );
  }
}