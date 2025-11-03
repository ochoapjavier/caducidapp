// frontend/lib/widgets/inventory_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/scanner_screen.dart';
import 'package:frontend/widgets/remove_item_view.dart'; // Importamos la nueva vista

class InventoryView extends StatefulWidget {
  const InventoryView({super.key});

  @override
  State<InventoryView> createState() => InventoryViewState(); // Clave pública
}

class InventoryViewState extends State<InventoryView> {
  late Future<List<dynamic>> _stockItemsFuture;
  final _nameSearchController = TextEditingController();
  final _eanSearchController = TextEditingController();
  Timer? _nameDebounce;
  bool _isSearchPanelVisible = false; // Nuevo estado para controlar la visibilidad

  @override
  void initState() {
    super.initState();
    _stockItemsFuture = fetchStockItems();
    _nameSearchController.addListener(_onNameSearchChanged);
    _eanSearchController.addListener(_onEanSearchChanged);
  }

  @override
  void dispose() {
    _nameSearchController.removeListener(_onNameSearchChanged);
    _eanSearchController.removeListener(_onEanSearchChanged);
    _nameSearchController.dispose();
    _eanSearchController.dispose();
    _nameDebounce?.cancel();
    super.dispose();
  }

  void _onNameSearchChanged() {
    if (_nameDebounce?.isActive ?? false) _nameDebounce!.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 500), () {
      // Si el campo de EAN está activo, no buscamos por nombre para evitar conflictos.
      if (_eanSearchController.text.isEmpty) {
        refreshInventory();
      }
    });
  }

  void _onEanSearchChanged() {
    // La búsqueda por EAN es más rápida y no necesita debounce.
    // Si el campo EAN se vacía, la búsqueda por nombre tomará el control.
    refreshInventory();
  }

  void _scanBarcode() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (ctx) => const ScannerScreen()),
    );
    if (barcode != null && barcode.isNotEmpty) {
      _eanSearchController.text = barcode;
      refreshInventory();
    }
  }

  // Hacemos el método público para poder llamarlo desde el widget padre
  void refreshInventory() {
    setState(() {
      _stockItemsFuture = fetchStockItems(searchTerm: _eanSearchController.text.isNotEmpty ? _eanSearchController.text : _nameSearchController.text);
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
    // Ya no necesitamos un Scaffold aquí si el widget padre lo proporciona.
    // Si este widget se usa en un contexto sin Scaffold, habría que mantenerlo.
    // Por ahora, lo quitamos para integrarlo mejor en la TabBarView.
    return Scaffold(
      body: Column(
        children: [
          // Panel de filtros desplegable
          ExpansionTile(
            title: const Text('Filtros'),
            leading: const Icon(Icons.filter_list),
            initiallyExpanded: false, // Empieza contraído
            onExpansionChanged: (isExpanded) {
              // Si se contrae y hay texto en los buscadores, los limpiamos y refrescamos la lista.
              if (!isExpanded && (_nameSearchController.text.isNotEmpty || _eanSearchController.text.isNotEmpty)) {
                _nameSearchController.clear();
                _eanSearchController.clear();
                refreshInventory();
              }
            },
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    // Buscador por Nombre
                    TextField(
                      controller: _nameSearchController,
                      decoration: InputDecoration(
                        labelText: 'Buscar por Nombre',
                        prefixIcon: const Icon(Icons.text_fields),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (value) {
                        if (_eanSearchController.text.isNotEmpty) _eanSearchController.clear();
                      },
                    ),
                    const SizedBox(height: 12),
                    // Buscador por EAN
                    TextField(
                      controller: _eanSearchController,
                      decoration: InputDecoration(
                        labelText: 'Buscar por EAN',
                        prefixIcon: const Icon(Icons.barcode_reader),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: _scanBarcode,
                          tooltip: 'Escanear código',
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        if (_nameSearchController.text.isNotEmpty) _nameSearchController.clear();
                      },
                    ),
                  ],
                ),
              )
            ],
          ),
          // Lista de inventario
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
                          final imageUrl = item['producto_maestro']['image_url']; // <-- OBTENEMOS LA URL
                          final expiryDate = DateTime.parse(item['fecha_caducidad']);
                          final stockId = item['id_stock'];

                          return ListTile(
                            contentPadding: const EdgeInsets.only(left: 32, right: 16),
                            // --- INICIO: WIDGET DE IMAGEN ---
                            // Aumentamos el radio del CircleAvatar para una imagen más grande y visible.
                            leading: CircleAvatar(
                              radius: 28, // <-- TAMAÑO AUMENTADO
                              backgroundColor: Colors.grey[200],
                              // Si hay URL, intentamos cargar la imagen de red.
                              // Si no, mostramos un icono por defecto.
                              child: imageUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      width: 56, // <-- TAMAÑO AUMENTADO (2 * radio)
                                      height: 56, // <-- TAMAÑO AUMENTADO (2 * radio)
                                      // Widget que se muestra mientras carga la imagen
                                      loadingBuilder: (context, child, progress) => progress == null ? child : const CircularProgressIndicator(strokeWidth: 2),
                                      // Widget que se muestra si hay un error al cargar
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.grey),
                                    ),
                                  )
                                : const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 28),
                            ),
                            // --- FIN: WIDGET DE IMAGEN ---
                            // --- INICIO: TÍTULO MEJORADO (UX/UI) ---
                            // Usamos una Columna para separar el nombre y la marca,
                            // dando más jerarquía visual al nombre del producto.
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (brand != null && brand.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      brand,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ),
                              ],
                            ),
                            // --- FIN: TÍTULO MEJORADO (UX/UI) ---
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
