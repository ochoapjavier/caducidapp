import 'package:flutter/material.dart';
import 'package:frontend/screens/batch_scanner_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/models/ubicacion.dart';
import 'package:frontend/utils/expiry_utils.dart';

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
  
  // Cache for product names
  Map<String, String> _productNames = {};
  Map<String, int> _productIds = {};

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
        } else {
          // Try OpenFoodFacts or default
          final offProduct = await fetchProductFromOpenFoodFacts(item.barcode);
          _productNames[item.barcode] = offProduct?['product_name'] ?? 'Producto Desconocido';
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

        _groupedItems[targetLocId]!.add(OrganizedItem(
          scannedItem: item,
          productName: _productNames[item.barcode] ?? 'Cargando...',
          locationId: targetLocId,
        ));
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

  Future<void> _saveAll() async {
    // Validate: No items in -1 (Unclassified) and all have dates?
    // Actually, let's allow saving even if unclassified (default to first location?)
    // But dates are mandatory for our logic usually.
    
    final unclassified = _groupedItems[-1];
    if (unclassified != null && unclassified.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor asigna ubicación a todos los productos.')),
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
          // If date is missing, default to today + 7 days? Or fail?
          // Let's fail/skip for now or use a default.
          final expiry = item.scannedItem.expiryDate ?? DateTime.now().add(const Duration(days: 7));
          
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
    );
  }

  Widget _buildSection(String title, int locId, Color bg) {
    final items = _groupedItems[locId] ?? [];
    return Card(
      color: bg,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              title, 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
            ),
          ),
          ...items.map((item) => ListTile(
            title: Text(item.productName),
            subtitle: Text(item.scannedItem.expiryDate != null 
              ? 'Vence: ${item.scannedItem.expiryDate!.day}/${item.scannedItem.expiryDate!.month}' 
              : '⚠️ Sin fecha (Se usará +7 días)'),
            trailing: PopupMenuButton<int>(
              icon: const Icon(Icons.swap_vert),
              onSelected: (newLocId) => _moveItem(item, newLocId),
              itemBuilder: (context) => _locations.map((l) => PopupMenuItem(
                value: l.id,
                child: Text(l.nombre),
              )).toList(),
            ),
          )),
        ],
      ),
    );
  }
}

class OrganizedItem {
  final ScannedItem scannedItem;
  String productName;
  int locationId;

  OrganizedItem({
    required this.scannedItem,
    required this.productName,
    required this.locationId,
  });
}
