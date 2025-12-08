class AppException implements Exception {
  final String message;
  final String? prefix;

  AppException([this.message = "Algo salió mal", this.prefix]);

  @override
  String toString() {
    return "$prefix$message";
  }
}

class NetworkException extends AppException {
  NetworkException([String message = "No hay conexión a internet"]) 
      : super(message, "Error de Red: ");
}

class AuthException extends AppException {
  AuthException([String message = "Sesión expirada o inválida"]) 
      : super(message, "Error de Autenticación: ");
}

class ServerException extends AppException {
  ServerException([String message = "Error en el servidor"]) 
      : super(message, "Error del Servidor: ");
}

class ValidationException extends AppException {
  ValidationException([String message = "Datos inválidos"]) 
      : super(message, "Error de Validación: ");
}

class UnknownException extends AppException {
  UnknownException([String message = "Error desconocido"]) 
      : super(message, "");
}
