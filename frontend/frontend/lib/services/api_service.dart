// frontend/lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/alerta.dart';
import '../models/ubicacion.dart';
import '../models/hogar.dart';
import 'hogar_service.dart';
import 'app_exceptions.dart';

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

// Wrapper global para manejar excepciones de red y servidor
Future<T> safeApiCall<T>(Future<T> Function() apiCall) async {
  try {
    return await apiCall();
  } on SocketException {
    throw NetworkException('No hay conexión a internet (Socket)');
  } on http.ClientException catch (e) {
    // Captura errores de conexión en Web (CORS, servidor caído, sin internet)
    debugPrint('ClientException caught: $e');
    throw NetworkException('No hay conexión a internet o servidor inaccesible');
  } on FormatException catch (_) {
    throw ServerException('Respuesta inválida del servidor');
  } catch (e) {
    // Si ya es una de nuestras excepciones, la dejamos pasar
    if (e is AppException) rethrow;
    // Si no, la empaquetamos como desconocida o servidor
    debugPrint('Unknown exception in safeApiCall: $e');
    throw ServerException('Error inesperado: $e');
  }
}

// Helper para procesar respuestas HTTP y lanzar excepciones personalizadas
dynamic _processResponse(http.Response response) {
  switch (response.statusCode) {
    case 200:
    case 201:
      // Si el cuerpo está vacío, devolvemos null o mapa vacío según convenga
      if (response.body.isEmpty) return {};
      return json.decode(utf8.decode(response.bodyBytes));
    case 400:
      final body = json.decode(utf8.decode(response.bodyBytes));
      throw ValidationException(body['detail'] ?? 'Datos inválidos');
    case 401:
    case 403:
      throw AuthException('Sesión expirada o sin permisos');
    case 404:
      // A veces 404 es un resultado válido (ej. buscar producto), 
      // pero por defecto lo tratamos como excepción si no se maneja antes.
      throw ValidationException('Recurso no encontrado'); 
    case 500:
    default:
      throw ServerException('Error del servidor (${response.statusCode})');
  }
}

// Función auxiliar para obtener las cabeceras con el token de autenticación
Future<Map<String, String>> getAuthHeaders() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw AuthException('Usuario no autenticado. No se puede realizar la petición.');
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
  
  return headers;
}

// Función asíncrona para obtener las alertas de caducidad (Future)
Future<List<AlertaItem>> fetchAlertas() async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.get(Uri.parse('$apiUrl/alertas/proxima-semana'), headers: headers);
    final jsonBody = _processResponse(response);
    final List<dynamic> rawList = jsonBody['productos_proximos_a_caducar'];
    return rawList.map((json) => AlertaItem.fromJson(json)).toList();
  });
}

// Nueva función: Obtener todas las ubicaciones (GET /ubicaciones/)
Future<List<Ubicacion>> fetchUbicaciones() async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.get(Uri.parse('$apiUrl/ubicaciones/'), headers: headers);
    final List<dynamic> jsonList = _processResponse(response);
    return jsonList.map((json) => Ubicacion.fromJson(json)).toList();
  });
}

// Nueva función: Crear una ubicación (POST /ubicaciones/)
Future<void> createUbicacion(String nombre, {bool esCongelador = false}) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$apiUrl/ubicaciones/'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'nombre': nombre,
        'es_congelador': esCongelador,
      }),
    );
    _processResponse(response);
  });
}

// Función para eliminar una ubicación (DELETE /ubicaciones/{id})
Future<void> deleteUbicacion(int id) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.delete(
      Uri.parse('$apiUrl/ubicaciones/$id'),
      headers: headers,
    );
    if (response.statusCode != 200) {
       _processResponse(response); // Will throw exception
    }
  });
}

// Función para actualizar una ubicación (PUT /ubicaciones/{id})
Future<void> updateUbicacion(int id, String newName, {bool? esCongelador}) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    
    final Map<String, dynamic> body = {'nombre': newName};
    if (esCongelador != null) {
      body['es_congelador'] = esCongelador;
    }
    
    final response = await http.put(
      Uri.parse('$apiUrl/ubicaciones/$id'),
      headers: headers,
      body: jsonEncode(body),
    );
    _processResponse(response);
  });
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
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
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
    _processResponse(response);
  });
}

/// Busca un producto en nuestro catálogo por su código de barras.
Future<Map<String, dynamic>?> fetchProductFromCatalog(String barcode) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.get(Uri.parse('$apiUrl/products/by-barcode/$barcode'), headers: headers);

    if (response.statusCode == 404) return null;
    return _processResponse(response);
  });
}

/// Actualiza el nombre/marca de un producto en el catálogo maestro.
Future<void> updateProductInCatalog({
  required String barcode,
  required String name,
  String? brand,
}) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.put(
      Uri.parse('$apiUrl/products/by-barcode/$barcode'),
      headers: headers,
      body: jsonEncode({
        'nombre': name,
        'marca': brand,
      }),
    );
    _processResponse(response);
  });
}

/// Busca productos maestros por nombre (para autocompletado).
Future<List<Map<String, dynamic>>> fetchMasterProducts(String query) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/products/search?query=$query'),
      headers: headers,
    );
    final List<dynamic> data = _processResponse(response);
    return data.cast<Map<String, dynamic>>();
  });
}

/// Obtiene sugerencias de ubicación para una lista de productos (Smart Grouping).
Future<Map<int, int>> getProductSuggestions(List<int> productIds) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$apiUrl/products/suggestions'),
      headers: headers,
      body: jsonEncode(productIds),
    );
    final Map<String, dynamic> data = _processResponse(response);
    // Convert String keys to Int keys
    return data.map((key, value) => MapEntry(int.parse(key), value as int));
  });
}

/// Busca un producto en la API de Open Food Facts usando su código de barras.
Future<Map<String, dynamic>?> fetchProductFromOpenFoodFacts(String barcode) async {
  // No usamos safeApiCall aquí porque queremos manejar el error silenciosamente o devolver null
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
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
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
    _processResponse(response);
  });
}

/// Obtiene todos los items de stock para el usuario actual.
Future<List<dynamic>> fetchStockItems({
  String? searchTerm,
  List<String>? statusFilter,
  String? sortBy,
}) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    var uri = Uri.parse('$apiUrl/stock/');

    final queryParams = <String, dynamic>{};
    if (searchTerm != null && searchTerm.isNotEmpty) {
      queryParams['search'] = searchTerm;
    }
    if (statusFilter != null && statusFilter.isNotEmpty) {
      // FastAPI expects repeated keys for list: ?status=congelado&status=abierto
      // Dart's Uri.replace(queryParameters) handles List<String> correctly by repeating keys
      queryParams['status'] = statusFilter;
    }
    if (sortBy != null && sortBy.isNotEmpty) {
      queryParams['sort'] = sortBy;
    }

    if (queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final response = await http.get(uri, headers: headers);
    return _processResponse(response);
  });
}

/// Llama al endpoint para consumir una unidad de un item de stock.
Future<Map<String, dynamic>> consumeStockItem(int stockId) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.patch(
      Uri.parse('$apiUrl/stock/$stockId/consume'),
      headers: headers,
    );
    return _processResponse(response);
  });
}

/// Llama al endpoint para eliminar una cantidad específica de un item de stock.
Future<Map<String, dynamic>> removeStockItems({
  required int stockId,
  required int cantidad,
}) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$apiUrl/stock/remove'),
      headers: headers,
      body: jsonEncode({
        'id_stock': stockId,
        'cantidad': cantidad,
      }),
    );
    return _processResponse(response);
  });
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
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final body = <String, dynamic>{};
    if (productName != null) body['product_name'] = productName;
    if (brand != null) body['brand'] = brand;
    if (fechaCaducidad != null) body['fecha_caducidad'] = fechaCaducidad.toIso8601String().split('T').first;
    if (cantidadActual != null) body['cantidad_actual'] = cantidadActual;
    if (ubicacionId != null) body['ubicacion_id'] = ubicacionId;
    if (ubicacionId != null) body['ubicacion_id'] = ubicacionId;

    final response = await http.patch(
      Uri.parse('$apiUrl/stock/$stockId'),
      headers: headers,
      body: jsonEncode(body),
    );
    
    if (response.statusCode == 404) throw ValidationException('Item no encontrado');
    return _processResponse(response);
  });
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
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
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
    return _processResponse(response);
  });
}

/// Congela unidades de un producto.
Future<Map<String, dynamic>> freezeProduct({
  required int stockId,
  required int cantidad,
  required int ubicacionCongeladorId,
}) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final body = {
      'cantidad': cantidad,
      'ubicacion_congelador_id': ubicacionCongeladorId,
    };

    final response = await http.post(
      Uri.parse('$apiUrl/stock/$stockId/freeze'),
      headers: headers,
      body: jsonEncode(body),
    );
    return _processResponse(response);
  });
}

/// Descongela un producto congelado.
Future<Map<String, dynamic>> unfreezeProduct({
  required int stockId,
  required int cantidad,
  required int nuevaUbicacionId,
  int diasVidaUtil = 2,
}) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
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
    return _processResponse(response);
  });
}

/// Mueve unidades de un producto a una ubicación diferente.
Future<Map<String, dynamic>> relocateProduct({
  required int stockId,
  required int cantidad,
  required int nuevaUbicacionId,
}) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final body = {
      'cantidad': cantidad,
      'nueva_ubicacion_id': nuevaUbicacionId,
    };

    final response = await http.post(
      Uri.parse('$apiUrl/stock/$stockId/relocate'),
      headers: headers,
      body: jsonEncode(body),
    );
    return _processResponse(response);
  });
}

// ============================================================================
// GESTIÓN DE HOGARES - Sistema Multihogar
// ============================================================================

/// Obtener la lista de hogares del usuario autenticado
Future<List<Hogar>> fetchHogares() async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/hogares'),
      headers: headers,
    );
    final List<dynamic> jsonList = _processResponse(response);
    return jsonList.map((json) => Hogar.fromJson(json)).toList();
  });
}

/// Obtener los detalles completos de un hogar (incluyendo miembros)
Future<HogarDetalle> fetchHogarDetalle(int hogarId) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.get(
      Uri.parse('$apiUrl/hogares/$hogarId'),
      headers: headers,
    );
    return HogarDetalle.fromJson(_processResponse(response));
  });
}

/// Crear un nuevo hogar
Future<Hogar> createHogar(String nombre, {String icono = 'home'}) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$apiUrl/hogares'),
      headers: headers,
      body: jsonEncode({
        'nombre': nombre,
        'icono': icono,
      }),
    );
    return Hogar.fromJson(_processResponse(response));
  });
}

/// Unirse a un hogar existente usando un código de invitación
Future<void> unirseAHogar(String codigoInvitacion) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$apiUrl/hogares/unirse'),
      headers: headers,
      body: jsonEncode({
        'codigo_invitacion': codigoInvitacion.toUpperCase(),
      }),
    );
    _processResponse(response);
  });
}

/// Regenerar el código de invitación de un hogar (solo admin)
Future<String> regenerarCodigoInvitacion(int hogarId) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$apiUrl/hogares/$hogarId/invitacion/regenerar'),
      headers: headers,
    );
    final body = _processResponse(response);
    return body['nuevo_codigo'];
  });
}

/// Abandonar un hogar
Future<void> abandonarHogar(int hogarId) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('$apiUrl/hogares/$hogarId/abandonar'),
      headers: headers,
    );
    _processResponse(response);
  });
}

/// Expulsar a un miembro del hogar (solo admin)
Future<void> expulsarMiembro(int hogarId, String userId) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.delete(
      Uri.parse('$apiUrl/hogares/$hogarId/miembros/$userId'),
      headers: headers,
    );
    _processResponse(response);
  });
}

/// Cambiar el rol de un miembro (solo admin)
Future<void> cambiarRolMiembro(int hogarId, String userId, String nuevoRol) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.put(
      Uri.parse('$apiUrl/hogares/$hogarId/miembros/$userId/rol'),
      headers: headers,
      body: jsonEncode({
        'nuevo_rol': nuevoRol,
      }),
    );
    _processResponse(response);
  });
}

/// Actualizar nombre e icono de un hogar (solo admin)
Future<Hogar> updateHogar(int hogarId, String nombre, String icono) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.put(
      Uri.parse('$apiUrl/hogares/$hogarId'),
      headers: headers,
      body: jsonEncode({
        'nombre': nombre,
        'icono': icono,
      }),
    );
    return Hogar.fromJson(_processResponse(response));
  });
}

/// Actualizar el apodo del miembro actual dentro de un hogar
Future<void> updateMyApodo(int hogarId, String apodo) async {
  return safeApiCall(() async {
    final headers = await getAuthHeaders();
    final response = await http.put(
      Uri.parse('$apiUrl/hogares/$hogarId/miembros/mi-apodo'),
      headers: headers,
      body: jsonEncode({'apodo': apodo}),
    );
    _processResponse(response);
  });
}