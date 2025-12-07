import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shopping_item.dart';

import '../services/api_service.dart'; // Importar para usar baseUrl global

class ShoppingService {
  // Usamos la misma URL base que el resto de la app
  final String baseUrl = '$apiV1Url'; 

  Future<String?> _getToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  Future<List<ShoppingListItem>> getShoppingList(int hogarId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/shopping-list/hogar/$hogarId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => ShoppingListItem.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load shopping list');
    }
  }

  Future<ShoppingListItem> addItem(int hogarId, String nombre, {int cantidad = 1, int? fkProducto}) async {
    final token = await _getToken();
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) throw Exception('User not logged in');

    final response = await http.post(
      Uri.parse('$baseUrl/shopping-list/hogar/$hogarId?user_id=${user.uid}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'producto_nombre': nombre,
        'cantidad': cantidad,
        'fk_producto': fkProducto,
      }),
    );

    if (response.statusCode == 200) {
      return ShoppingListItem.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to add item');
    }
  }

  Future<ShoppingListItem> updateItem(int itemId, {bool? completado, int? cantidad}) async {
    final token = await _getToken();
    final Map<String, dynamic> body = {};
    if (completado != null) body['completado'] = completado;
    if (cantidad != null) body['cantidad'] = cantidad;

    final response = await http.patch(
      Uri.parse('$baseUrl/shopping-list/$itemId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return ShoppingListItem.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update item');
    }
  }

  Future<void> deleteItem(int itemId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/shopping-list/$itemId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete item');
    }
  }

  Future<void> moveToInventory(int itemId, int ubicacionId, DateTime fechaCaducidad) async {
    final token = await _getToken();
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) throw Exception('User not logged in');

    final response = await http.post(
      Uri.parse('$baseUrl/shopping-list/$itemId/to-inventory?ubicacion_id=$ubicacionId&fecha_caducidad=${fechaCaducidad.toIso8601String().split('T')[0]}&user_id=${user.uid}'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to move to inventory');
    }
  }
}
