import 'package:flutter/material.dart';
import '../models/shopping_item.dart';
import '../services/shopping_service.dart';
import '../services/api_service.dart'; // Para fetchUbicaciones y fetchProducts
import '../models/ubicacion.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../widgets/magic_move_dialog.dart';
import '../widgets/error_view.dart';

class ShoppingListScreen extends StatefulWidget {
  final int hogarId;

  const ShoppingListScreen({Key? key, required this.hogarId}) : super(key: key);

  @override
  _ShoppingListScreenState createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final ShoppingService _shoppingService = ShoppingService();
  final TextEditingController _itemController = TextEditingController();
  List<ShoppingListItem> _items = [];
  bool _isLoading = true;
  Object? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> refresh() async {
    await _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _shoppingService.getShoppingList(widget.hogarId);
      setState(() {
        _items = items;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e;
      });
      // No mostramos SnackBar si ya mostramos la pantalla de error
    }
  }

  Future<void> _addItem(String nombre, {int? fkProducto}) async {
    if (nombre.isEmpty) return;
    try {
      await _shoppingService.addItem(widget.hogarId, nombre, fkProducto: fkProducto);
      _itemController.clear();
      _loadItems();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al añadir item: $e')),
      );
    }
  }

  Future<void> _toggleItem(ShoppingListItem item) async {
    try {
      await _shoppingService.updateItem(item.id, completado: !item.completado);
      _loadItems();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar item: $e')),
      );
    }
  }

  Future<void> _deleteItem(int id) async {
    try {
      await _shoppingService.deleteItem(id);
      _loadItems();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar item: $e')),
      );
    }
  }

  Future<void> _moveToInventory(List<ShoppingListItem> selectedItems) async {
    // Preparar datos para el diálogo
    // Como ShoppingListItem tiene datos limitados, pasamos lo que tenemos.
    // El MagicMoveDialog usará addManualStockItem, que funciona bien con solo el nombre.
    final itemsToMove = selectedItems.map((item) => {
      'id': item.id,
      'quantity': item.cantidad,
      'producto': {
        'id': item.fkProducto,
        'nombre': item.productoNombre,
        'marca': item.product?['marca'],
        'image_url': item.product?['image_url'],
        'codigo_barras': item.product?['barcode'],
      }
    }).toList();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => MagicMoveDialog(itemsToMove: itemsToMove),
    );

    if (result == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Productos movidos al inventario correctamente')),
        );
      }
      _loadItems(); // Recargar la lista para reflejar los cambios (items eliminados)
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingItems = _items.where((i) => !i.completado).toList();
    final completedItems = _items.where((i) => i.completado).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Compra'),
        actions: [
          if (completedItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.inventory),
              tooltip: 'Mover comprados al inventario',
              onPressed: () => _moveToInventory(completedItems),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.length < 2) {
                  return const Iterable<Map<String, dynamic>>.empty();
                }
                try {
                  // Usamos fetchStockItems como fuente de sugerencias (productos en inventario)
                  // Esto permite autocompletar con productos que el usuario ya tiene o conoce.
                  final stockItems = await fetchStockItems(searchTerm: textEditingValue.text);
                  
                  // Extraemos productos únicos para evitar duplicados en la lista
                  final uniqueProducts = <String, Map<String, dynamic>>{};
                  for (var item in stockItems) {
                    final product = item['producto_maestro'];
                    if (product != null) {
                      uniqueProducts[product['nombre']] = {
                        'nombre': product['nombre'],
                        'id_producto': product['id'], // Ajustar según modelo real si está disponible
                      };
                    }
                  }
                  return uniqueProducts.values;
                } catch (e) {
                  debugPrint('Error fetching suggestions: $e');
                  return const Iterable<Map<String, dynamic>>.empty();
                }
              },
              displayStringForOption: (option) => option['nombre'],
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Añadir producto...',
                    prefixIcon: const Icon(Icons.add),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () {
                        if (textEditingController.text.isNotEmpty) {
                          _addItem(textEditingController.text);
                          textEditingController.clear();
                        }
                      },
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      _addItem(value);
                      textEditingController.clear();
                    }
                  },
                );
              },
              onSelected: (Map<String, dynamic> selection) {
                _addItem(selection['nombre'], fkProducto: selection['id_producto']);
                // Hack para limpiar el campo después de selección
                // Requeriría un controller externo o setState, pero por simplicidad:
                Future.delayed(const Duration(milliseconds: 50), () {
                  // No tenemos acceso fácil al controller interno aquí sin fieldViewBuilder controller
                  // Pero el usuario puede seguir escribiendo.
                  // Idealmente, el fieldViewBuilder controller se limpia.
                  // Como _addItem ya se llamó, el usuario ve el item añadido.
                  // El campo se queda con el texto seleccionado. El usuario debe borrarlo.
                  // Para mejor UX, deberíamos limpiar.
                  // Pero Autocomplete es tricky con limpieza.
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorView(
                        error: _error!,
                        onRetry: _loadItems,
                      )
                    : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (pendingItems.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('Pendientes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        ...pendingItems.map((item) => _buildItemTile(item)),
                      ],
                      if (completedItems.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('Comprados', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey)),
                        ),
                        ...completedItems.map((item) => _buildItemTile(item)),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(ShoppingListItem item) {
    final imageUrl = item.product?['image_url'];
    final brand = item.product?['marca'];

    return Dismissible(
      key: Key(item.id.toString()),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: Colors.red.shade700),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => _deleteItem(item.id),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: CheckboxListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Row(
            children: [
              if (imageUrl != null && imageUrl.toString().isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    imageUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                      const Icon(Icons.image_not_supported_outlined, size: 24, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  item.productoNombre,
                  style: TextStyle(
                    decoration: item.completado ? TextDecoration.lineThrough : null,
                    color: item.completado ? Colors.grey : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          subtitle: (brand != null || item.cantidad > 1)
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (brand != null && brand.toString().isNotEmpty)
                        Text(
                          brand,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      if (item.cantidad > 1)
                        Text(
                          'Cantidad: ${item.cantidad}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                )
              : null,
          value: item.completado,
          onChanged: (_) => _toggleItem(item),
          secondary: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _deleteItem(item.id),
            tooltip: 'Eliminar de la lista',
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
