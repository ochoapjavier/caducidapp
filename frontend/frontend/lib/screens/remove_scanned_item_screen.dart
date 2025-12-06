import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/shopping_service.dart';
import 'package:frontend/services/hogar_service.dart';
import 'package:frontend/utils/expiry_utils.dart';
import 'package:intl/intl.dart';
import 'package:frontend/widgets/quantity_selection_dialog.dart';

class RemoveScannedItemScreen extends StatefulWidget {
  final String? initialBarcode;
  const RemoveScannedItemScreen({super.key, this.initialBarcode});

  @override
  State<RemoveScannedItemScreen> createState() => _RemoveScannedItemScreenState();
}

class _RemoveScannedItemScreenState extends State<RemoveScannedItemScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = true;
  bool _isLoading = false;
  List<dynamic> _foundItems = [];
  String? _scannedBarcode;

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null) {
      _isScanning = false;
      _scannedBarcode = widget.initialBarcode;
      _isLoading = true;
      // Trigger search immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchByBarcode(widget.initialBarcode!);
      });
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _searchByBarcode(String code) async {
    try {
      // 1. Buscar items con este código de barras en el inventario
      final allStock = await fetchStockItems(searchTerm: code);
      
      // Filtrar por código de barras exacto (por si el search es fuzzy)
      final exactMatches = allStock.where((item) {
        final product = item['producto_maestro'];
        return product != null && product['barcode'] == code;
      }).toList();

      if (mounted) {
        setState(() {
          _foundItems = exactMatches;
          _isLoading = false;
        });
        
        if (_foundItems.isEmpty) {
          _showNotFoundDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al buscar producto: $e')),
        );
        // Volver a escanear
        setState(() => _isScanning = true);
      }
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (!_isScanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() {
      _isScanning = false;
      _scannedBarcode = code;
      _isLoading = true;
    });

    await _searchByBarcode(code);
  }

  void _showNotFoundDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Producto no encontrado'),
        content: Text('No tienes stock del producto con código $_scannedBarcode.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isScanning = true;
                _foundItems = [];
                _scannedBarcode = null;
              });
            },
            child: const Text('Escanear otro'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(), // Salir de la pantalla
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  void _onStockItemSelected(dynamic item) {
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
        Navigator.of(context).pop(true); // Volver y refrescar
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
    if (_isScanning) {
      return Scaffold(
        appBar: AppBar(title: const Text('Escanear para Salida')),
        body: MobileScanner(
          controller: _scannerController,
          onDetect: _onDetect,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultados del Escaneo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isScanning = true;
              _foundItems = [];
              _scannedBarcode = null;
            });
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Código: $_scannedBarcode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _foundItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _foundItems[index];
                      final name = item['producto_maestro']['nombre'];
                      final location = item['ubicacion']['nombre'];
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
                          onTap: () => _onStockItemSelected(item),
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
                                  child: Icon(Icons.qr_code, color: Theme.of(context).colorScheme.onPrimaryContainer),
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
                                      Text(
                                        location,
                                        style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 14),
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