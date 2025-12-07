// frontend/lib/widgets/inventory_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/scanner_screen.dart';
import 'package:frontend/utils/expiry_utils.dart'; // Utilidades centralizadas para lógica de caducidad
import 'package:frontend/widgets/quantity_selection_dialog.dart';
import 'package:frontend/services/shopping_service.dart';
import 'package:frontend/services/hogar_service.dart';

// Eliminado _isLoading (no se usaba)

class InventoryView extends StatefulWidget {
  final VoidCallback? onAddItem;
  final VoidCallback? onRemoveItem;

  const InventoryView({
    super.key, 
    this.onAddItem, 
    this.onRemoveItem
  });

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
  /// Método público para poder ser invocado desde otras vistas (ej: Alertas)
  void showRemoveQuantityDialog(int stockId, int currentQuantity, String productName, int? productId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => QuantitySelectionDialog(
        title: 'Eliminar "$productName"',
        subtitle: 'Disponibles: $currentQuantity',
        maxQuantity: currentQuantity,
        onConfirm: (quantity, addToShoppingList) async {
          try {
            // 1. Eliminar del stock
            await removeStockItems(stockId: stockId, cantidad: quantity);

            // 2. Añadir a lista de compra si se solicitó
            if (addToShoppingList) {
              try {
                final hogarId = await HogarService().getHogarActivo();
                if (hogarId != null) {
                  await ShoppingService().addItem(hogarId, productName, fkProducto: productId);
                }
              } catch (e) {
                debugPrint('Error adding to shopping list: $e');
              }
            }

            // 3. Refrescar inventario
            await refreshInventory();

            // 4. Notificar
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(addToShoppingList 
                    ? 'Eliminado y añadido a la lista.' 
                    : 'Producto eliminado.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  // ============================================================================
  // DIÁLOGOS PARA ACCIONES DE ESTADO DE PRODUCTO
  // ============================================================================

  /// Diálogo para abrir un producto cerrado
  Future<void> _showOpenProductDialog(dynamic item) async {
    final stockId = item['id_stock'];
    final productName = item['producto_maestro']['nombre'];
    final currentQuantity = item['cantidad_actual'];
    final int? defaultDiasConsumo = item['producto_maestro']['dias_consumo_abierto'];
    
    int quantity = 1;
    // Si hay un valor por defecto, lo usamos y desactivamos "mantener fecha" por defecto.
    // Si no, usamos 4 días y mantenemos la fecha original por defecto.
    int diasVidaUtil = defaultDiasConsumo ?? 4;
    bool mantenerFechaCaducidad = defaultDiasConsumo == null;
    
    int? selectedLocationId;
    
    final colorScheme = Theme.of(context).colorScheme;
    
    // Obtener ubicaciones para el dropdown
    final locations = await fetchUbicaciones();
    
    if (!mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Abrir "$productName"'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Disponible: $currentQuantity unidades',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                // Spinner para cantidad
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cantidad a abrir',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: quantity > 1
                          ? () => setStateDialog(() => quantity--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: colorScheme.primary,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$quantity',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: quantity < currentQuantity
                          ? () => setStateDialog(() => quantity++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      color: colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Nueva ubicación (opcional)',
                    helperText: 'Ej: mover de despensa a nevera',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedLocationId,
                  items: locations.map((loc) => DropdownMenuItem<int>(
                    value: loc.id,
                    child: Text(loc.nombre),
                  )).toList(),
                  onChanged: (value) => setStateDialog(() => selectedLocationId = value),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mantener fecha de caducidad original'),
                  subtitle: Text(
                    mantenerFechaCaducidad
                      ? 'La fecha no cambiará al abrir'
                      : 'Se recalculará según días de vida útil',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: mantenerFechaCaducidad,
                  onChanged: (value) => setStateDialog(() => mantenerFechaCaducidad = value),
                ),
                // Campo de días solo si NO mantiene fecha
                if (!mantenerFechaCaducidad) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Días de vida útil',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        onPressed: diasVidaUtil > 1
                            ? () => setStateDialog(() => diasVidaUtil--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: colorScheme.primary,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$diasVidaUtil',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: diasVidaUtil < 30
                            ? () => setStateDialog(() => diasVidaUtil++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                  Text(
                    'Nueva fecha: ${DateTime.now().add(Duration(days: diasVidaUtil)).day}/${DateTime.now().add(Duration(days: diasVidaUtil)).month}/${DateTime.now().add(Duration(days: diasVidaUtil)).year}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: colorScheme.secondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          defaultDiasConsumo != null && defaultDiasConsumo == diasVidaUtil
                              ? 'Usando tu preferencia guardada para este producto.'
                              : 'Este valor se guardará como preferencia para la próxima vez.',
                          style: TextStyle(fontSize: 11, color: colorScheme.secondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Abrir'),
            ),
          ],
        ),
      ),
    );
    
    if (confirmed == true) {
      try {
        if (quantity <= 0 || quantity > currentQuantity) {
          throw Exception('Cantidad inválida');
        }
        
        await openProduct(
          stockId: stockId,
          cantidad: quantity,
          nuevaUbicacionId: selectedLocationId,
          mantenerFechaCaducidad: mantenerFechaCaducidad,
          diasVidaUtil: diasVidaUtil,
        );
        
        await refreshInventory();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Producto abierto correctamente'),
              backgroundColor: colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      }
    }
  }

  /// Diálogo para congelar un producto
  Future<void> _showFreezeProductDialog(dynamic item) async {
    final stockId = item['id_stock'];
    final productName = item['producto_maestro']['nombre'];
    final currentQuantity = item['cantidad_actual'];
    final estadoProducto = item['estado_producto'] ?? 'cerrado';
    
    int quantity = currentQuantity;
    int? freezerLocationId;
    
    final colorScheme = Theme.of(context).colorScheme;
    
    // Obtener ubicaciones y filtrar solo las que son congeladores
    final allLocations = await fetchUbicaciones();
    final locations = allLocations.where((loc) => loc.esCongelador).toList();
    
    if (!mounted) return;
    
    // Validar que existen ubicaciones de tipo congelador
    if (locations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No tienes ubicaciones de tipo congelador. Crea una primero en la pantalla de Ubicaciones.'),
          backgroundColor: colorScheme.error,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Congelar "$productName"'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Disponible: $currentQuantity unidades',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                // Advertencia si es producto descongelado
                if (estadoProducto.toLowerCase() == 'descongelado') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade700, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '⚠️ No se recomienda re-congelar productos ya descongelados por seguridad alimentaria.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'Al congelar, el producto dejará de aparecer en las alertas de caducidad.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                // Spinner para cantidad
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cantidad a congelar',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: quantity > 1
                          ? () => setStateDialog(() => quantity--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: colorScheme.primary,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$quantity',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: quantity < currentQuantity
                          ? () => setStateDialog(() => quantity++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      color: colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Ubicación del congelador *',
                    border: OutlineInputBorder(),
                  ),
                  value: freezerLocationId,
                  items: locations.map((loc) => DropdownMenuItem<int>(
                    value: loc.id,
                    child: Text(loc.nombre),
                  )).toList(),
                  onChanged: (value) => setStateDialog(() => freezerLocationId = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: freezerLocationId == null ? null : () => Navigator.of(ctx).pop(true),
              child: const Text('Congelar'),
            ),
          ],
        ),
      ),
    );
    
    if (confirmed == true && freezerLocationId != null) {
      try {
        if (quantity <= 0 || quantity > currentQuantity) {
          throw Exception('Cantidad inválida');
        }
        
        await freezeProduct(
          stockId: stockId,
          cantidad: quantity,
          ubicacionCongeladorId: freezerLocationId!,
        );
        
        await refreshInventory();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Producto congelado correctamente'),
              backgroundColor: colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      }
    }
  }

  /// Diálogo para descongelar un producto
  Future<void> _showUnfreezeProductDialog(dynamic item) async {
    final stockId = item['id_stock'];
    final productName = item['producto_maestro']['nombre'];
    final currentQuantity = item['cantidad_actual'] as int;
    
    int? newLocationId;
    int diasVidaUtil = 2;
    int quantity = 1; // Cantidad a descongelar
    
    final colorScheme = Theme.of(context).colorScheme;
    
    // Obtener ubicaciones y filtrar solo las que NO son congeladores
    final allLocations = await fetchUbicaciones();
    final locations = allLocations.where((loc) => !loc.esCongelador).toList();
    
    // Validar que existen ubicaciones que no son congelador
    if (locations.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes ubicaciones normales (no congelador) para descongelar. Crea una primero en la pantalla de Ubicaciones.'),
        ),
      );
      return;
    }
    
    if (!mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Descongelar "$productName"'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Al descongelar, se recomienda consumir el producto en pocos días.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                // Selector de cantidad
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cantidad a descongelar',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: quantity > 1
                          ? () => setStateDialog(() => quantity--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: colorScheme.primary,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$quantity',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: quantity < currentQuantity
                          ? () => setStateDialog(() => quantity++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      color: colorScheme.primary,
                    ),
                  ],
                ),
                Text(
                  'Disponible: $currentQuantity unidades',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Nueva ubicación (no congelador) *',
                    helperText: 'Ej: Nevera, Despensa',
                    border: OutlineInputBorder(),
                  ),
                  value: newLocationId,
                  items: locations.map((loc) => DropdownMenuItem<int>(
                    value: loc.id,
                    child: Text(loc.nombre),
                  )).toList(),
                  onChanged: (value) => setStateDialog(() => newLocationId = value),
                ),
                const SizedBox(height: 16),
                // Spinner para días
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Días para consumir',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: diasVidaUtil > 1
                          ? () => setStateDialog(() => diasVidaUtil--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: colorScheme.primary,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$diasVidaUtil',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: diasVidaUtil < 7
                          ? () => setStateDialog(() => diasVidaUtil++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      color: colorScheme.primary,
                    ),
                  ],
                ),
                Text(
                  'Nueva fecha: ${DateTime.now().add(Duration(days: diasVidaUtil)).day}/${DateTime.now().add(Duration(days: diasVidaUtil)).month}/${DateTime.now().add(Duration(days: diasVidaUtil)).year}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: newLocationId == null ? null : () => Navigator.of(ctx).pop(true),
              child: const Text('Descongelar'),
            ),
          ],
        ),
      ),
    );
    
    if (confirmed == true && newLocationId != null) {
      try {
        if (diasVidaUtil <= 0 || diasVidaUtil > 7) {
          throw Exception('Días inválidos (1-7)');
        }
        
        if (quantity <= 0 || quantity > currentQuantity) {
          throw Exception('Cantidad inválida');
        }
        
        await unfreezeProduct(
          stockId: stockId,
          cantidad: quantity,
          nuevaUbicacionId: newLocationId!,
          diasVidaUtil: diasVidaUtil,
        );
        
        await refreshInventory();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Producto descongelado correctamente'),
              backgroundColor: colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      }
    }
  }

  /// Diálogo para reubicar un producto
  Future<void> _showRelocateProductDialog(dynamic item) async {
    final stockId = item['id_stock'];
    final productName = item['producto_maestro']['nombre'];
    final currentLocationName = item['ubicacion']['nombre'];
    final currentQuantity = item['cantidad_actual'];
    
    int? newLocationId;
    int quantity = 1;
    
    final colorScheme = Theme.of(context).colorScheme;
    
    // Obtener ubicaciones
    final locations = await fetchUbicaciones();
    
    if (!mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Reubicar "$productName"'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ubicación actual: $currentLocationName',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Unidades disponibles: $currentQuantity',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Spinner para cantidad a reubicar
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cantidad a reubicar',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: quantity > 1
                          ? () => setStateDialog(() => quantity--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: colorScheme.primary,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$quantity',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: quantity < currentQuantity
                          ? () => setStateDialog(() => quantity++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      color: colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Nueva ubicación *',
                    border: OutlineInputBorder(),
                  ),
                  value: newLocationId,
                  items: locations.map((loc) => DropdownMenuItem<int>(
                    value: loc.id,
                    child: Text(loc.nombre),
                  )).toList(),
                  onChanged: (value) => setStateDialog(() => newLocationId = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: newLocationId == null ? null : () => Navigator.of(ctx).pop(true),
              child: const Text('Reubicar'),
            ),
          ],
        ),
      ),
    );
    
    if (confirmed == true && newLocationId != null) {
      try {
        await relocateProduct(
          stockId: stockId,
          cantidad: quantity,
          nuevaUbicacionId: newLocationId!,
        );
        
        await refreshInventory();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Producto reubicado correctamente'),
              backgroundColor: colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Quitamos el Scaffold interno para integrarlo mejor en la pantalla contenedora.
    return SafeArea(
      child: Column(
      children: [
        // Encabezado: Filtros + Acciones Rápidas
        Material(
          color: Theme.of(context).cardColor,
          elevation: 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filtros expandibles
              Expanded(
                child: ExpansionTile(
                  title: Text(
                    'Filtros',
                    style: textTheme.titleMedium,
                  ),
                  leading: Icon(Icons.filter_list, color: colorScheme.primary),
                  initiallyExpanded: false, // Empieza contraído
                  shape: const Border(), // Quitar bordes por defecto
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
              ),
              // Botones de Acción (+ / -)
              if (widget.onRemoveItem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 4),
                  child: IconButton.filledTonal(
                    onPressed: widget.onRemoveItem,
                    icon: const Icon(Icons.remove),
                    tooltip: 'Registrar Salida',
                    // Eliminados colores explícitos para un look más integrado
                  ),
                ),
              if (widget.onAddItem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 12),
                  child: IconButton.filledTonal( // Cambiado a filledTonal para consistencia
                    onPressed: widget.onAddItem,
                    icon: const Icon(Icons.add),
                    tooltip: 'Añadir Producto',
                  ),
                ),
            ],
          ),
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
                                final estadoProducto = item['estado_producto'] ?? 'cerrado';
                                
                                // Usando utilidades centralizadas para mantener consistencia
                                final expiryColor = ExpiryUtils.getExpiryColor(expiryDate, colorScheme);
                                final statusLabel = ExpiryUtils.getStatusLabel(expiryDate);
                                final daysUntilExpiry = ExpiryUtils.daysUntilExpiry(expiryDate);
                                final availableActions = ExpiryUtils.getAvailableActions(estadoProducto);
                                return Container(
                                  margin: EdgeInsets.only(
                                    left: 12,
                                    right: 12,
                                    top: i == 0 ? 4 : 2,
                                    bottom: i == itemsInLocation.length - 1 ? 8 : 2,
                                  ),
                                  decoration: BoxDecoration(
                                    // Fondo ligeramente tintado para todos los items, independientemente de la franja,
                                    // de forma que la única diferencia visual sea la franja de la izquierda.
                                    color: colorScheme.surfaceVariant.withAlpha((255 * 0.65).round()),
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
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      children: [
                                        if (expiryColor != Colors.transparent)
                                          Positioned(
                                            left: 0,
                                            top: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 10,
                                              color: expiryColor,
                                            ),
                                          ),
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(expiryColor != Colors.transparent ? 12 : 14, 12, 14, 12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              // FILA PRINCIPAL: Imagen + Información + Badges
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  CircleAvatar(
                                                    radius: 20,
                                                    backgroundColor: Colors.grey[200],
                                                    child: imageUrl != null
                                                        ? ClipOval(
                                                            child: Image.network(
                                                              imageUrl,
                                                              fit: BoxFit.cover,
                                                              width: 40,
                                                              height: 40,
                                                              loadingBuilder: (context, child, progress) => progress == null
                                                                  ? child
                                                                  : const SizedBox(
                                                                      width: 20,
                                                                      height: 20,
                                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                                    ),
                                                              errorBuilder: (context, error, stackTrace) => const Icon(
                                                                Icons.image_not_supported,
                                                                color: Colors.grey,
                                                                size: 20,
                                                              ),
                                                            ),
                                                          )
                                                        : const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 20),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        // ═══════════════════════════════════════════════════
                                                        // 📱 DISEÑO UX/UI DE CLASE MUNDIAL
                                                        // ═══════════════════════════════════════════════════
                                                        
                                                        // 1️⃣ NOMBRE + MARCA (en una sola línea, jerarquía visual clara)
                                                        Padding(
                                                          padding: const EdgeInsets.only(right: 48),
                                                          child: RichText(
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                            text: TextSpan(
                                                              children: [
                                                                TextSpan(
                                                                  text: productName,
                                                                  style: textTheme.titleMedium?.copyWith(
                                                                    fontWeight: FontWeight.w700,
                                                                    fontSize: 15,
                                                                    color: colorScheme.onSurface,
                                                                  ),
                                                                ),
                                                                if (brand != null && brand.isNotEmpty) ...[
                                                                  TextSpan(
                                                                    text: ' · ',
                                                                    style: textTheme.bodySmall?.copyWith(
                                                                      color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                                                                      fontWeight: FontWeight.w300,
                                                                    ),
                                                                  ),
                                                                  TextSpan(
                                                                    text: brand,
                                                                    style: textTheme.bodySmall?.copyWith(
                                                                      color: colorScheme.onSurfaceVariant,
                                                                      fontSize: 13,
                                                                      fontWeight: FontWeight.w500,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        
                                                        // 2️⃣ ALERTA PRIORITARIA + FECHA DE CADUCIDAD (destacada con color e icono)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                          decoration: BoxDecoration(
                                                            color: expiryColor != Colors.transparent
                                                                ? expiryColor.withAlpha((255 * 0.12).round())
                                                                : colorScheme.surfaceVariant.withAlpha((255 * 0.5).round()),
                                                            borderRadius: BorderRadius.circular(6),
                                                            border: Border.all(
                                                              color: expiryColor != Colors.transparent
                                                                  ? expiryColor.withAlpha((255 * 0.3).round())
                                                                  : Colors.transparent,
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: IntrinsicHeight(
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(
                                                                  daysUntilExpiry < 0 
                                                                      ? Icons.dangerous_rounded
                                                                      : daysUntilExpiry <= 3
                                                                          ? Icons.warning_amber_rounded
                                                                          : daysUntilExpiry <= 7
                                                                              ? Icons.schedule_rounded
                                                                              : Icons.check_circle_outline_rounded,
                                                                  size: 16,
                                                                  color: expiryColor != Colors.transparent
                                                                      ? expiryColor
                                                                      : colorScheme.onSurfaceVariant,
                                                                ),
                                                                const SizedBox(width: 6),
                                                                // Badge de urgencia (si aplica)
                                                                if (expiryColor != Colors.transparent) ...[
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                                    decoration: BoxDecoration(
                                                                      color: expiryColor,
                                                                      borderRadius: BorderRadius.circular(4),
                                                                    ),
                                                                    child: Text(
                                                                      statusLabel.toUpperCase(),
                                                                      style: textTheme.labelSmall?.copyWith(
                                                                        color: Colors.white,
                                                                        fontSize: 9,
                                                                        fontWeight: FontWeight.w800,
                                                                        letterSpacing: 0.5,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 5),
                                                                  Text(
                                                                    '·',
                                                                    style: TextStyle(
                                                                      color: expiryColor.withAlpha((255 * 0.5).round()),
                                                                      fontWeight: FontWeight.w300,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 5),
                                                                ],
                                                                Flexible(
                                                                  child: Text(
                                                                    '${expiryDate.day.toString().padLeft(2, '0')}/${expiryDate.month.toString().padLeft(2, '0')}/${expiryDate.year}',
                                                                    style: textTheme.bodySmall?.copyWith(
                                                                      color: expiryColor != Colors.transparent
                                                                          ? expiryColor
                                                                          : colorScheme.onSurfaceVariant,
                                                                      fontSize: 11,
                                                                      fontWeight: FontWeight.w700,
                                                                      decoration: daysUntilExpiry < 0 
                                                                          ? TextDecoration.lineThrough 
                                                                          : null,
                                                                    ),
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        
                                                        // 3️⃣ ESTADO DEL PRODUCTO (Abierto/Congelado) con fecha contextual
                                                        if (ExpiryUtils.shouldShowStateBadge(estadoProducto)) ...[
                                                          const SizedBox(height: 6),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                            decoration: BoxDecoration(
                                                              color: ExpiryUtils.getStateBadgeColor(estadoProducto).withAlpha((255 * 0.12).round()),
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(
                                                                color: ExpiryUtils.getStateBadgeColor(estadoProducto).withAlpha((255 * 0.3).round()),
                                                                width: 1,
                                                              ),
                                                            ),
                                                            child: IntrinsicHeight(
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Icon(
                                                                    ExpiryUtils.getStateIcon(estadoProducto),
                                                                    size: 16,
                                                                    color: ExpiryUtils.getStateBadgeColor(estadoProducto),
                                                                  ),
                                                                  const SizedBox(width: 6),
                                                                  Text(
                                                                    ExpiryUtils.getStateLabel(estadoProducto).toUpperCase(),
                                                                    style: textTheme.labelSmall?.copyWith(
                                                                      color: ExpiryUtils.getStateBadgeColor(estadoProducto),
                                                                      fontSize: 10,
                                                                      fontWeight: FontWeight.w800,
                                                                      letterSpacing: 0.6,
                                                                    ),
                                                                  ),
                                                                  // Fecha de apertura, congelación o descongelación
                                                                  if ((estadoProducto == 'abierto' && item['fecha_apertura'] != null) ||
                                                                      (estadoProducto == 'congelado' && item['fecha_congelacion'] != null) ||
                                                                      (estadoProducto == 'descongelado' && item['fecha_descongelacion'] != null)) ...[
                                                                    const SizedBox(width: 6),
                                                                    Text(
                                                                      '·',
                                                                      style: TextStyle(
                                                                        color: ExpiryUtils.getStateBadgeColor(estadoProducto).withAlpha((255 * 0.5).round()),
                                                                        fontWeight: FontWeight.w300,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(width: 6),
                                                                    Flexible(
                                                                      child: Text(
                                                                        () {
                                                                          final fecha = estadoProducto == 'abierto'
                                                                              ? DateTime.parse(item['fecha_apertura'])
                                                                              : estadoProducto == 'congelado'
                                                                              ? DateTime.parse(item['fecha_congelacion'])
                                                                              : DateTime.parse(item['fecha_descongelacion']);
                                                                          return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
                                                                        }(),
                                                                        style: textTheme.bodySmall?.copyWith(
                                                                          color: ExpiryUtils.getStateBadgeColor(estadoProducto),
                                                                          fontSize: 11,
                                                                          fontWeight: FontWeight.w700,
                                                                        ),
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                  // Ícono de info para mostrar historial (solo para descongelados)
                                                                  if (estadoProducto == 'descongelado' && 
                                                                      item['fecha_congelacion'] != null &&
                                                                      item['fecha_descongelacion'] != null) ...[
                                                                    const SizedBox(width: 4),
                                                                    GestureDetector(
                                                                      onTap: () {
                                                                        final fechaCongelacion = DateTime.parse(item['fecha_congelacion']);
                                                                        final fechaDescongelacion = DateTime.parse(item['fecha_descongelacion']);
                                                                        showDialog(
                                                                          context: context,
                                                                          builder: (ctx) => AlertDialog(
                                                                            title: const Text('Historial de Congelación'),
                                                                            content: Column(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              children: [
                                                                                Row(
                                                                                  children: [
                                                                                    Icon(Icons.ac_unit_rounded, color: Colors.blue.shade700, size: 20),
                                                                                    const SizedBox(width: 8),
                                                                                    Text(
                                                                                      'Congelado: ${fechaCongelacion.day.toString().padLeft(2, '0')}/${fechaCongelacion.month.toString().padLeft(2, '0')}/${fechaCongelacion.year}',
                                                                                      style: const TextStyle(fontSize: 14),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                                const SizedBox(height: 8),
                                                                                Row(
                                                                                  children: [
                                                                                    Icon(Icons.severe_cold_rounded, color: Colors.teal.shade700, size: 20),
                                                                                    const SizedBox(width: 8),
                                                                                    Text(
                                                                                      'Descongelado: ${fechaDescongelacion.day.toString().padLeft(2, '0')}/${fechaDescongelacion.month.toString().padLeft(2, '0')}/${fechaDescongelacion.year}',
                                                                                      style: const TextStyle(fontSize: 14),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                                const SizedBox(height: 12),
                                                                                Text(
                                                                                  '${fechaDescongelacion.difference(fechaCongelacion).inDays} días congelado',
                                                                                  style: TextStyle(
                                                                                    fontSize: 12,
                                                                                    fontStyle: FontStyle.italic,
                                                                                    color: colorScheme.onSurface.withOpacity(0.6),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                            actions: [
                                                                              TextButton(
                                                                                onPressed: () => Navigator.of(ctx).pop(),
                                                                                child: const Text('Cerrar'),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        );
                                                                      },
                                                                      child: Icon(
                                                                        Icons.info_outline_rounded,
                                                                        size: 16,
                                                                        color: ExpiryUtils.getStateBadgeColor(estadoProducto).withAlpha((255 * 0.7).round()),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  // Badge de cantidad + botón editar (columna derecha)
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: colorScheme.primaryContainer,
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Text(
                                                          'x$quantity',
                                                          style: textTheme.labelLarge?.copyWith(
                                                            fontWeight: FontWeight.w700,
                                                            color: colorScheme.onPrimaryContainer,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      // Botón Editar
                                                      IconButton(
                                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                        padding: const EdgeInsets.all(6),
                                                        tooltip: 'Editar',
                                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                                        onPressed: () => _showEditStockItemDialog(item),
                                                        style: IconButton.styleFrom(
                                                          backgroundColor: colorScheme.primaryContainer,
                                                          foregroundColor: colorScheme.onPrimaryContainer,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              
                                              // Separador visual entre información y acciones
                                              const SizedBox(height: 12),
                                              Divider(
                                                color: colorScheme.outlineVariant.withOpacity(0.3),
                                                thickness: 1,
                                                height: 1,
                                              ),
                                              const SizedBox(height: 12),
                                              
                                              // 4️⃣ BOTONES DE ACCIÓN (centrados en todo el ancho)
                                              Center(
                                                child: Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  alignment: WrapAlignment.center,
                                                  children: [
                                                          // Botón Abrir (solo si cerrado)
                                                          if (availableActions['abrir'] == true)
                                                            IconButton(
                                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                              padding: const EdgeInsets.all(6),
                                                              tooltip: 'Abrir',
                                                              icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                                              onPressed: () => _showOpenProductDialog(item),
                                                              style: IconButton.styleFrom(
                                                                backgroundColor: Colors.orange.shade100,
                                                                foregroundColor: Colors.orange.shade800,
                                                              ),
                                                            ),
                                                          // Botón Congelar (si no está congelado)
                                                          if (availableActions['congelar'] == true)
                                                            IconButton(
                                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                              padding: const EdgeInsets.all(6),
                                                              tooltip: 'Congelar',
                                                              icon: const Icon(Icons.ac_unit_rounded, size: 18),
                                                              onPressed: () => _showFreezeProductDialog(item),
                                                              style: IconButton.styleFrom(
                                                                backgroundColor: Colors.blue.shade100,
                                                                foregroundColor: Colors.blue.shade800,
                                                              ),
                                                            ),
                                                          // Botón Descongelar (solo si congelado)
                                                          if (availableActions['descongelar'] == true)
                                                            IconButton(
                                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                              padding: const EdgeInsets.all(6),
                                                              tooltip: 'Descongelar',
                                                              icon: const Icon(Icons.wb_sunny_rounded, size: 18),
                                                              onPressed: () => _showUnfreezeProductDialog(item),
                                                              style: IconButton.styleFrom(
                                                                backgroundColor: Colors.amber.shade100,
                                                                foregroundColor: Colors.amber.shade800,
                                                              ),
                                                            ),
                                                          // Botón Reubicar (siempre disponible)
                                                          if (availableActions['reubicar'] == true)
                                                            IconButton(
                                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                              padding: const EdgeInsets.all(6),
                                                              tooltip: 'Reubicar',
                                                              icon: const Icon(Icons.move_up_rounded, size: 18),
                                                              onPressed: () => _showRelocateProductDialog(item),
                                                              style: IconButton.styleFrom(
                                                                backgroundColor: Colors.purple.shade100,
                                                                foregroundColor: Colors.purple.shade800,
                                                              ),
                                                            ),
                                                          // Botón Usar
                                                          IconButton(
                                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                            padding: const EdgeInsets.all(6),
                                                            tooltip: 'Usar',
                                                            icon: const Icon(Icons.remove_circle_outline, size: 18),
                                                            onPressed: () => showRemoveQuantityDialog(
                                                              stockId, 
                                                              quantity, 
                                                              productName,
                                                              item['producto_maestro']['id_producto'],
                                                            ),
                                                            style: IconButton.styleFrom(
                                                              backgroundColor: colorScheme.secondaryContainer,
                                                              foregroundColor: colorScheme.onSecondaryContainer,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
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
      ),
    );
  }
  void _showEditStockItemDialog(dynamic item) {
    final colorScheme = Theme.of(context).colorScheme;
    final producto = item['producto_maestro'];
    final stockId = item['id_stock'] as int;
    final initialName = producto['nombre'] as String? ?? '';
    final initialBrand = (producto['marca'] as String?) ?? '';
    final initialQty = item['cantidad_actual'] as int;
    final initialExpiry = DateTime.parse(item['fecha_caducidad']);

    final nameController = TextEditingController(text: initialName);
    final brandController = TextEditingController(text: initialBrand);
    final qtyController = TextEditingController(text: initialQty.toString());
    final dateController = TextEditingController(text: '${initialExpiry.day.toString().padLeft(2,'0')}/${initialExpiry.month.toString().padLeft(2,'0')}/${initialExpiry.year}');
    DateTime selectedDate = initialExpiry;
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    Future<void> pickDate(StateSetter setStateModal) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
      );
      if (picked != null) {
        setStateModal(() {
          selectedDate = picked;
          dateController.text = '${picked.day.toString().padLeft(2,'0')}/${picked.month.toString().padLeft(2,'0')}/${picked.year}';
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Editar Producto',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre del producto',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.edit),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Introduce un nombre' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: brandController,
                      decoration: InputDecoration(
                        labelText: 'Marca (opcional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.branding_watermark),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: qtyController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: 'Cantidad',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: saving ? null : () {
                                  final current = int.tryParse(qtyController.text) ?? 1;
                                  if (current > 1) {
                                    setStateModal(() => qtyController.text = (current - 1).toString());
                                  }
                                },
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: saving ? null : () {
                                  final current = int.tryParse(qtyController.text) ?? 0;
                                  setStateModal(() => qtyController.text = (current + 1).toString());
                                },
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Requerido';
                              final n = int.tryParse(v);
                              if (n == null || n <= 0) return '> 0';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: dateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Fecha de caducidad',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      onTap: saving ? null : () => pickDate(setStateModal),
                    ),
                    const SizedBox(height: 24),
                    if (saving)
                      const Center(child: CircularProgressIndicator())
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                if (!(formKey.currentState?.validate() ?? false)) return;
                                setStateModal(() => saving = true);
                                try {
                                  await updateStockItem(
                                    stockId: stockId,
                                    productName: nameController.text.trim() != initialName ? nameController.text.trim() : null,
                                    brand: brandController.text.trim() != initialBrand ? brandController.text.trim() : null,
                                    cantidadActual: int.parse(qtyController.text),
                                    fechaCaducidad: selectedDate != initialExpiry ? selectedDate : null,
                                  );
                                  await refreshInventory();
                                  if (mounted) {
                                    Navigator.of(ctx).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Ítem actualizado.'),
                                        backgroundColor: colorScheme.primary,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setStateModal(() => saving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error al actualizar: $e'),
                                      backgroundColor: colorScheme.error,
                                    ),
                                  );
                                }
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Guardar'),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
