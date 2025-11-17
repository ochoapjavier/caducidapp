// frontend/lib/widgets/inventory_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/scanner_screen.dart';

// Eliminado _isLoading (no se usaba)

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
  // _isSearchPanelVisible eliminado (no se utilizaba)
  // _processingByItem eliminado (no se usa tras simplificar acciones)

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
  
  // Método _consumeItem eliminado (no usado tras rediseño)
  
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
                              await removeStockItems(stockId: stockId, cantidad: quantityToRemove);

                              // Refrescar inventario y esperar a que termine
                              await refreshInventory();

                              // Cerrar diálogo y mostrar confirmación
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Stock actualizado.'),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white, // Forzar contraste legible
                  ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Quitamos el Scaffold interno para integrarlo mejor en la pantalla contenedora.
    return Column(
      children: [
        // Panel de filtros desplegable
        ExpansionTile(
          title: Text(
            'Filtros',
            style: textTheme.titleMedium,
          ),
          leading: Icon(Icons.filter_list, color: colorScheme.primary),
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
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nombre',
                      prefixIcon: Icon(Icons.text_fields),
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
                      prefixIcon: const Icon(Icons.qr_code_2_outlined),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    itemCount: locationKeys.length, // Ahora iteramos sobre las ubicaciones
                    itemBuilder: (context, index) {
                      final locationName = locationKeys[index];
                      final itemsInLocation = groupedItems[locationName]!;

                      // Usamos ExpansionTile para cada ubicación envuelto en una Card
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Card(
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              key: PageStorageKey(locationName), // Ayuda a mantener el estado (abierto/cerrado)
                              leading: Icon(
                                Icons.location_on_outlined,
                                color: colorScheme.primary,
                              ),
                              title: Text(
                                locationName,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${itemsInLocation.length} producto(s)',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.65),
                                ),
                              ),
                              initiallyExpanded: true,
                              childrenPadding: const EdgeInsets.only(bottom: 8),
                              children: itemsInLocation.asMap().entries.map((entry) {
                                final i = entry.key;
                                final item = entry.value;
                                final productName = item['producto_maestro']['nombre'];
                                final brand = item['producto_maestro']['marca'];
                                final quantity = item['cantidad_actual'];
                                final imageUrl = item['producto_maestro']['image_url'];
                                final expiryDate = DateTime.parse(item['fecha_caducidad']);
                                final stockId = item['id_stock'];
                                final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
                                Color expiryColor;
                                if (daysUntilExpiry <= 3) {
                                  expiryColor = Colors.red;
                                } else if (daysUntilExpiry <= 7) {
                                  expiryColor = Colors.orange;
                                } else {
                                  expiryColor = Colors.transparent;
                                }
                                return Container(
                                  margin: EdgeInsets.only(
                                    left: 12,
                                    right: 12,
                                    top: i == 0 ? 4 : 2,
                                    bottom: i == itemsInLocation.length - 1 ? 8 : 2,
                                  ),
                                  decoration: BoxDecoration(
                                    // Fondo ligeramente tintado para contrastar con el blanco del Card padre.
                                    // Si el producto no está próximo a caducar, usamos un tono neutro suave.
                                    // Si hay franja de caducidad mantenemos fondo limpio para que la franja destaque.
                                    color: expiryColor == Colors.transparent
                                        ? colorScheme.surfaceVariant.withAlpha((255 * 0.65).round())
                                        : colorScheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: colorScheme.outline.withAlpha((255 * 0.35).round()),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha((255 * 0.07).round()),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                          if (expiryColor != Colors.transparent)
                                            Positioned(
                                              left: 0,
                                              top: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: 6,
                                                decoration: BoxDecoration(
                                                  color: expiryColor,
                                                  borderRadius: const BorderRadius.only(
                                                    topLeft: Radius.circular(16),
                                                    bottomLeft: Radius.circular(16),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          Padding(
                                            padding: EdgeInsets.fromLTRB(expiryColor != Colors.transparent ? 14 : 16, 14, 16, 14),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                CircleAvatar(
                                                  radius: 24,
                                                  backgroundColor: Colors.grey[200],
                                                  child: imageUrl != null
                                                      ? ClipOval(
                                                          child: Image.network(
                                                            imageUrl,
                                                            fit: BoxFit.cover,
                                                            width: 48,
                                                            height: 48,
                                                            loadingBuilder: (context, child, progress) => progress == null
                                                                ? child
                                                                : const SizedBox(
                                                                    width: 24,
                                                                    height: 24,
                                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                                  ),
                                                            errorBuilder: (context, error, stackTrace) => const Icon(
                                                              Icons.image_not_supported,
                                                              color: Colors.grey,
                                                            ),
                                                          ),
                                                        )
                                                      : const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 24),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        productName,
                                                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      if (brand != null && brand.isNotEmpty)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 2.0),
                                                          child: Text(
                                                            brand,
                                                            style: textTheme.bodySmall?.copyWith(
                                                              color: colorScheme.onSurface.withAlpha((255 * 0.65).round()),
                                                            ),
                                                          ),
                                                        ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Caduca: ${expiryDate.day}/${expiryDate.month}/${expiryDate.year}',
                                                        style: textTheme.bodySmall,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      'x$quantity',
                                                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    ElevatedButton.icon(
                                                      onPressed: () => _showRemoveQuantityDialog(stockId, quantity, productName),
                                                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                                                      label: const Text('Usar'),
                                                      style: ElevatedButton.styleFrom(
                                                        elevation: 0,
                                                        backgroundColor: colorScheme.primaryContainer,
                                                        foregroundColor: colorScheme.onPrimaryContainer,
                                                        minimumSize: const Size(0, 34),
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                }).toList(),
                              ),
                            ),
                          ), // Card
                        ); // return Padding
                      }, // itemBuilder
                    ), // ListView.builder
                  ); // end RefreshIndicator return
              },
            ), // FutureBuilder
          ), // Expanded
        ],
      ); // Column
  }
}
