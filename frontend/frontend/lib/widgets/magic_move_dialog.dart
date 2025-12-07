import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/shopping_service.dart';
import '../models/ubicacion.dart';
import '../screens/scanner_screen.dart';

class MagicMoveDialog extends StatefulWidget {
  final List<dynamic> itemsToMove;

  const MagicMoveDialog({super.key, required this.itemsToMove});

  @override
  State<MagicMoveDialog> createState() => _MagicMoveDialogState();
}

class _MagicMoveDialogState extends State<MagicMoveDialog> {
  final ShoppingService _shoppingService = ShoppingService();
  
  // Lista local mutable para permitir modificaciones (nombre, marca, foto)
  late List<Map<String, dynamic>> _items;
  
  // Estado adicional (ubicación, fecha, cantidad)
  final Map<int, Map<String, dynamic>> _itemStates = {};
  
  List<Ubicacion> _locations = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // 1. Clonar items para poder modificarlos localmente
      _items = widget.itemsToMove.map((item) => Map<String, dynamic>.from(item)).toList();

      // 2. Cargar ubicaciones
      final locations = await fetchUbicaciones();
      
      final now = DateTime.now();
      final defaultExpiry = now.add(const Duration(days: 7));
      
      int? defaultLocationId;
      if (locations.isNotEmpty) {
        final despensa = locations.firstWhere(
          (l) => l.nombre.toLowerCase().contains('despensa'),
          orElse: () => locations.first,
        );
        defaultLocationId = despensa.id;
      }

      // 3. Inicializar estados
      for (var item in _items) {
        _itemStates[item['id']] = {
          'locationId': defaultLocationId,
          'expiryDate': defaultExpiry,
          'quantity': item['quantity'] ?? 1,
        };
      }

      if (mounted) {
        setState(() {
          _locations = locations;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing magic move: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _scanBarcode(int index) async {
    // 1. Abrir escáner
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    if (barcode == null) return;

    // 2. Buscar producto
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buscando producto...')),
      );
    }

    try {
      // A. Buscar en catálogo propio
      var productData = await fetchProductFromCatalog(barcode);
      
      // B. Si no está, buscar en OpenFoodFacts
      if (productData == null) {
        productData = await fetchProductFromOpenFoodFacts(barcode);
      }

      if (productData != null && mounted) {
        final data = productData!;
        setState(() {
          // Actualizar datos del item en la lista local
          _items[index]['producto'] = {
            'id': data['id'], // Puede ser null si viene de OFF
            'nombre': data['product_name'] ?? data['nombre'] ?? 'Producto Escaneado',
            'marca': data['brands'] ?? data['marca'],
            'image_url': data['image_url'] ?? data['image_front_url'],
            'codigo_barras': barcode,
          };
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Producto identificado: ${data['product_name'] ?? data['nombre']}!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto no encontrado. Puedes editarlo manualmente.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching product: $e');
    }
  }

  void _showEditDialog(int index) {
    final item = _items[index];
    final nameController = TextEditingController(text: item['producto']['nombre']);
    final brandController = TextEditingController(text: item['producto']['marca']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Producto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: brandController,
              decoration: const InputDecoration(labelText: 'Marca (opcional)'),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                item['producto']['nombre'] = nameController.text;
                item['producto']['marca'] = brandController.text.isEmpty ? null : brandController.text;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _processMove() async {
    setState(() => _isSaving = true);

    try {
      for (var item in _items) {
        final state = _itemStates[item['id']]!;
        final locationId = state['locationId'] as int?;
        final expiryDate = state['expiryDate'] as DateTime;
        
        if (locationId == null) continue;

        // Si el producto viene de OpenFoodFacts o es nuevo, 'id' será null o diferente.
        // addManualStockItem maneja la creación/búsqueda en backend si enviamos barcode.
        
        await addManualStockItem(
          productName: item['producto']['nombre'],
          productId: item['producto']['id'], 
          brand: item['producto']['marca'],
          barcode: item['producto']['codigo_barras'],
          imageUrl: item['producto']['image_url'],
          cantidad: state['quantity'] as int,
          fechaCaducidad: expiryDate,
          ubicacionId: locationId,
        );

        // Borrar de la lista de compra original
        await _shoppingService.deleteItem(item['id']);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error moving items: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al mover productos: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Icon(Icons.auto_fix_high, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mover al Inventario',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _locations.isEmpty
                      ? const Center(child: Text('No hay ubicaciones creadas.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final state = _itemStates[item['id']]!;
                            final productName = item['producto']['nombre'];
                            final brand = item['producto']['marca'];
                            final imageUrl = item['producto']['image_url'];

                            return Card(
                              elevation: 0,
                              color: colorScheme.surfaceContainerHighest.withAlpha((255 * 0.3).round()),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: colorScheme.outlineVariant),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: Image + Name/Brand + Actions
                                    Row(
                                      children: [
                                        if (imageUrl != null)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(imageUrl, width: 48, height: 48, fit: BoxFit.cover),
                                          )
                                        else
                                          Container(
                                            width: 48, 
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: colorScheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(Icons.shopping_bag_outlined, color: colorScheme.onSurfaceVariant),
                                          ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                productName, 
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                              if (brand != null)
                                                Text(brand, style: Theme.of(context).textTheme.bodySmall),
                                            ],
                                          ),
                                        ),
                                        // Acciones: Scan & Edit
                                        IconButton(
                                          icon: const Icon(Icons.qr_code_scanner),
                                          tooltip: 'Escanear producto real',
                                          onPressed: () => _scanBarcode(index),
                                          style: IconButton.styleFrom(
                                            foregroundColor: colorScheme.primary,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          tooltip: 'Editar manualmente',
                                          onPressed: () => _showEditDialog(index),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    // Inputs Section
                                    Column(
                                      children: [
                                        // Row 1: Quantity + Location
                                        Row(
                                          children: [
                                            // Cantidad
                                            SizedBox(
                                              width: 80,
                                              child: TextFormField(
                                                initialValue: state['quantity'].toString(),
                                                keyboardType: TextInputType.number,
                                                decoration: const InputDecoration(
                                                  labelText: 'Cant.',
                                                  isDense: true,
                                                  border: OutlineInputBorder(),
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                ),
                                                onChanged: (val) {
                                                  final q = int.tryParse(val);
                                                  if (q != null && q > 0) {
                                                    state['quantity'] = q;
                                                  }
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Ubicación
                                            Expanded(
                                              child: DropdownButtonFormField<int>(
                                                value: state['locationId'],
                                                decoration: const InputDecoration(
                                                  labelText: 'Ubicación',
                                                  isDense: true,
                                                  border: OutlineInputBorder(),
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                ),
                                                items: _locations.map((loc) {
                                                  return DropdownMenuItem(
                                                    value: loc.id,
                                                    child: Text(
                                                      loc.nombre,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 14),
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (val) {
                                                  setState(() {
                                                    state['locationId'] = val;
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Row 2: Expiry Date
                                        InkWell(
                                          onTap: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: state['expiryDate'],
                                              firstDate: DateTime.now(),
                                              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                                            );
                                            if (picked != null) {
                                              setState(() {
                                                state['expiryDate'] = picked;
                                              });
                                            }
                                          },
                                          child: InputDecorator(
                                            decoration: const InputDecoration(
                                              labelText: 'Fecha de Caducidad',
                                              isDense: true,
                                              border: OutlineInputBorder(),
                                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              suffixIcon: Icon(Icons.calendar_today, size: 20),
                                            ),
                                            child: Text(
                                              DateFormat('dd/MM/yyyy').format(state['expiryDate']),
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 16,
                overflowSpacing: 16,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _processMove,
                    icon: _isSaving 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                    label: Text(_isSaving ? 'Moviendo...' : 'Confirmar Movimiento'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

