// frontend/lib/services/api_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/alerta.dart';
import '../models/ubicacion.dart';
import '../models/hogar.dart';
import 'hogar_service.dart';

// --- 2. GESTIÓN DE ENTORNO AUTOMÁTICA ---
// Usa la IP de tu máquina en la red local para pruebas en dispositivo físico.
// Si usas el emulador de Android, la IP para referirte al localhost de tu PC es 10.0.2.2.
const String _localBaseUrl = 'http://192.168.1.145:8000'; // <-- AJUSTA ESTA IP SI ES NECESARIO
const String _productionBaseUrl = 'https://caducidapp-api.onrender.com';

// kDebugMode es `true` en `flutter run` y `false` en `flutter build --release`.
const String baseUrl = kDebugMode ? _localBaseUrl : _productionBaseUrl;
const String apiPrefix = '/api/v1/inventory';
const String apiUrl = '$baseUrl$apiPrefix';
const String apiV1Url = '$baseUrl/api/v1'; // Base para otros servicios (ej. notificaciones)

// Función auxiliar para obtener las cabeceras con el token de autenticación
Future<Map<String, String>> _getAuthHeaders() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('Usuario no autenticado. No se puede realizar la petición.');
  }
  final idToken = await user.getIdToken();
  
  final headers = {
    'Content-Type': 'application/json; charset=UTF-8',
    'Authorization': 'Bearer $idToken',
  };
  
  // Añadir X-Hogar-Id si hay un hogar activo seleccionado
  final hogarService = HogarService();
  final hogarActivo = await hogarService.getHogarActivo();
  if (hogarActivo != null) {
    headers['X-Hogar-Id'] = hogarActivo.toString();
  }
  
  // DEBUG: Imprimir headers para depuración
  debugPrint('--- API REQUEST HEADERS ---');
  debugPrint('Authorization: Bearer ${idToken?.substring(0, 10) ?? "null"}...');
  if (headers.containsKey('X-Hogar-Id')) {
    debugPrint('X-Hogar-Id: ${headers['X-Hogar-Id']}');
  } else {
    debugPrint('X-Hogar-Id: NOT PRESENT');
  }
  debugPrint('---------------------------');
  
  return headers;
}

// Función asíncrona para obtener las alertas de caducidad (Future)
Future<List<AlertaItem>> fetchAlertas() async {
  final headers = await _getAuthHeaders();
  final response = await http.get(Uri.parse('$apiUrl/alertas/proxima-semana'), headers: headers);

  if (response.statusCode == 200) {
    final Map<String, dynamic> jsonBody = json.decode(response.body);
    final List<dynamic> rawList = jsonBody['productos_proximos_a_caducar'];
    return rawList.map((json) => AlertaItem.fromJson(json)).toList();
  } else {
    throw Exception('Error al cargar alertas: Código ${response.statusCode}. Asegúrate que el backend esté corriendo.');
  }
}

// Nueva función: Obtener todas las ubicaciones (GET /ubicaciones/)
Future<List<Ubicacion>> fetchUbicaciones() async {
  final headers = await _getAuthHeaders();
  final response = await http.get(Uri.parse('$apiUrl/ubicaciones/'), headers: headers);

  if (response.statusCode == 200) {
    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => Ubicacion.fromJson(json)).toList();
  } else {
    throw Exception('Error al cargar ubicaciones. Código de estado: ${response.statusCode}');
  }
}

// Nueva función: Crear una ubicación (POST /ubicaciones/)
Future<void> createUbicacion(String nombre, {bool esCongelador = false}) async {
  final headers = await _getAuthHeaders();
  final response = await http.post(
    Uri.parse('$apiUrl/ubicaciones/'),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      'nombre': nombre,
      'es_congelador': esCongelador,
    }),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
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
    final errorBody = json.decode(response.body);
    throw Exception(errorBody['detail'] ?? 'Error desconocido al eliminar la ubicación.');
  }
}

// Función para actualizar una ubicación (PUT /ubicaciones/{id})
Future<void> updateUbicacion(int id, String newName, {bool? esCongelador}) async {
  final headers = await _getAuthHeaders();
  
  final Map<String, dynamic> body = {'nombre': newName};
  if (esCongelador != null) {
    body['es_congelador'] = esCongelador;
  }
  
  final response = await http.put(
    Uri.parse('$apiUrl/ubicaciones/$id'),
    headers: headers,
    body: jsonEncode(body),
  );

  if (response.statusCode != 200) {
    final errorBody = json.decode(response.body);
    throw Exception(errorBody['detail'] ?? 'Error desconocido al actualizar la ubicación.');
  }
}

/// Añade un nuevo item de stock al inventario del usuario.
Future<void> addManualStockItem({
  required String productName,
  int? productId,
  String? brand,
  String? barcode,
  String? imageUrl,
  required int ubicacionId,
  required int cantidad,
  required DateTime fechaCaducidad,
}) async {
  final headers = await _getAuthHeaders();
  final response = await http.post(
    Uri.parse('$apiUrl/stock/manual'),
    headers: headers,
    body: jsonEncode({
      'product_name': productName,
      'product_id': productId,
      'brand': brand,
      'barcode': barcode,
      'image_url': imageUrl,
      'ubicacion_id': ubicacionId,
      'cantidad': cantidad,
      'fecha_caducidad': fechaCaducidad.toIso8601String().split('T').first,
    }),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    final errorBody = json.decode(response.body);
    throw Exception(errorBody['detail'] ?? 'Error desconocido al añadir el producto.');
  }
}

/// Busca un producto en nuestro catálogo por su código de barras.
Future<Map<String, dynamic>?> fetchProductFromCatalog(String barcode) async {
  final headers = await _getAuthHeaders();
  final response = await http.get(Uri.parse('$apiUrl/products/by-barcode/$barcode'), headers: headers);

  if (response.statusCode == 200) {
    return json.decode(utf8.decode(response.bodyBytes));
  }
  if (response.statusCode == 404) {
    return null;
  }
  throw Exception('Error al buscar producto en el catálogo: ${response.statusCode}');
}

/// Actualiza el nombre/marca de un producto en el catálogo maestro.
Future<void> updateProductInCatalog({
  required String barcode,
  required String name,
  String? brand,
}) async {
  final headers = await _getAuthHeaders();
  final response = await http.put(
    Uri.parse('$apiUrl/products/by-barcode/$barcode'),
    headers: headers,
    body: jsonEncode({
      'nombre': name,
      'marca': brand,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('Error al actualizar el producto en el catálogo: ${response.statusCode}');
  }
}

/// Busca un producto en la API de Open Food Facts usando su código de barras.
Future<Map<String, dynamic>?> fetchProductFromOpenFoodFacts(String barcode) async {
  final uri = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json');
  try {
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 0) {
        return null;
      }
      return data['product'];
    }
    return null;
  } catch (e) {
    return null;
  }
}

/// Añade un nuevo item de stock desde un escaneo.
Future<void> addScannedStockItem({
  required String barcode,
  required String productName,
  String? brand,
  required int ubicacionId,
  required int cantidad,
  required DateTime fechaCaducidad,
}) async {
  final headers = await _getAuthHeaders();
  final response = await http.post(
    Uri.parse('$apiUrl/stock/from-scan'),
    headers: headers,
    body: jsonEncode({
      'barcode': barcode,
      'product_name': productName,
      'brand': brand,
      'ubicacion_id': ubicacionId,
      'cantidad': cantidad,
      'fecha_caducidad': fechaCaducidad.toIso8601String().split('T').first,
    }),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    final errorBody = json.decode(response.body);
    throw Exception(errorBody['detail'] ?? 'Error desconocido al añadir el producto escaneado.');
  }
}

/// Obtiene todos los items de stock para el usuario actual.
Future<List<dynamic>> fetchStockItems({String? searchTerm}) async {
  final headers = await _getAuthHeaders();
  var uri = Uri.parse('$apiUrl/stock/');

  if (searchTerm != null && searchTerm.isNotEmpty) {
    uri = uri.replace(queryParameters: {'search': searchTerm});
  }

  final response = await http.get(uri, headers: headers);

  if (response.statusCode == 200) {
    return json.decode(utf8.decode(response.bodyBytes));
  } else {
    throw Exception('Error al cargar el inventario: ${response.statusCode}');
  }
}

/// Llama al endpoint para consumir una unidad de un item de stock.
Future<Map<String, dynamic>> consumeStockItem(int stockId) async {
  final headers = await _getAuthHeaders();
  final response = await http.patch(
    Uri.parse('$apiUrl/stock/$stockId/consume'),
    headers: headers,
  );

  if (response.statusCode == 200) {
    return json.decode(utf8.decode(response.bodyBytes));
  } else {
    try {
      final errorBody = json.decode(utf8.decode(response.bodyBytes));
      throw Exception(errorBody['detail'] ?? 'Error desconocido al consumir el producto.');
    } catch (e) {
      throw Exception('Error al consumir el producto. Código: ${response.statusCode}');
    }
  }
}

/// Llama al endpoint para eliminar una cantidad específica de un item de stock.
Future<Map<String, dynamic>> removeStockItems({
  required int stockId,
  required int cantidad,
}) async {
  final headers = await _getAuthHeaders();
  final response = await http.post(
    Uri.parse('$apiUrl/stock/remove'),
    headers: headers,
    body: jsonEncode({
      'id_stock': stockId,
      'cantidad': cantidad,
    }),
  );

  if (response.statusCode == 200) {
    return json.decode(utf8.decode(response.bodyBytes));
  } else {
    final errorBody = json.decode(utf8.decode(response.bodyBytes));
    throw Exception(errorBody['detail'] ?? 'Error desconocido al eliminar el producto.');
  }
}

/// Actualiza un item de stock.
Future<Map<String, dynamic>> updateStockItem({
  required int stockId,
  String? productName,
  String? brand,
  DateTime? fechaCaducidad,
  int? cantidadActual,
  int? ubicacionId,
}) async {
  final headers = await _getAuthHeaders();
  final body = <String, dynamic>{};
  if (productName != null) body['product_name'] = productName;
  if (brand != null) body['brand'] = brand;
  if (fechaCaducidad != null) body['fecha_caducidad'] = fechaCaducidad.toIso8601String().split('T').first;
  if (cantidadActual != null) body['cantidad_actual'] = cantidadActual;
  if (ubicacionId != null) body['ubicacion_id'] = ubicacionId;

  final response = await http.patch(
    Uri.parse('$apiUrl/stock/$stockId'),
    headers: headers,
    body: jsonEncode(body),
  );

  if (response.statusCode == 200) {
    try {
      return json.decode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return {};
    }
  } else if (response.statusCode == 404) {
    throw Exception('Item no encontrado.');
  } else {
    try {
      final errorBody = json.decode(utf8.decode(response.bodyBytes));
      throw Exception(errorBody['detail'] ?? 'Error al actualizar el item.');
    } catch (e) {
      throw Exception('Error al actualizar el item. Código: ${response.statusCode}');
    }
  }
}

// ============================================================================
// PRODUCT STATE MANAGEMENT ACTIONS
// ============================================================================

/// Abre unidades selladas de un producto.
Future<Map<String, dynamic>> openProduct({
  required int stockId,
  required int cantidad,
  int? nuevaUbicacionId,
  bool mantenerFechaCaducidad = true,
  int diasVidaUtil = 4,
}) async {
  final headers = await _getAuthHeaders();
  final body = {
    'cantidad': cantidad,
    'mantener_fecha_caducidad': mantenerFechaCaducidad,
    'dias_vida_util': diasVidaUtil,
    if (nuevaUbicacionId != null) 'nueva_ubicacion_id': nuevaUbicacionId,
  };

  final response = await http.post(
    Uri.parse('$apiUrl/stock/$stockId/open'),
    headers: headers,
    body: jsonEncode(body),
  );

  if (response.statusCode == 200) {
    return json.decode(utf8.decode(response.bodyBytes));
  } else {
    final errorBody = json.decode(utf8.decode(response.bodyBytes));
    throw Exception(errorBody['detail'] ?? 'Error al abrir el producto.');
  }
}

/// Congela unidades de un producto.
Future<Map<String, dynamic>> freezeProduct({
  required int stockId,
  required int cantidad,
  required int ubicacionCongeladorId,
}) async {
  final headers = await _getAuthHeaders();
  final body = {
    'cantidad': cantidad,
    'ubicacion_congelador_id': ubicacionCongeladorId,
  };

  final response = await http.post(
    Uri.parse('$apiUrl/stock/$stockId/freeze'),
    headers: headers,
    body: jsonEncode(body),
  );

  if (response.statusCode == 200) {
    return json.decode(utf8.decode(response.bodyBytes));
  } else {
    final errorBody = json.decode(utf8.decode(response.bodyBytes));
    throw Exception(errorBody['detail'] ?? 'Error al congelar el producto.');
  }
}

/// Descongela un producto congelado.
Future<Map<String, dynamic>> unfreezeProduct({
  required int stockId,
  required int cantidad,
  required int nuevaUbicacionId,
  int diasVidaUtil = 2,
}) async {
  final headers = await _getAuthHeaders();
  final body = {
    'cantidad': cantidad,
    'nueva_ubicacion_id': nuevaUbicacionId,
    'dias_vida_util': diasVidaUtil,
  };

  final response = await http.post(
    Uri.parse('$apiUrl/stock/$stockId/unfreeze'),
    headers: headers,
    body: jsonEncode(body),
  );

  if (response.statusCode == 200) {
    return json.decode(utf8.decode(response.bodyBytes));
  } else {
    final errorBody = json.decode(utf8.decode(response.bodyBytes));
    throw Exception(errorBody['detail'] ?? 'Error al descongelar el producto.');
  }
}

/// Mueve unidades de un producto a una ubicación diferente.
Future<Map<String, dynamic>> relocateProduct({
  required int stockId,
  required int cantidad,
  required int nuevaUbicacionId,
}) async {
  final headers = await _getAuthHeaders();
  final body = {
    'cantidad': cantidad,
    'nueva_ubicacion_id': nuevaUbicacionId,
  };

  final response = await http.post(
    Uri.parse('$apiUrl/stock/$stockId/relocate'),
    headers: headers,
    body: jsonEncode(body),
  );

  if (response.statusCode == 200) {
    return json.decode(utf8.decode(response.bodyBytes));
  } else {
    final errorBody = json.decode(utf8.decode(response.bodyBytes));
    throw Exception(errorBody['detail'] ?? 'Error al reubicar el producto.');
  }
}

// ============================================================================
// GESTIÓN DE HOGARES - Sistema Multihogar
// ============================================================================

/// Obtener la lista de hogares del usuario autenticado
Future<List<Hogar>> fetchHogares() async {
  final headers = await _getAuthHeaders();
  final response = await http.get(
    Uri.parse('$apiUrl/hogares'),
    headers: headers,
  );

  if (response.statusCode == 200) {
    final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
    return jsonList.map((json) => Hogar.fromJson(json)).toList();
  } else {
    throw Exception('Error al cargar hogares. Código: ${response.statusCode}');
  }
}

/// Obtener los detalles completos de un hogar (incluyendo miembros)
Future<HogarDetalle> fetchHogarDetalle(int hogarId) async {
  final headers = await _getAuthHeaders();
  final response = await http.get(
    Uri.parse('$apiUrl/hogares/$hogarId'),
    headers: headers,
  );

  if (response.statusCode == 200) {
    return HogarDetalle.fromJson(json.decode(utf8.decode(response.bodyBytes)));
  } else {
    final errorBody = json.decode(utf8.decode(response.bodyBytes));
    throw Exception(errorBody['detail'] ?? 'Error al cargar detalles del hogar');
  }
}

/// Crear un nuevo hogar
Future<Hogar> createHogar(String nombre, {String icono = 'home'}) async {
  final headers = await _getAuthHeaders();
  final response = await http.post(
    Uri.parse('$apiUrl/hogares'),
    headers: headers,
    body: jsonEncode({
      'nombre': nombre,
      'icono': icono,
    }),
  );

  if (response.statusCode == 200 || response.statusCode == 201) {
    return Hogar.fromJson(json.decode(utf8.decode(response.bodyBytes)));
  } else {
    final errorBody = json.decode(utf8.decode(response.bodyBytes));
    throw Exception(errorBody['detail'] ?? 'Error al crear hogar');
  }
}

/// Unirse a un hogar existente usando un código de invitación
Future<void> unirseAHogar(String codigoInvitacion) async {
  final headers = await _getAuthHeaders();
  final response = await http.post(
    Uri.parse('$apiUrl/hogares/unirse'),
    headers: headers,
    body: jsonEncode({
      'codigo_invitacion': codigoInvitacion.toUpperCase(),
    }),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    final errorBody = json.decode(utf8.decode(response.bodyBytes));
    throw Exception(errorBody['detail'] ?? 'Error al unirse al hogar');
  }
}

/// Regenerar el código de invitación de un hogar (solo admin)
Future<String> regenerarCodigoInvitacion(int hogarId) async {
  final headers = await _getAuthHeaders();
  final response = await http.post(
    Uri.parse('$apiUrl/hogares/$hogarId/invitacion/regenerar'),
    headers: headers,
  );

  if (response.statusCode == 200) {
    final body = json.decode(utf8.decode(response.bodyBytes));
    return body['nuevo_codigo'];
  } else {
    final errorBody = json.decode(utf8.decode(response.bodyBytes));
    throw Exception(errorBody['detail'] ?? 'Error al regenerar código');
  }
}

/// Abandonar un hogar
Future<void> abandonarHogar(int hogarId) async {
  final headers = await _getAuthHeaders();
  final response = await http.post(
    Uri.parse('$apiUrl/hogares/$hogarId/abandonar'),
    headers: headers,
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    final errorBody = json.decode(utf8.decode(response.bodyBytes));
    throw Exception(errorBody['detail'] ?? 'Error al abandonar hogar');
  }
}

/// Expulsar a un miembro del hogar (solo admin)
Future<void> expulsarMiembro(int hogarId, String userId) async {
  final headers = await _getAuthHeaders();
  final response = await http.delete(
    Uri.parse('$apiUrl/hogares/$hogarId/miembros/$userId'),
    headers: headers,
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    final errorBody = json.decode(utf8.decode(response.bodyBytes));
    throw Exception(errorBody['detail'] ?? 'Error al expulsar miembro');
  }
}

/// Cambiar el rol de un miembro (solo admin)
Future<void> cambiarRolMiembro(int hogarId, String userId, String nuevoRol) async {
  final headers = await _getAuthHeaders();
  final response = await http.put(
    Uri.parse('$apiUrl/hogares/$hogarId/miembros/$userId/rol'),
    headers: headers,
    body: jsonEncode({
      'nuevo_rol': nuevoRol,
    }),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    final errorBody = json.decode(utf8.decode(response.bodyBytes));
    throw Exception(errorBody['detail'] ?? 'Error al cambiar rol');
  }
}

/// Actualizar nombre e icono de un hogar (solo admin)
Future<Hogar> updateHogar(int hogarId, String nombre, String icono) async {
  final headers = await _getAuthHeaders();
  final response = await http.put(
    Uri.parse('$apiUrl/hogares/$hogarId'),
    headers: headers,
    body: jsonEncode({
      'nombre': nombre,
      'icono': icono,
    }),
  );

  if (response.statusCode == 200) {
    return Hogar.fromJson(json.decode(utf8.decode(response.bodyBytes)));
  } else {
    final errorBody = json.decode(utf8.decode(response.bodyBytes));
    throw Exception(errorBody['detail'] ?? 'Error al actualizar hogar');
  }
}

/// Actualizar el apodo del miembro actual dentro de un hogar
Future<void> updateMyApodo(int hogarId, String apodo) async {
  final headers = await _getAuthHeaders();
  final response = await http.put(
    Uri.parse('$apiUrl/hogares/$hogarId/miembros/mi-apodo'),
    headers: headers,
    body: jsonEncode({'apodo': apodo}),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    final errorBody = json.decode(utf8.decode(response.bodyBytes));
    throw Exception(errorBody['detail'] ?? 'Error al actualizar apodo');
  }
}