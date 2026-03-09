import 'package:flutter/material.dart';
import 'package:frontend/screens/batch_scanner_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/models/ubicacion.dart';
import 'package:frontend/utils/expiry_utils.dart';
import 'package:frontend/widgets/quantity_selection_dialog.dart';

class BatchOrganizerScreen extends StatefulWidget {
  final List<ScannedItem> scannedItems;

  const BatchOrganizerScreen({super.key, required this.scannedItems});

  @override
  State<BatchOrganizerScreen> createState() => _BatchOrganizerScreenState();
}

class _BatchOrganizerScreenState extends State<BatchOrganizerScreen> {
  // State
  bool _isLoading = true;
  List<Ubicacion> _locations = [];
  
  // Data Structure: Location ID -> List of Items
  // Key -1 represents "Unclassified"
  Map<int, List<OrganizedItem>> _groupedItems = {};
  
  // Grouping Helper
  Map<String, List<OrganizedItem>> _groupItemsByProductAndDate(List<OrganizedItem> items) {
    final Map<String, List<OrganizedItem>> groups = {};
    for (var item in items) {
      final key = '${item.scannedItem.barcode}_${item.scannedItem.expiryDate?.toIso8601String()}';
      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(item);
    }
    return groups;
  }
  
  // Cache for product names
  Map<String, String> _productNames = {};
  Map<String, String?> _productImages = {}; // Cache for product images
  Map<String, int> _productIds = {};

  // Selection Mode
  Set<OrganizedItem> _selectedItems = {};
  bool get _isSelectionMode => _selectedItems.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initializeOrganizer();
  }

  Future<void> _initializeOrganizer() async {
    try {
      // 1. Fetch Locations
      _locations = await fetchUbicaciones();
      
      // 2. Fetch Product Details for each barcode
      // Optimization: Could be a batch endpoint, but loop is fine for < 20 items
      for (var item in widget.scannedItems) {
        final product = await fetchProductFromCatalog(item.barcode);
        if (product != null) {
          _productNames[item.barcode] = product['nombre'];
          _productIds[item.barcode] = product['id_producto'];
          _productImages[item.barcode] = product['imagen_url'] ?? item.productImageUrl;
        } else {
          // Try OpenFoodFacts or default
          final offProduct = await fetchProductFromOpenFoodFacts(item.barcode);
          _productNames[item.barcode] = offProduct?['product_name'] ?? 'Producto Desconocido';
          _productImages[item.barcode] = offProduct?['image_url'] ?? item.productImageUrl;
          // No ID yet, will be created on save
        }
      }

      // 3. Get Smart Suggestions
      final productIds = _productIds.values.toList();
      Map<int, int> suggestions = {};
      if (productIds.isNotEmpty) {
        suggestions = await getProductSuggestions(productIds);
      }

      // 4. Group Items
      _groupedItems = { -1: [] }; // Init unclassified
      for (var loc in _locations) {
        _groupedItems[loc.id] = [];
      }

      for (var item in widget.scannedItems) {
        final productId = _productIds[item.barcode];
        final suggestedLocId = productId != null ? suggestions[productId] : null;
        
        final targetLocId = suggestedLocId ?? -1;
        
        // Ensure list exists (in case suggestion is for a deleted location?)
        if (!_groupedItems.containsKey(targetLocId)) {
           _groupedItems[targetLocId] = [];
        }

        // Create multiple entries based on quantity
        for (int i = 0; i < item.quantity; i++) {
          _groupedItems[targetLocId]!.add(OrganizedItem(
            scannedItem: item,
            productName: _productNames[item.barcode] ?? 'Cargando...',
            imageUrl: _productImages[item.barcode],
            locationId: targetLocId,
          ));
        }
      }

    } catch (e) {
      print("Error initializing organizer: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando datos: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _moveItem(OrganizedItem item, int newLocationId) {
    setState(() {
      // Remove from old
      _groupedItems[item.locationId]?.remove(item);
      
      // Update item
      item.locationId = newLocationId;
      
      // Add to new
      if (!_groupedItems.containsKey(newLocationId)) {
        _groupedItems[newLocationId] = [];
      }
      _groupedItems[newLocationId]!.add(item);
    });
  }

  void _toggleSelection(OrganizedItem item) {
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
      } else {
        _selectedItems.add(item);
      }
    });
  }

  Future<void> _editItem(OrganizedItem item) async {
    final nameController = TextEditingController(text: item.productName);
    DateTime? selectedDate = item.scannedItem.expiryDate;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Editar Producto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre del Producto'),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(selectedDate != null 
                  ? 'Vence: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}' 
                  : 'Sin Fecha'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2000), // Allow past dates
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (picked != null) {
                    setStateDialog(() => selectedDate = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () {
                _updateItem(item, nameController.text, selectedDate);
                Navigator.pop(context);
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateItem(OrganizedItem item, String newName, DateTime? newDate) {
      setState(() {
        // Create new ScannedItem (immutable)
        final newItem = ScannedItem(
          barcode: item.scannedItem.barcode,
          expiryDate: newDate,
          imagePath: item.scannedItem.imagePath,
          productImageUrl: item.scannedItem.productImageUrl
        );
        
        final list = _groupedItems[item.locationId]!;
        final index = list.indexOf(item);
        if (index != -1) {
           // Replace with new instance
           final newOrganizedItem = OrganizedItem(
             scannedItem: newItem,
             productName: newName,
             imageUrl: item.imageUrl,
             locationId: item.locationId
           );
           list[index] = newOrganizedItem;
           
           // Update selection if needed
           if (_selectedItems.contains(item)) {
              _selectedItems.remove(item);
              _selectedItems.add(newOrganizedItem);
           }
        }
      });
  }

  void _moveSelectedItems() async {
      // Check if all selected items belong to the same group (Product+Date)
      // This enables "Partial Move" logic
      bool isSingleGroup = false;
      String? groupKey;
      
      if (_selectedItems.length > 1) {
        isSingleGroup = true;
        for (var item in _selectedItems) {
           final key = '${item.scannedItem.barcode}_${item.scannedItem.expiryDate?.toIso8601String()}';
           if (groupKey == null) {
             groupKey = key;
           } else if (groupKey != key) {
             isSingleGroup = false;
             break;
           }
        }
      }

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(isSingleGroup ? 'Mover ${_selectedItems.length} items a...' : 'Mover a...'),
          children: _locations.map((l) => SimpleDialogOption(
            onPressed: () => Navigator.pop(context, {'locId': l.id}),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(l.nombre, style: const TextStyle(fontSize: 16)),
            ),
          )).toList(),
        ),
      );
      
      if (result != null) {
        final locId = result['locId'] as int;
        
        // If single group, ask for quantity (Partial Move)
        // BUT only if we are selecting from a larger group? 
        // Actually, the user selects the GROUP first, then we ask quantity.
        // Let's change the flow: User taps "Move" on a GROUP card.
        
        // Current flow: User selects items (toggles).
        // If we want "Partial Move", we need to know how many to move.
        // If I select a group of 6, and say "Move", I should be asked "How many?".
        
        int quantityToMove = _selectedItems.length;
        
        if (isSingleGroup && _selectedItems.length > 1) {
           // Ask for quantity
           final qty = await showDialog<int>(
             context: context,
             builder: (context) {
               int currentQty = _selectedItems.length;
               return StatefulBuilder(
                 builder: (context, setStateDialog) => AlertDialog(
                   title: const Text('¿Cuántos mover?'),
                   content: Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       IconButton(
                         icon: const Icon(Icons.remove_circle_outline),
                         onPressed: () {
                           if (currentQty > 1) setStateDialog(() => currentQty--);
                         },
                       ),
                       Text('$currentQty', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                       IconButton(
                         icon: const Icon(Icons.add_circle_outline),
                         onPressed: () {
                           if (currentQty < _selectedItems.length) setStateDialog(() => currentQty++);
                         },
                       ),
                     ],
                   ),
                   actions: [
                     TextButton(
                       onPressed: () => Navigator.pop(context),
                       child: const Text('CANCELAR'),
                     ),
                     FilledButton(
                       onPressed: () => Navigator.pop(context, currentQty),
                       child: const Text('MOVER'),
                     ),
                   ],
                 ),
               );
             }
           );
           if (qty != null) {
             quantityToMove = qty;
           } else {
             return; // Cancelled
           }
        }

        // Move the first N items
        int moved = 0;
        for (var item in _selectedItems.toList()) {
           if (moved >= quantityToMove) break;
           _moveItem(item, locId);
           moved++;
        }
        
        setState(() {
          _selectedItems.clear();
        });
      }
  }

  Future<void> _saveAll() async {
    // Validate: No items in -1 (Unclassified) and all have dates?
    final unclassified = _groupedItems[-1];
    if (unclassified != null && unclassified.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor asigna ubicación a todos los productos.')),
      );
      return;
    }

    // Validate: All items must have an expiry date
    bool hasMissingDates = false;
    for (var list in _groupedItems.values) {
      for (var item in list) {
        if (item.scannedItem.expiryDate == null) {
          hasMissingDates = true;
          break;
        }
      }
    }

    if (hasMissingDates) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todos los productos deben tener fecha de caducidad.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      int successCount = 0;
      
      for (var entry in _groupedItems.entries) {
        final locId = entry.key;
        if (locId == -1) continue;

        for (var item in entry.value) {
          // Date is mandatory now
          final expiry = item.scannedItem.expiryDate!;
          
          if (_productIds.containsKey(item.scannedItem.barcode)) {
             // Existing product -> Add Scan
             await addScannedStockItem(
               barcode: item.scannedItem.barcode,
               productName: item.productName,
               ubicacionId: locId,
               cantidad: 1,
               fechaCaducidad: expiry,
             );
          } else {
            // New product -> Manual Add (which creates product)
            await addManualStockItem(
              productName: item.productName,
              barcode: item.scannedItem.barcode,
              imageUrl: item.imageUrl,
              ubicacionId: locId,
              cantidad: 1,
              fechaCaducidad: expiry,
            );
          }
          successCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡$successCount productos guardados!')),
        );
        Navigator.popUntil(context, ModalRoute.withName('/'));
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizar Compra'),
        actions: [
          TextButton(
            onPressed: _saveAll,
            child: const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Unclassified Section (Important!)
          if (_groupedItems[-1]?.isNotEmpty ?? false)
            _buildSection('Sin Clasificar', -1, Colors.orange.shade100),

          // 2. Classified Sections
          ..._locations.map((loc) {
            final items = _groupedItems[loc.id];
            if (items == null || items.isEmpty) return const SizedBox.shrink();
            return _buildSection(loc.nombre, loc.id, Colors.white);
          }),
        ],
      ),

      bottomNavigationBar: _isSelectionMode ? BottomAppBar(
        color: Colors.blueGrey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_selectedItems.length} seleccionados', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              FilledButton.icon(
                onPressed: _moveSelectedItems,
                icon: const Icon(Icons.drive_file_move),
                label: const Text('MOVER'),
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              )
            ],
          ),
        ),
      ) : null,
    );
  }

  Widget _buildSection(String title, int locId, Color bg) {
    final items = _groupedItems[locId] ?? [];
    // Group items for display
    final groups = _groupItemsByProductAndDate(items);

    return Card(
      color: bg,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${items.length} items', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...groups.entries.map((entry) {
            final groupItems = entry.value;
            final firstItem = groupItems.first;
            final isSelected = groupItems.every((i) => _selectedItems.contains(i));
            final isPartialSelected = !isSelected && groupItems.any((i) => _selectedItems.contains(i));
            
            return ListTile(
              leading: Stack(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: firstItem.imageUrl != null 
                        ? DecorationImage(image: NetworkImage(firstItem.imageUrl!), fit: BoxFit.cover)
                        : null,
                      color: Colors.grey[200],
                    ),
                    child: firstItem.imageUrl == null ? const Icon(Icons.image_not_supported) : null,
                  ),
                  if (isSelected || isPartialSelected)
                    Positioned.fill(
                      child: Container(
                        color: Colors.blue.withOpacity(0.3),
                        child: const Icon(Icons.check, color: Colors.white),
                      ),
                    ),
                ],
              ),
              title: Text(firstItem.productName),
              subtitle: Text(firstItem.scannedItem.expiryDate != null 
                ? 'Vence: ${firstItem.scannedItem.expiryDate!.day}/${firstItem.scannedItem.expiryDate!.month}/${firstItem.scannedItem.expiryDate!.year}'
                : 'Falta Fecha',
                style: TextStyle(color: firstItem.scannedItem.expiryDate == null ? Colors.red : null),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('x${groupItems.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  if (locId == -1) // Only show move button if unclassified? No, selection mode handles move.
                    const SizedBox.shrink(),
                ],
              ),
              onTap: () {
                if (_isSelectionMode) {
                  // Toggle all in group
                  setState(() {
                    if (isSelected) {
                      _selectedItems.removeAll(groupItems);
                    } else {
                      _selectedItems.addAll(groupItems);
                    }
                  });
                } else {
                  // Edit first item (and propagate changes?) 
                  // Or open group edit dialog?
                  // For now, edit first item logic but apply to all?
                  // Simpler: Edit just one instance or show list?
                  // Let's stick to simple edit for now, maybe just edit the first one creates confusion.
                  // Better: Edit Dialog applies to ALL in group or splits?
                  // Let's assume edit applies to the group for now (e.g. wrong date).
                  _editGroup(groupItems);
                }
              },
              onLongPress: () {
                setState(() {
                  _selectedItems.addAll(groupItems);
                });
              },
            );
          }),
        ],
      ),
    );
  }

  Future<void> _editGroup(List<OrganizedItem> groupItems) async {
    // Edit Name and Date for the whole group
    final firstItem = groupItems.first;
    final nameController = TextEditingController(text: firstItem.productName);
    DateTime? selectedDate = firstItem.scannedItem.expiryDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Editar Grupo (${groupItems.length})'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre del Producto'),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(selectedDate != null 
                  ? 'Vence: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}' 
                  : 'Sin Fecha'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (picked != null) {
                    setStateDialog(() => selectedDate = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () {
                // Update ALL items in group
                for (var item in groupItems) {
                   _updateItem(item, nameController.text, selectedDate);
                }
                Navigator.pop(context);
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }
}

class OrganizedItem {
  final ScannedItem scannedItem;
  String productName;
  String? imageUrl;
  int locationId;

  OrganizedItem({
    required this.scannedItem,
    required this.productName,
    this.imageUrl,
    required this.locationId,
  });
}
