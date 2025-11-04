// frontend/lib/widgets/inventory_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/scanner_screen.dart';

var _isLoading = false; // Para mostrar un spinner durante las llamadas a la API

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
  final Map<int, bool> _processingByItem = {}; // id_stock -> processing

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
  Future<void> refreshInventory() async {
    setState(() {
      _stockItemsFuture = fetchStockItems(searchTerm: _eanSearchController.text.isNotEmpty ? _eanSearchController.text : _nameSearchController.text);
    });
    try {
      await _stockItemsFuture;
    } catch (_) {
      // el FutureBuilder mostrará el error; aquí sólo evitamos que el await lance hacia arriba
    }
  }
  
  void _consumeItem(int stockId) async {
    setState(() => _processingByItem[stockId] = true);
    try {
      await consumeStockItem(stockId);
      await refreshInventory();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto consumido.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      setState(() => _processingByItem.remove(stockId));
    }
  }
  
  /// Muestra un diálogo para confirmar y especificar la cantidad a eliminar.
  void _showRemoveQuantityDialog(int stockId, int currentQuantity, String productName) {
    final quantityController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();
    bool isProcessing = false; // Estado local para el diálogo

    showDialog(
      context: context,
      builder: (ctx) {
        // Usamos StatefulBuilder para que el contenido del diálogo pueda tener su propio estado.
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final int currentVal = int.tryParse(quantityController.text) ?? 0;

            return AlertDialog(
              title: Text('Eliminar "$productName"'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Disponibles: $currentQuantity. ¿Cuántas unidades quieres eliminar?'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'Cantidad',
                        border: const OutlineInputBorder(),
                        prefixIcon: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: isProcessing
                              ? null
                              : currentVal > 1
                                  ? () => setStateDialog(() => quantityController.text = (currentVal - 1).toString())
                                  : null,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: isProcessing
                              ? null
                              : currentVal < currentQuantity
                                  ? () => setStateDialog(() => quantityController.text = (currentVal + 1).toString())
                                  : null,
                        ),
                      ),
                      onChanged: (value) => setStateDialog(() {}), // Para actualizar el estado de los botones
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Introduce un nº.';
                        final n = int.tryParse(value);
                        if (n == null) return 'Nº inválido.';
                        if (n <= 0) return 'Debe ser > 0.';
                        if (n > currentQuantity) return 'No hay tantas.';
                        return null;
                      },
                    ),
                    if (isProcessing) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Eliminando...'),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          if (formKey.currentState?.validate() ?? false) {
                            final quantityToRemove = int.parse(quantityController.text);

                            // Mostrar indicador de proceso en el diálogo
                            setStateDialog(() => isProcessing = true);

                            try {
                              // Llamada al API para eliminar
                              final result = await removeStockItems(stockId: stockId, cantidad: quantityToRemove);

                              // Refrescar inventario y esperar a que termine
                              await refreshInventory();

                              // Cerrar diálogo y mostrar confirmación
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result is Map ? (result['message'] ?? 'Stock actualizado.') : (result?.toString() ?? 'Stock actualizado.')),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              // En caso de error, permitir reintento y notificar
                              setStateDialog(() => isProcessing = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  child: const Text('Eliminar'),
                ),
              ],
            );
          },
        );
      },
    );
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
                    await refreshInventory();
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
                          
                          // --- INICIO: LÓGICA PARA EL INDICADOR VISUAL DE CADUCIDAD ---
                          final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
                          Color expiryColor;
                          if (daysUntilExpiry <= 3) {
                            expiryColor = Colors.red;
                          } else if (daysUntilExpiry <= 7) {
                            expiryColor = Colors.orange;
                          } else {
                            expiryColor = Colors.transparent; // Sin borde si no está próximo a caducar
                          }
                          // --- FIN: LÓGICA PARA EL INDICADOR VISUAL DE CADUCIDAD ---
                          
                          return ListTile(
                            contentPadding: const EdgeInsets.only(left: 32, right: 16),
                            // --- INICIO: WIDGET DE IMAGEN CON BORDE DE CADUCIDAD ---
                            leading: Container(
                              padding: const EdgeInsets.all(2.0), // Espacio entre el borde y la imagen
                              decoration: BoxDecoration(
                                color: expiryColor, // El color que calculamos antes
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 26, // Un poco más pequeño para que el borde se vea
                                backgroundColor: Colors.grey[200],
                                // Si hay URL, intentamos cargar la imagen de red.
                                child: imageUrl != null
                                  ? ClipOval(
                                      child: Image.network(
                                        imageUrl, // Argumento posicional
                                        fit: BoxFit.cover, // Argumento con nombre, necesita coma
                                        width: 52,         // Argumento con nombre, necesita coma
                                        height: 52,        // Argumento con nombre, necesita coma
                                        loadingBuilder: (context, child, progress) => progress == null ? child : const CircularProgressIndicator(strokeWidth: 2),
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.grey),
                                      ),
                                    )
                                  : const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 28),
                              ),
                            ),
                            // --- FIN: WIDGET DE IMAGEN CON BORDE DE CADUCIDAD ---
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
                                  // --- CAMBIO: En lugar de consumir 1, abrimos el diálogo ---
                                  onPressed: () => _showRemoveQuantityDialog(
                                    stockId,
                                    quantity,
                                    productName,
                                  ),
                                  tooltip: 'Eliminar unidades',
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
