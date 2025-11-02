// frontend/lib/widgets/inventory_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/widgets/remove_item_view.dart'; // Importamos la nueva vista

class InventoryView extends StatefulWidget {
  const InventoryView({super.key});

  @override
  State<InventoryView> createState() => InventoryViewState(); // Clave pública
}

class InventoryViewState extends State<InventoryView> {
  late Future<List<dynamic>> _stockItemsFuture;
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _stockItemsFuture = fetchStockItems();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      refreshInventory();
    });
  }

  // Hacemos el método público para poder llamarlo desde el widget padre
  void refreshInventory() {
    setState(() {
      _stockItemsFuture = fetchStockItems(searchTerm: _searchController.text);
    });
  }

  void _consumeItem(int stockId) async {
    try {
      await consumeStockItem(stockId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto consumido.'), backgroundColor: Colors.green),
      );
      refreshInventory(); // Recargamos la lista para ver el cambio
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( // Envolvemos en un Scaffold para poder usar el FAB
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Buscar por nombre o EAN',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _stockItemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay productos en tu inventario.'));
                }

                // --- INICIO DE LA LÓGICA DE AGRUPACIÓN ---
                final Map<String, List<dynamic>> groupedItems = {};
                for (var item in snapshot.data!) {
                  final locationName = item['ubicacion']['nombre'] as String;
                  if (!groupedItems.containsKey(locationName)) {
                    groupedItems[locationName] = [];
                  }
                  groupedItems[locationName]!.add(item);
                }
                final locationKeys = groupedItems.keys.toList()..sort(); // Ordenamos las ubicaciones alfabéticamente
                // --- FIN DE LA LÓGICA DE AGRUPACIÓN ---

                return RefreshIndicator(
                  onRefresh: () async {
                    refreshInventory();
                  },
                  child: ListView.builder(
                    itemCount: locationKeys.length, // Ahora iteramos sobre las ubicaciones
                    itemBuilder: (context, index) {
                      final locationName = locationKeys[index];
                      final itemsInLocation = groupedItems[locationName]!;

                      // Usamos ExpansionTile para cada ubicación
                      return ExpansionTile(
                        key: PageStorageKey(locationName), // Ayuda a mantener el estado (abierto/cerrado)
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(
                          locationName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Text('${itemsInLocation.length} producto(s)'),
                        initiallyExpanded: true,
                        children: itemsInLocation.map((item) {
                          // Este es el ListTile para cada producto, similar al que ya tenías
                          final productName = item['producto_maestro']['nombre'];
                          final brand = item['producto_maestro']['marca'];
                          final quantity = item['cantidad_actual'];
                          final expiryDate = DateTime.parse(item['fecha_caducidad']);
                          final stockId = item['id_stock'];

                          return ListTile(
                            contentPadding: const EdgeInsets.only(left: 32, right: 16),
                            title: Text(brand != null ? '$productName - $brand' : productName),
                            subtitle: Text('Caduca: ${expiryDate.day}/${expiryDate.month}/${expiryDate.year}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$quantity', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () => _consumeItem(stockId),
                                  tooltip: 'Consumir 1 unidad',
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
