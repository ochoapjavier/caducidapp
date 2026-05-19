// frontend/lib/screens/add_manual_item_screen.dart
// frontend/lib/screens/add_manual_item_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/models/ubicacion.dart';
import 'package:frontend/screens/scanner_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/date_scanner_screen.dart';
import 'package:intl/intl.dart';
import 'package:frontend/widgets/app_toast.dart';
import 'package:frontend/utils/date_parser.dart';

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
  int? _selectedProductId; // Nuevo campo para guardar el ID del producto seleccionado
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

  void _applyParsedDate(String value) {
    final parsed = parseExpirationDate(value);
    if (parsed != null) {
      setState(() {
        _selectedDate = parsed;
        _dateController.text = DateFormat('dd/MM/yyyy').format(parsed);
      });
    }
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
          AppToast.show(
            context,
            message: 'Error al buscar producto: ${e.toString()}',
            type: AppToastType.error,
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
        AppToast.show(
          context,
          message: 'Por favor, selecciona una fecha de caducidad.',
          type: AppToastType.info,
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
            AppToast.show(
              context,
              message: 'Error al actualizar el producto: ${e.toString()}',
              type: AppToastType.error,
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
        productId: _selectedProductId, // Pasamos el ID del producto seleccionado
        brand: _brandController.text.isNotEmpty ? _brandController.text : null,
        barcode:
            _barcodeController.text.isNotEmpty ? _barcodeController.text : null,
        ubicacionId: _selectedUbicacionId!,
        cantidad: int.parse(_quantityController.text),
        fechaCaducidad: _selectedDate!,
      );

      if (mounted) {
        AppToast.show(
          context,
          message: 'Producto añadido con éxito.',
          type: AppToastType.success,
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          message: 'Error: ${e.toString()}',
          type: AppToastType.error,
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
    Widget sectionCard({required Widget child}) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: child,
      );
    }
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
                        padding: EdgeInsets.only(bottom: 18.0),
                        
                      ),
                      sectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Producto',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return Autocomplete<Map<String, dynamic>>(
                                  optionsBuilder: (TextEditingValue textEditingValue) async {
                                    if (textEditingValue.text.length < 2) {
                                      return const Iterable<Map<String, dynamic>>.empty();
                                    }
                                    try {
                                      return await fetchMasterProducts(textEditingValue.text);
                                    } catch (e) {
                                      debugPrint('Error fetching suggestions: $e');
                                      return const Iterable<Map<String, dynamic>>.empty();
                                    }
                                  },
                                  displayStringForOption: (option) => option['nombre'],
                                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                    if (textEditingController.text != _productNameController.text) {
                                      textEditingController.text = _productNameController.text;
                                    }

                                    textEditingController.addListener(() {
                                      _productNameController.text = textEditingController.text;
                                    });

                                    return TextFormField(
                                      controller: textEditingController,
                                      focusNode: focusNode,
                                      decoration: const InputDecoration(
                                        labelText: 'Nombre del Producto *',
                                        suffixIcon: Icon(Icons.search),
                                      ),
                                      textCapitalization: TextCapitalization.sentences,
                                      validator: (value) => (value == null || value.trim().isEmpty)
                                          ? 'Introduce un nombre.'
                                          : null,
                                      onFieldSubmitted: (String value) {
                                        onFieldSubmitted();
                                      },
                                    );
                                  },
                                  onSelected: (Map<String, dynamic> selection) {
                                    setState(() {
                                      _productNameController.text = selection['nombre'];
                                      if (selection['marca'] != null) {
                                        _brandController.text = selection['marca'];
                                      }
                                      if (selection['barcode'] != null) {
                                        _barcodeController.text = selection['barcode'];
                                      }
                                      if (selection['id_producto'] != null) {
                                        _selectedProductId = selection['id_producto'];
                                      }
                                    });
                                  },
                                  optionsViewBuilder: (context, onSelected, options) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 4.0,
                                        child: SizedBox(
                                          width: constraints.maxWidth,
                                          child: ListView.builder(
                                            padding: EdgeInsets.zero,
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            itemBuilder: (BuildContext context, int index) {
                                              final option = options.elementAt(index);
                                              return ListTile(
                                                title: Text(option['nombre']),
                                                subtitle: option['marca'] != null ? Text(option['marca']) : null,
                                                onTap: () {
                                                  onSelected(option);
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _brandController,
                              decoration: const InputDecoration(
                                  labelText: 'Marca (Opcional)'),
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 12),
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      sectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Ubicación y cantidad',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
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
                            const SizedBox(height: 12),
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      sectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Caducidad',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _dateController,
                                    decoration: InputDecoration(
                                      hintText: 'Fecha de Caducidad *',
                                      prefixIcon: const Icon(Icons.calendar_today),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.date_range_outlined),
                                        onPressed: _presentDatePicker,
                                        tooltip: 'Elegir fecha',
                                      ),
                                    ),
                                    keyboardType: TextInputType.datetime,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9/]'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      final parsed = parseExpirationDate(value);
                                      if (parsed != null) {
                                        _selectedDate = parsed;
                                      }
                                    },
                                    onFieldSubmitted: (value) {
                                      _applyParsedDate(value);
                                    },
                                    onEditingComplete: () {
                                      _applyParsedDate(_dateController.text);
                                    },
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Por favor, selecciona una fecha.';
                                      }
                                      if (parseExpirationDate(value) == null) {
                                        return 'Formato no valido.';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.camera_alt_outlined, size: 30),
                                  onPressed: _scanDate,
                                  tooltip: 'Escanear fecha con la camara',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
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
