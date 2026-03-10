// frontend/lib/screens/matchmaker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/models/ticket_item.dart';
import 'package:frontend/screens/scanner_screen.dart';

import 'package:frontend/models/supermercado.dart';
import 'package:frontend/services/api_service.dart' as api;

class MatchmakerResult {
  final List<TicketItem> items;
  final int? supermercadoId;
  final String supermercadoNombre;

  MatchmakerResult({
    required this.items,
    this.supermercadoId,
    required this.supermercadoNombre,
  });
}

class MatchmakerScreen extends StatefulWidget {
  final List<TicketItem> initialItems;
  final String guessedSupermercado;

  const MatchmakerScreen({super.key, required this.initialItems, required this.guessedSupermercado});

  @override
  State<MatchmakerScreen> createState() => _MatchmakerScreenState();
}

class _MatchmakerScreenState extends State<MatchmakerScreen> {
  late List<TicketItem> items;
  
  List<Supermercado> supermercados = [];
  List<Map<String, dynamic>> dictionaryMemory = [];
  int? selectedSupermercadoId;
  String customSupermercadoNombre = "Desconocido";
  bool isLoadingSupermercado = true;

  bool _isValidItem(TicketItem item) {
    return item.nombre.trim().isNotEmpty &&
        item.cantidad > 0 &&
        item.precioUnitario > 0 &&
        !item.requiereRevisionCantidad;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    items = List.from(widget.initialItems);
    customSupermercadoNombre = widget.guessedSupermercado;
    _loadSupermercados();
  }

  Future<void> _loadSupermercados() async {
    try {
      final list = await api.getSupermercados();
      try {
        dictionaryMemory = await api.getDictionaryMemory();
      } catch (_) {}
      
      if (!mounted) return;
      setState(() {
        supermercados = list;
        isLoadingSupermercado = false;
        
        // Intentar pre-seleccionar si el OCR atinó
        try {
          final matched = supermercados.firstWhere(
            (s) => s.nombre.toLowerCase() == widget.guessedSupermercado.toLowerCase(),
          );
          selectedSupermercadoId = matched.id;
          customSupermercadoNombre = matched.nombre;
          _applyMemoryToItems();
        } catch (_) {
          // No encontró coincidencia exacta, se queda como None
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingSupermercado = false;
      });
    }
  }

  void _applyMemoryToItems() {
    if (selectedSupermercadoId == null || dictionaryMemory.isEmpty) return;
    
    for (var item in items) {
      if (item.eansAsignados.isEmpty) {
        try {
           final memoryMatch = dictionaryMemory.firstWhere((mem) => 
               mem['supermercado_id'] == selectedSupermercadoId && 
               mem['ticket_nombre'] == item.nombre
           );
           
           if (memoryMatch['eans'] != null) {
              final eans = List<String>.from(memoryMatch['eans']);
              if (eans.isNotEmpty) {
                 item.eansAsignados.addAll(eans);
                 // Notificamos sutilmente al usuario de la magia en UI si quisiéramos
              }
           }
        } catch (_) {
           // Ningún match histórico encontrado
        }
      }
    }
  }

  void _showCreateSupermercadoDialog() {
    final TextEditingController _nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir Nuevo Supermercado'),
        content: TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre (ej: Alimerka)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              String newName = _nameController.text.trim();
              if (newName.isNotEmpty) {
                 Navigator.pop(context); // Cierra diálogo
                 setState(() => isLoadingSupermercado = true);
                 try {
                    // Creamos en backend (silencioso o no)
                    final newSuper = await api.createSupermercado(newName);
                    if (!mounted) return;
                    setState(() {
                       supermercados.add(newSuper);
                       supermercados.sort((a, b) => a.nombre.compareTo(b.nombre));
                       selectedSupermercadoId = newSuper.id;
                       customSupermercadoNombre = newSuper.nombre;
                       isLoadingSupermercado = false;
                    });
                 } catch (e) {
                    setState(() => isLoadingSupermercado = false);
                 }
              }
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  void _scanBarcodeForItem(int index) async {
    // Abrimos el lector de códigos de barras normal
    final String? scannedBarcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const ScannerScreen(),
      ),
    );

    if (scannedBarcode != null && scannedBarcode.isNotEmpty) {
      setState(() {
        items[index].eansAsignados.add(scannedBarcode);
      });
      // Vibrar ligeramente para confirmar
      HapticFeedback.lightImpact();
    }
  }

  void _editItem(int index) {
    final item = items[index];
    final nameController = TextEditingController(text: item.nombre);
    final quantityController = TextEditingController(text: item.cantidad.toString());
    final priceController = TextEditingController(
      text: item.precioUnitario.toStringAsFixed(2).replaceAll('.', ','),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar producto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad *',
                  helperText: 'Indica cuántas unidades guardarás en inventario',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio unitario *',
                  prefixText: '€ ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final newName = nameController.text.trim();
              final newQuantity = int.tryParse(quantityController.text.trim());
              final newPrice = double.tryParse(priceController.text.trim().replaceAll(',', '.'));

              if (newName.isEmpty) {
                _showSnackBar('El nombre no puede estar vacío.');
                return;
              }
              if (newQuantity == null || newQuantity <= 0) {
                _showSnackBar('La cantidad debe ser un número entero positivo.');
                return;
              }
              if (newPrice == null || newPrice <= 0) {
                _showSnackBar('El precio unitario debe ser mayor que cero.');
                return;
              }

              setState(() {
                items[index].nombre = newName.toUpperCase();
                items[index].cantidad = newQuantity;
                items[index].precioUnitario = newPrice;
                items[index].requiereRevisionCantidad = false;
              });
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _removeItem(int index) {
    final removedItem = items[index];

    setState(() {
      items.removeAt(index);
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Se ha quitado "${removedItem.nombre}" del ticket.'),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () {
              setState(() {
                items.insert(index.clamp(0, items.length), removedItem);
              });
            },
          ),
        ),
      );
  }

  void _finishMatching() {
    if (items.isEmpty) {
      _showSnackBar('Añade o conserva al menos un producto antes de guardar.');
      return;
    }

    final invalidIndex = items.indexWhere((item) => !_isValidItem(item));
    if (invalidIndex != -1) {
      final invalidItem = items[invalidIndex];
      if (invalidItem.requiereRevisionCantidad) {
        _showSnackBar('Revisa y confirma la cantidad de los productos vendidos por peso antes de guardar.');
      } else {
        _showSnackBar('Revisa nombre, cantidad y precio antes de guardar.');
      }
      _editItem(invalidIndex);
      return;
    }

    Navigator.of(context).pop(MatchmakerResult(
      items: items,
      supermercadoId: selectedSupermercadoId,
      supermercadoNombre: customSupermercadoNombre,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificar Ticket'),
        backgroundColor: colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            onPressed: _finishMatching,
            tooltip: 'Confirmar y Guardar',
          )
        ],
      ),
      body: Column(
        children: [
          // Cabecera explicativa
          Container(
            padding: const EdgeInsets.all(16),
            color: colorScheme.primaryContainer.withAlpha((255 * 0.3).round()),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Revisa el ticket antes de guardarlo: toca una fila para editar nombre, cantidad y precio; desliza para quitar productos que no quieras guardar.',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          
          // --- Selector de Supermercado ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.store, color: colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: isLoadingSupermercado
                    ? const Center(child: LinearProgressIndicator())
                    : DropdownButtonFormField<int?>(
                        value: selectedSupermercadoId,
                        decoration: InputDecoration(
                          labelText: 'Selecciona el Supermercado',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                           ...supermercados.map((s) => DropdownMenuItem<int?>(
                             value: s.id,
                             child: Text(s.nombre),
                           )),
                           const DropdownMenuItem<int?>(
                             value: -1, // Valor reservado
                             child: Text('+ Crear Nuevo...', style: TextStyle(color: Colors.blue)),
                           ),
                        ],
                        onChanged: (val) {
                          if (val == -1) {
                             _showCreateSupermercadoDialog();
                          } else {
                             setState(() {
                                selectedSupermercadoId = val;
                                if (val != null) {
                                  customSupermercadoNombre = supermercados.firstWhere((s) => s.id == val).nombre;
                                  _applyMemoryToItems();
                                }
                             });
                          }
                        },
                      ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Lista interactiva
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final isMatched = item.eansAsignados.isNotEmpty;
                final isValid = _isValidItem(item);
                final requiresQuantityReview = item.requiereRevisionCantidad;

                return Dismissible(
                  key: ValueKey('ticket-item-$index-${item.nombre}-${item.precioUnitario}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red.shade600,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline, color: Colors.white),
                        SizedBox(height: 4),
                        Text('Quitar', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  onDismissed: (_) => _removeItem(index),
                  child: ListTile(
                    onTap: () => _editItem(index),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: !isValid
                          ? Colors.orange.withOpacity(0.2)
                          : isMatched
                              ? Colors.green.withOpacity(0.2)
                              : colorScheme.surfaceContainerHighest,
                      child: Icon(
                        !isValid
                            ? Icons.warning_amber_rounded
                            : isMatched
                                ? Icons.check
                                : Icons.receipt_long,
                        color: !isValid
                            ? Colors.orange.shade700
                            : isMatched
                                ? Colors.green
                                : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(
                      item.nombre,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        if (requiresQuantityReview)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.orange.withOpacity(0.45)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.scale_rounded, size: 16, color: Colors.orange.shade700),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Producto vendido por peso: revisa la cantidad final',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: Colors.orange.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Text(
                              'Cantidad: ${item.cantidad}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: isValid ? colorScheme.onSurfaceVariant : Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Unitario: ${item.precioUnitario.toStringAsFixed(2)} €',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'Total: ${item.precioTotal.toStringAsFixed(2)} €',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          requiresQuantityReview
                              ? 'Toca para confirmar la cantidad · Desliza para quitar'
                              : 'Toca para editar · Desliza para quitar',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (isMatched)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '${item.eansAsignados.length} código(s) asociado(s)',
                              style: const TextStyle(color: Colors.green, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    trailing: OutlinedButton.icon(
                      onPressed: () => _scanBarcodeForItem(index),
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: Text(isMatched ? 'Escanear Más' : 'Asignar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isMatched ? colorScheme.onSurface : colorScheme.primary,
                        side: BorderSide(
                          color: isMatched ? colorScheme.outline : colorScheme.primary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton(
            onPressed: _finishMatching,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Guardar y Alimentar Inventario', style: TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
