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
      var message = 'Ocurrió un error, por favor revisa tus credenciales.';
      if (error.message != null) {
        message = error.message!;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: SingleChildScrollView(
          child: Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      key: const ValueKey('email'),
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return 'Por favor, introduce un email válido.';
                        }
                        return null;
                      },
                      onSaved: (value) => _userEmail = value!,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    TextFormField(
                      key: const ValueKey('password'),
                      validator: (value) {
                        if (value == null || value.length < 7) {
                          return 'La contraseña debe tener al menos 7 caracteres.';
                        }
                        return null;
                      },
                      onSaved: (value) => _userPassword = value!,
                      obscureText: true, // Oculta la contraseña
                      decoration: const InputDecoration(labelText: 'Contraseña'),
                    ),
                    const SizedBox(height: 20),
                    if (_isLoading) const CircularProgressIndicator(),
                    if (!_isLoading)
                      ElevatedButton(
                        onPressed: _submitAuthForm,
                        child: Text(_isLoginMode ? 'Iniciar Sesión' : 'Registrarse'),
                      ),
                    if (!_isLoading)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLoginMode = !_isLoginMode;
                          });
                        },
                        child: Text(_isLoginMode
                            ? 'Crear una nueva cuenta'
                            : 'Ya tengo una cuenta'),
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