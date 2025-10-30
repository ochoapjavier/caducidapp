// frontend/lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http; // Importamos el paquete http
import 'package:firebase_auth/firebase_auth.dart'; // Importamos Firebase Auth
import '../models/alerta.dart';
import '../models/ubicacion.dart';

// URL base de tu API Core (usando el host y el prefijo de FastAPI)
const String apiUrl = 'http://localhost:8000/api/v1/inventory';

// Función auxiliar para obtener las cabeceras con el token de autenticación
Future<Map<String, String>> _getAuthHeaders() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    // Si no hay usuario, no podemos enviar el token.
    // Podrías lanzar un error o manejarlo según la lógica de tu app.
    throw Exception('Usuario no autenticado. No se puede realizar la petición.');
  }
  final idToken = await user.getIdToken();
  return {
    'Content-Type': 'application/json; charset=UTF-8',
    'Authorization': 'Bearer $idToken',
  };
}

// Función asíncrona para obtener las alertas de caducidad (Future)
Future<List<AlertaItem>> fetchAlertas() async {
  final headers = await _getAuthHeaders();
  final response = await http.get(Uri.parse('$apiUrl/alertas/proxima-semana'), headers: headers);

  if (response.statusCode == 200) {
    // 1. Decodificar el cuerpo JSON (string) a un mapa de Dart
    final Map<String, dynamic> jsonBody = json.decode(response.body);
    
    // 2. Extraer la lista que está bajo la clave 'productos_proximos_a_caducar'
    final List<dynamic> rawList = jsonBody['productos_proximos_a_caducar'];

    // 3. Mapear la lista de JSONs a la lista de objetos AlertaItem
    return rawList.map((json) => AlertaItem.fromJson(json)).toList();
    
  } else {
    // Lanza una excepción si el backend responde con error 
    throw Exception('Error al cargar alertas: Código ${response.statusCode}. Asegúrate que el backend esté corriendo.');
  }
}

// Nueva función: Obtener todas las ubicaciones (GET /ubicaciones/)
Future<List<Ubicacion>> fetchUbicaciones() async {
  final headers = await _getAuthHeaders();
  final response = await http.get(Uri.parse('$apiUrl/ubicaciones/'), headers: headers);

  if (response.statusCode == 200) {
    // 1. El API devuelve una lista de objetos JSON, así que decodificamos directamente a una Lista.
    final List<dynamic> jsonList = json.decode(response.body);

    // 2. Mapeamos cada objeto JSON de la lista a un objeto Ubicacion usando el constructor .fromJson.
    return jsonList.map((json) => Ubicacion.fromJson(json)).toList();
    
  } else {
    // Lanza una excepción si el backend responde con error.
    throw Exception('Error al cargar ubicaciones. Código de estado: ${response.statusCode}');
  }
}

// Nueva función: Crear una ubicación (POST /ubicaciones/)
Future<void> createUbicacion(String nombre) async {
  final headers = await _getAuthHeaders();
  final response = await http.post(
    Uri.parse('$apiUrl/ubicaciones/'),
    headers: headers,
    // Crea el body JSON que espera FastAPI: {"nombre": "..."}
    body: jsonEncode(<String, String>{
      'nombre': nombre,
    }),
  );

  // Un código de estado que no está en el rango 2xx (ej. 200, 201) indica un error.
  if (response.statusCode < 200 || response.statusCode >= 300) {
    // Si da error 400 (ej. nombre duplicado), lanza excepción
    final errorBody = json.decode(response.body);
    throw Exception(errorBody['detail']?? 'Error desconocido al crear ubicación');
  }
}

// Función para eliminar una ubicación (DELETE /ubicaciones/{id})
Future<void> deleteUbicacion(int id) async {
  final headers = await _getAuthHeaders();
  final response = await http.delete(
    Uri.parse('$apiUrl/ubicaciones/$id'),
    headers: headers,
  );

  if (response.statusCode != 200) {
    // Si el backend devuelve un error (ej. 404, 409), lo decodificamos y lanzamos.
    final errorBody = json.decode(response.body);
    throw Exception(errorBody['detail'] ?? 'Error desconocido al eliminar la ubicación.');
  }
}

// Función para actualizar una ubicación (PUT /ubicaciones/{id})
Future<void> updateUbicacion(int id, String newName) async {
  final headers = await _getAuthHeaders();
  final response = await http.put(
    Uri.parse('$apiUrl/ubicaciones/$id'),
    headers: headers,
    body: jsonEncode(<String, String>{
      'nombre': newName,
    }),
  );

  if (response.statusCode != 200) {
    // Si el backend devuelve un error (ej. 404, 409), lo decodificamos y lanzamos.
    final errorBody = json.decode(response.body);
    throw Exception(errorBody['detail'] ?? 'Error desconocido al actualizar la ubicación.');
  }
}

/// Añade un nuevo item de stock al inventario del usuario.
Future<void> addManualStockItem({
  required String productName,
  required int ubicacionId,
  required int cantidad,
  required DateTime fechaCaducidad,
}) async {
  final headers = await _getAuthHeaders();
  final response = await http.post(
    Uri.parse('$apiUrl/stock/manual'), // El nuevo endpoint
    headers: headers,
    body: jsonEncode({
      'product_name': productName,
      'ubicacion_id': ubicacionId,
      'cantidad': cantidad,
      // Formateamos la fecha a 'YYYY-MM-DD'
      'fecha_caducidad': fechaCaducidad.toIso8601String().split('T').first,
    }),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    final errorBody = json.decode(response.body);
    throw Exception(errorBody['detail'] ?? 'Error desconocido al añadir el producto.');
  }
}