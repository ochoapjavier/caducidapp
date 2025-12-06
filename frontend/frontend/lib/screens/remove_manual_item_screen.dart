import 'package:flutter/material.dart';
import 'package:frontend/models/ubicacion.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/shopping_service.dart';
import 'package:frontend/services/hogar_service.dart';
import 'package:intl/intl.dart';
import 'package:frontend/utils/expiry_utils.dart';
import 'package:frontend/widgets/quantity_selection_dialog.dart';

class RemoveManualItemScreen extends StatefulWidget {
  const RemoveManualItemScreen({super.key});

  @override
  State<RemoveManualItemScreen> createState() => _RemoveManualItemScreenState();
}

class _RemoveManualItemScreenState extends State<RemoveManualItemScreen> {
  final _quantityController = TextEditingController(text: '1');
  
  // Estado
  bool _isLoading = false;
  List<dynamic> _fullStock = [];
  List<Ubicacion> _ubicaciones = [];
  
  // Selección
  Ubicacion? _selectedUbicacion;
  dynamic _selectedStockItem;
  List<dynamic> _itemsInLocation = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        fetchUbicaciones(),
        fetchStockItems(),
      ]);
      if (mounted) {
        setState(() {
          _ubicaciones = results[0] as List<Ubicacion>;
          _fullStock = results[1] as List<dynamic>;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: ${e.toString()}')),
        );
      }
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
      _selectedStockItem = null;
      _quantityController.text = '1';
      if (ubicacion != null) {
        _itemsInLocation = _fullStock
            .where((item) => item['ubicacion']['id_ubicacion'] == ubicacion.id)
            .toList();
      } else {
        _itemsInLocation = [];
      }
    });
  }

  void _onStockItemChanged(dynamic item) {
    setState(() {
      _selectedStockItem = item;
      _quantityController.text = '1';
    });
    
    if (item != null) {
      _showQuantityModal(item);
    }
  }

  void _showQuantityModal(dynamic item) {
    final maxQuantity = item['cantidad_actual'] as int;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => QuantitySelectionDialog(
        title: 'Eliminar "${item['producto_maestro']['nombre']}"',
        subtitle: 'Ubicación: ${item['ubicacion']['nombre']}',
        maxQuantity: maxQuantity,
        onConfirm: (quantity, addToShoppingList) {
          _submitRemoval(item, quantity, addToShoppingList);
        },
      ),
    );
  }

  Future<void> _submitRemoval(dynamic item, int quantity, bool addToShoppingList) async {
    setState(() => _isLoading = true);
    final productName = item['producto_maestro']['nombre'];
    final productId = item['producto_maestro']['id_producto'];

    try {
      await removeStockItems(
        stockId: item['id_stock'],
        cantidad: quantity,
      );

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(addToShoppingList 
              ? 'Eliminado y añadido a la lista.' 
              : 'Stock actualizado.'),
            backgroundColor: Colors.green,
          ),
        );
        // Recargar datos
        _loadInitialData();
        // Limpiar selección
        setState(() {
          _selectedStockItem = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salida Manual'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
        children: [
          // Selector de Ubicación
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<Ubicacion>(
              value: _selectedUbicacion,
              decoration: const InputDecoration(
                labelText: 'Selecciona Ubicación',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              items: _ubicaciones.map((u) => DropdownMenuItem(
                value: u,
                child: Text(u.nombre),
              )).toList(),
              onChanged: _onUbicacionChanged,
            ),
          ),
          
          // Lista de Productos
          Expanded(
            child: _selectedUbicacion == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app, size: 64, color: Theme.of(context).disabledColor),
                      const SizedBox(height: 16),
                      const Text('Elige una ubicación para ver productos'),
                    ],
                  ),
                )
              : _itemsInLocation.isEmpty
                ? const Center(child: Text('No hay productos aquí.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _itemsInLocation.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _itemsInLocation[index];
                      final name = item['producto_maestro']['nombre'];
                      final expiry = DateTime.parse(item['fecha_caducidad']);
                      final fmtExpiry = DateFormat('dd/MM/yy').format(expiry);
                      final qty = item['cantidad_actual'];
                      final estado = item['estado_producto'] ?? 'cerrado';
                      final showBadge = ExpiryUtils.shouldShowStateBadge(estado);
                      final badgeColor = ExpiryUtils.getStateBadgeColor(estado);
                      final badgeLabel = ExpiryUtils.getStateLabel(estado);
                      
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () => _onStockItemChanged(item),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.inventory_2, color: Theme.of(context).colorScheme.onPrimaryContainer),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text('Cad: $fmtExpiry', style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                                          const SizedBox(width: 12),
                                          Icon(Icons.numbers, size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text('Cant: $qty', style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                                          if (showBadge) ...[
                                            const SizedBox(width: 12),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: badgeColor.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: badgeColor, width: 1),
                                              ),
                                              child: Text(
                                                badgeLabel,
                                                style: TextStyle(
                                                  color: badgeColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: Colors.grey[400]),
                              ],
                            ),
                          ),
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