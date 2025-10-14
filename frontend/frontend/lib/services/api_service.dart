// frontend/lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http; // Importamos el paquete http
import '../models/alerta.dart';
import '../models/ubicacion.dart';

// URL base de tu API Core (usando el host y el prefijo de FastAPI)
const String apiUrl = 'http://localhost:8000/api/v1/inventory';

// Función asíncrona para obtener las alertas de caducidad (Future)
Future<List<AlertaItem>> fetchAlertas() async {
  // Llama al endpoint HU4
  final response = await http.get(Uri.parse('$apiUrl/alertas/proxima-semana'));

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
  final response = await http.get(Uri.parse('$apiUrl/ubicaciones/'));

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
  final response = await http.post(
    Uri.parse('$apiUrl/ubicaciones/'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    // Crea el body JSON que espera FastAPI: {"nombre": "..."}
    body: jsonEncode(<String, String>{
      'nombre': nombre,
    }),
  );

  if (response.statusCode!= 200) {
    // Si da error 400 (ej. nombre duplicado), lanza excepción
    final errorBody = json.decode(response.body);
    throw Exception(errorBody['detail']?? 'Error desconocido al crear ubicación');
  }
}

// Función para eliminar una ubicación (DELETE /ubicaciones/{id})
Future<void> deleteUbicacion(int id) async {
  final response = await http.delete(
    Uri.parse('$apiUrl/ubicaciones/$id'),
  );

  if (response.statusCode != 200) {
    // Si el backend devuelve un error (ej. 404, 409), lo decodificamos y lanzamos.
    final errorBody = json.decode(response.body);
    throw Exception(errorBody['detail'] ?? 'Error desconocido al eliminar la ubicación.');
  }
}

// Función para actualizar una ubicación (PUT /ubicaciones/{id})
Future<void> updateUbicacion(int id, String newName) async {
  final response = await http.put(
    Uri.parse('$apiUrl/ubicaciones/$id'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
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