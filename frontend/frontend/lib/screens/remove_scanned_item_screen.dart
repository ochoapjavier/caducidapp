// frontend/lib/screens/remove_scanned_item_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';

class RemoveScannedItemScreen extends StatefulWidget {
  final String barcode;

  const RemoveScannedItemScreen({super.key, required this.barcode});

  @override
  State<RemoveScannedItemScreen> createState() =>
      _RemoveScannedItemScreenState();
}

class _RemoveScannedItemScreenState extends State<RemoveScannedItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();

  late Future<List<dynamic>> _foundItemsFuture;
  List<dynamic> _foundItems = [];

  dynamic _selectedStockItem;
  var _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Buscamos en el inventario todos los items que coincidan con el EAN escaneado.
    _foundItemsFuture = fetchStockItems(searchTerm: widget.barcode);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _onStockItemChanged(dynamic item) {
    setState(() {
      _selectedStockItem = item;
      if (item != null) {
        // Por defecto, sugerimos eliminar 1 unidad.
        _quantityController.text = '1';
      } else {
        _quantityController.clear();
      }
    });
  }

  void _incrementQuantity() {
    if (_selectedStockItem == null) return;
    final currentQuantity = int.tryParse(_quantityController.text) ?? 0;
    final maxQuantity = _selectedStockItem!['cantidad_actual'] as int;
    if (currentQuantity < maxQuantity) {
      _quantityController.text = (currentQuantity + 1).toString();
      setState(() {}); // Para actualizar el estado de los botones
    }
  }

  void _decrementQuantity() {
    final currentQuantity = int.tryParse(_quantityController.text) ?? 0;
    if (currentQuantity > 1) {
      _quantityController.text = (currentQuantity - 1).toString();
      setState(() {}); // Para actualizar el estado de los botones
    }
  }

  void _submitRemoval() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      await removeStockItems(
        stockId: _selectedStockItem['id_stock'],
        cantidad: int.parse(_quantityController.text),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Stock actualizado con éxito.'),
              backgroundColor: Colors.green),
        );
        // Cierra esta pantalla y vuelve a la vista de "Eliminar"
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salida por Escáner'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _foundItemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No se encontró ningún producto con este código de barras en tu inventario.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          _foundItems = snapshot.data!;
          // Si solo hay un resultado, lo pre-seleccionamos.
          if (_foundItems.length == 1 && _selectedStockItem == null) {
            // Usamos addPostFrameCallback para evitar llamar a setState durante el build.
            // Esto programa la llamada a _onStockItemChanged para DESPUÉS de que el frame se haya construido.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Verificamos que el widget siga montado por seguridad.
              if (mounted) _onStockItemChanged(_foundItems.first);
            });
          }

          final productName = _foundItems.first['producto_maestro']['nombre'];
          final brand = _foundItems.first['producto_maestro']['marca'];

          final bool isItemSelected = _selectedStockItem != null;
          final int currentQuantity = int.tryParse(_quantityController.text) ?? 0;
          final int maxQuantity = isItemSelected ? _selectedStockItem!['cantidad_actual'] : 0;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Información del producto
                  ListTile(
                    leading: const Icon(Icons.label_important_outline, size: 32),
                    title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text(brand ?? 'Marca no disponible'),
                  ),
                  const Divider(height: 32),

                  // 1. Dropdown para elegir la ubicación/item específico
                  DropdownButtonFormField<dynamic>(
                    value: _selectedStockItem,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Selecciona la ubicación del producto',
                      border: OutlineInputBorder(),
                    ),
                    items: _foundItems.map((item) {
                      final locationName = item['ubicacion']['nombre'];
                      final quantity = item['cantidad_actual'];
                      return DropdownMenuItem(
                        value: item,
                        child: Text('$locationName (Disponibles: $quantity)'),
                      );
                    }).toList(),
                    onChanged: _onStockItemChanged,
                    validator: (value) => value == null ? 'Debes seleccionar una ubicación.' : null,
                  ),
                  const SizedBox(height: 16),

                  // 2. Campo de Cantidad (reutilizado de la salida manual)
                  TextFormField(
                    controller: _quantityController,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Cantidad a Eliminar',
                      border: const OutlineInputBorder(),
                      enabled: isItemSelected,
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: isItemSelected && currentQuantity > 1 ? _decrementQuantity : null,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: isItemSelected && currentQuantity < maxQuantity ? _incrementQuantity : null,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Introduce una cantidad.';
                      final quantity = int.tryParse(value);
                      if (quantity == null || quantity <= 0) return 'La cantidad debe ser positiva.';
                      if (isItemSelected && quantity > maxQuantity) {
                        return 'No puedes eliminar más de lo disponible ($maxQuantity).';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // 3. Botón de Eliminar
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton.icon(
                      onPressed: isItemSelected ? _submitRemoval : null,
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: const Text('Eliminar del Inventario'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}