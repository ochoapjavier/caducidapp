// frontend/lib/screens/remove_manual_item_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/models/ubicacion.dart';
import 'package:frontend/services/api_service.dart';
import 'package:intl/intl.dart'; // <-- IMPORTACIÓN AÑADIDA

class RemoveManualItemScreen extends StatefulWidget {
  const RemoveManualItemScreen({super.key});

  @override
  State<RemoveManualItemScreen> createState() => _RemoveManualItemScreenState();
}

class _RemoveManualItemScreenState extends State<RemoveManualItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();

  // Estado de la pantalla
  var _isLoading = false;
  late Future<void> _initialLoadFuture; // Un único Future para controlar la carga inicial
  List<dynamic> _fullStock = []; // Lista completa del inventario

  // Valores seleccionados
  Ubicacion? _selectedUbicacion;
  dynamic? _selectedStockItem; // Item de stock seleccionado
  List<dynamic> _itemsInLocation = []; // Items filtrados por ubicación

  // Lista de ubicaciones cargadas
  List<Ubicacion> _ubicaciones = [];

  @override
  void initState() {
    super.initState();
    // Lanzamos ambas cargas y esperamos a que terminen
    _initialLoadFuture = _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // Esperamos a que ambas llamadas a la API terminen en paralelo
      final results = await Future.wait([
        fetchUbicaciones(),
        fetchStockItems(),
      ]);
      _ubicaciones = results[0] as List<Ubicacion>;
      _fullStock = results[1] as List<dynamic>;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos iniciales: ${e.toString()}')),
        );
      }
      // Relanzamos el error para que el FutureBuilder lo capture
      rethrow;
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _onUbicacionChanged(Ubicacion? ubicacion) {
    setState(() {
      _selectedUbicacion = ubicacion;
      _selectedStockItem = null; // Reseteamos el producto seleccionado
      _quantityController.clear();
      if (ubicacion != null) {
        // Filtramos el inventario para obtener solo los productos de la ubicación seleccionada
        _itemsInLocation = _fullStock
            .where((item) => item['ubicacion']['id_ubicacion'] == ubicacion.id) // Ahora esto funcionará
            .toList();
      } else {
        _itemsInLocation = [];
      }
    });
  }

  void _onStockItemChanged(dynamic item) {
    setState(() {
      _selectedStockItem = item;
      // Sugerimos la cantidad máxima disponible
      if (item != null) {
        _quantityController.text = item['cantidad_actual'].toString();
      } else {
        _quantityController.clear();
      }
    });
  }

  void _showConfirmationDialog() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final productName = _selectedStockItem['producto_maestro']['nombre'];
    final quantityToRemove = int.parse(_quantityController.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Salida'),
        content: Text('¿Seguro que quieres eliminar $quantityToRemove unidad(es) de "$productName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Cierra el diálogo
              _submitRemoval(); // Procede con la eliminación
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _submitRemoval() async {
    setState(() => _isLoading = true);

    try {
      await removeStockItems(
        stockId: _selectedStockItem['id_stock'],
        cantidad: int.parse(_quantityController.text),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock actualizado con éxito.'), backgroundColor: Colors.green),
        );
        // Volvemos a la pantalla de inventario y le decimos que refresque (devolviendo true)
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
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
        title: const Text('Salida Manual de Stock'),
      ),
      body: FutureBuilder(
        future: _initialLoadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar: ${snapshot.error}'));
          }

          // Una vez cargado, mostramos el formulario
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // 1. Dropdown de Ubicaciones
                  DropdownButtonFormField<Ubicacion>(
                    value: _selectedUbicacion,
                    decoration: const InputDecoration(labelText: 'Selecciona una Ubicación', border: OutlineInputBorder()),
                    items: _ubicaciones.map((ubicacion) {
                      return DropdownMenuItem(value: ubicacion, child: Text(ubicacion.nombre));
                    }).toList(),
                    onChanged: _onUbicacionChanged,
                    validator: (value) => value == null ? 'Selecciona una ubicación.' : null,
                  ),
                  const SizedBox(height: 16),

                  // 2. Dropdown de Productos (dependiente de la ubicación)
                  DropdownButtonFormField<dynamic>(
                    value: _selectedStockItem,
                    decoration: InputDecoration(
                      labelText: 'Selecciona un Producto',
                      border: const OutlineInputBorder(),
                      enabled: _selectedUbicacion != null, // Se activa solo si hay ubicación
                    ),
                    items: _itemsInLocation.map((item) {
                      final productName = item['producto_maestro']['nombre'];
                      final expiryDate = DateTime.parse(item['fecha_caducidad']);
                      final formattedDate = DateFormat('dd/MM/yy').format(expiryDate);
                      final quantity = item['cantidad_actual'];
                      return DropdownMenuItem(
                        value: item,
                        child: Text('$productName (Cad: $formattedDate, Disp: $quantity)', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: _onStockItemChanged,
                    validator: (value) => value == null ? 'Selecciona un producto.' : null,
                    isExpanded: true,
                  ),
                  const SizedBox(height: 16),

                  // 3. Campo de Cantidad
                  TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'Cantidad a Eliminar',
                      border: const OutlineInputBorder(),
                      enabled: _selectedStockItem != null,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Introduce una cantidad.';
                      }
                      final quantity = int.tryParse(value);
                      if (quantity == null || quantity <= 0) {
                        return 'La cantidad debe ser un número positivo.';
                      }
                      if (_selectedStockItem != null && quantity > _selectedStockItem['cantidad_actual']) {
                        return 'No puedes eliminar más de lo disponible (${_selectedStockItem['cantidad_actual']}).';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // 4. Botón de Eliminar
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton.icon(
                      onPressed: _selectedStockItem != null ? _showConfirmationDialog : null,
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