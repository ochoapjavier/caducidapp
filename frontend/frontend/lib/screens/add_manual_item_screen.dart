// frontend/lib/screens/add_manual_item_screen.dart
// frontend/lib/screens/add_manual_item_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/models/ubicacion.dart';
import 'package:frontend/screens/scanner_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/date_scanner_screen.dart';
import 'package:intl/intl.dart';

class AddManualItemScreen extends StatefulWidget {
  const AddManualItemScreen({super.key});

  @override
  State<AddManualItemScreen> createState() => _AddManualItemScreenState();
}

class _AddManualItemScreenState extends State<AddManualItemScreen> {
  // Form key
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _productNameController = TextEditingController();
  final _brandController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _dateController = TextEditingController();

  // State
  int? _selectedUbicacionId;
  DateTime? _selectedDate;
  String? _originalProductName;
  String? _originalBrand;
  var _isLoading = false;
  late Future<List<Ubicacion>> _ubicacionesFuture;

  @override
  void initState() {
    super.initState();
    _ubicacionesFuture = fetchUbicaciones();
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _quantityController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _incrementQuantity() {
    final currentQuantity = int.tryParse(_quantityController.text) ?? 0;
    setState(() {
      _quantityController.text = (currentQuantity + 1).toString();
    });
  }

  void _decrementQuantity() {
    final currentQuantity = int.tryParse(_quantityController.text) ?? 0;
    if (currentQuantity > 1) {
      setState(() {
        _quantityController.text = (currentQuantity - 1).toString();
      });
    }
  }

  void _onQuantityChanged() {
    setState(() {});
  }

  void _presentDatePicker() {
    showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    ).then((pickedDate) {
      if (pickedDate == null) return;
      setState(() {
        _selectedDate = pickedDate;
        _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
      });
    });
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (ctx) => const ScannerScreen()),
    );

    if (barcode != null && barcode.isNotEmpty) {
      setState(() {
        _barcodeController.text = barcode;
        _originalProductName = null;
        _originalBrand = null;
      });

      // Loading overlay while fetching catalog info
      showDialog(
        context: context,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      try {
        final productData = await fetchProductFromCatalog(barcode);
        if (mounted) {
          Navigator.of(context).pop();
        }

        if (productData != null) {
          setState(() {
            _productNameController.text = productData['nombre'];
            _brandController.text = productData['marca'] ?? '';
            _originalProductName = productData['nombre'];
            _originalBrand = productData['marca'];
          });
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al buscar producto: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _scanDate() async {
    final scannedDate = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(builder: (ctx) => const DateScannerScreen()),
    );
    if (scannedDate != null) {
      setState(() {
        _selectedDate = scannedDate;
        _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
      });
    }
  }

  Future<void> _submitForm() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid || _selectedDate == null) {
      if (_selectedDate == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, selecciona una fecha de caducidad.')),
        );
      }
      return;
    }

    _formKey.currentState!.save();
    setState(() {
      _isLoading = true;
    });

    // Confirm update to catalog if user changed auto-filled data
    final bool productWasFound = _originalProductName != null;
    final bool nameHasChanged =
        productWasFound && _productNameController.text != _originalProductName;
    final bool brandHasChanged =
        productWasFound && _brandController.text != (_originalBrand ?? '');

    if (productWasFound && (nameHasChanged || brandHasChanged)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Actualizar Producto Maestro'),
          content: const Text(
              'Has modificado los datos de un producto existente. ¿Quieres guardar estos cambios para futuras referencias de este código de barras?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sí, Actualizar'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          await updateProductInCatalog(
            barcode: _barcodeController.text,
            name: _productNameController.text,
            brand: _brandController.text.isNotEmpty
                ? _brandController.text
                : null,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Error al actualizar el producto: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
      }
    }

    try {
      await addManualStockItem(
        productName: _productNameController.text,
        brand: _brandController.text.isNotEmpty ? _brandController.text : null,
        barcode:
            _barcodeController.text.isNotEmpty ? _barcodeController.text : null,
        ubicacionId: _selectedUbicacionId!,
        cantidad: int.parse(_quantityController.text),
        fechaCaducidad: _selectedDate!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto añadido con éxito.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Estilo unificado para Acción Primaria (igual que versión escaneada)
    final ButtonStyle primaryActionStyle = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir Producto Manualmente'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 24.0),
                        child: Text(
                          'Los campos marcados con * son obligatorios.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      TextFormField(
                        controller: _productNameController,
                        decoration: const InputDecoration(
                            labelText: 'Nombre del Producto *'),
                        textCapitalization: TextCapitalization.sentences,
                        validator: (value) => (value == null ||
                                value.trim().isEmpty)
                            ? 'Introduce un nombre.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _brandController,
                        decoration: const InputDecoration(
                            labelText: 'Marca (Opcional)'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _barcodeController,
                        decoration: InputDecoration(
                          labelText: 'Código de Barras (EAN) (Opcional)',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            onPressed: _scanBarcode,
                            tooltip: 'Escanear código de barras',
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<List<Ubicacion>>(
                        future: _ubicacionesFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError ||
                              !snapshot.hasData ||
                              snapshot.data!.isEmpty) {
                            return const Text(
                                'No se pudieron cargar las ubicaciones. Añade una en la pestaña "Ubicaciones".');
                          }

                          return DropdownButtonFormField<int>(
                            value: _selectedUbicacionId,
                            decoration: const InputDecoration(
                                labelText: 'Ubicación *'),
                            items: snapshot.data!.map((ubicacion) {
                              return DropdownMenuItem(
                                value: ubicacion.id,
                                child: Text(ubicacion.nombre),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedUbicacionId = value;
                              });
                            },
                            validator: (value) => (value == null)
                                ? 'Selecciona una ubicación.'
                                : null,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _quantityController,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: 'Cantidad *',
                          prefixIcon: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed:
                                (int.tryParse(_quantityController.text) ?? 1) > 1
                                    ? _decrementQuantity
                                    : null,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: _incrementQuantity,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) => _onQuantityChanged(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Introduce una cantidad.';
                          }
                          if (int.tryParse(value) == null ||
                              int.parse(value) <= 0) {
                            return 'La cantidad debe ser un número positivo.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _dateController,
                              decoration: const InputDecoration(
                                hintText: 'Fecha de Caducidad *',
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              readOnly: true,
                              onTap: _presentDatePicker,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, selecciona una fecha.';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.camera_alt_outlined, size: 30),
                            onPressed: _scanDate,
                            tooltip: 'Escanear fecha con la cámara',
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : FilledButton.icon(
                              onPressed: _submitForm,
                              icon: const Icon(Icons.save),
                              label: const Text('Guardar Producto'),
                              style: primaryActionStyle,
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
