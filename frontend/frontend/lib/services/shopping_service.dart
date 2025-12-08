import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shopping_item.dart';

import '../services/api_service.dart'; // Importar para usar baseUrl global y safeApiCall

class ShoppingService {
  // Usamos la misma URL base que el resto de la app
  final String baseUrl = '$apiV1Url'; 

  Future<List<ShoppingListItem>> getShoppingList(int hogarId) async {
    return safeApiCall(() async {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/shopping-list/hogar/$hogarId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        return body.map((dynamic item) => ShoppingListItem.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load shopping list');
      }
    });
  }

  Future<ShoppingListItem> addItem(int hogarId, String nombre, {int cantidad = 1, int? fkProducto}) async {
    return safeApiCall(() async {
      final headers = await getAuthHeaders();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final response = await http.post(
        Uri.parse('$baseUrl/shopping-list/hogar/$hogarId?user_id=${user.uid}'),
        headers: headers,
        body: jsonEncode({
          'producto_nombre': nombre,
          'cantidad': cantidad,
          'fk_producto': fkProducto,
        }),
      );

      if (response.statusCode == 200) {
        return ShoppingListItem.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception('Failed to add item');
      }
    });
  }

  Future<ShoppingListItem> updateItem(int itemId, {bool? completado, int? cantidad}) async {
    return safeApiCall(() async {
      final headers = await getAuthHeaders();
      final Map<String, dynamic> body = {};
      if (completado != null) body['completado'] = completado;
      if (cantidad != null) body['cantidad'] = cantidad;

      final response = await http.patch(
        Uri.parse('$baseUrl/shopping-list/$itemId'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return ShoppingListItem.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception('Failed to update item');
      }
    });
  }

  Future<void> deleteItem(int itemId) async {
    return safeApiCall(() async {
      final headers = await getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/shopping-list/$itemId'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete item');
      }
    });
  }

  Future<void> moveToInventory(int itemId, int ubicacionId, DateTime fechaCaducidad) async {
    return safeApiCall(() async {
      final headers = await getAuthHeaders();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final response = await http.post(
        Uri.parse('$baseUrl/shopping-list/$itemId/to-inventory?ubicacion_id=$ubicacionId&fecha_caducidad=${fechaCaducidad.toIso8601String().split('T')[0]}&user_id=${user.uid}'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to move to inventory');
      }
    });
  }
}
