import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart'; // To access apiUrl, getAuthHeaders, and safeApiCall

class Location {
  final int id;
  final String nombre;
  final bool esCongelador;

  Location({
    required this.id,
    required this.nombre,
    required this.esCongelador,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id_ubicacion'],
      nombre: json['nombre'],
      esCongelador: json['es_congelador'] ?? false,
    );
  }
}

class LocationService {
  
  Future<List<Location>> getLocations(int hogarId) async {
    return safeApiCall(() async {
      final headers = await getAuthHeaders();
      final response = await http.get(Uri.parse('$apiUrl/ubicaciones/'), headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((json) => Location.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar ubicaciones: ${response.statusCode}');
      }
    });
  }

  Future<Location> createLocation(int hogarId, String nombre, bool esCongelador) async {
    return safeApiCall(() async {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('$apiUrl/ubicaciones/'),
        headers: headers,
        body: jsonEncode({
          'nombre': nombre,
          'es_congelador': esCongelador,
          'hogar_id': hogarId,
        }),
      );

      if (response.statusCode == 201) {
        return Location.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception('Error al crear ubicación: ${response.body}');
      }
    });
  }

  Future<Location> updateLocation(int locationId, String nombre, bool esCongelador) async {
    return safeApiCall(() async {
      final headers = await getAuthHeaders();
      final response = await http.put(
        Uri.parse('$apiUrl/ubicaciones/$locationId'),
        headers: headers,
        body: jsonEncode({
          'nombre': nombre,
          'es_congelador': esCongelador,
        }),
      );

      if (response.statusCode == 200) {
        return Location.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception('Error al actualizar ubicación: ${response.body}');
      }
    });
  }

  Future<void> deleteLocation(int locationId) async {
    return safeApiCall(() async {
      final headers = await getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$apiUrl/ubicaciones/$locationId'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Error al eliminar ubicación: ${response.body}');
      }
    });
  }
}
