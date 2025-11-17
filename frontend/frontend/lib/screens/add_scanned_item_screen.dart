// frontend/lib/screens/add_scanned_item_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/models/ubicacion.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/date_scanner_screen.dart';
import 'package:intl/intl.dart';

class AddScannedItemScreen extends StatefulWidget {
  final String barcode;
  final String initialProductName;
  final String? initialBrand;
  final String? initialImageUrl; // <-- NUEVO: Recibimos la URL de la imagen
  final bool isFromLocalDB; // Para saber si debemos ofrecer la actualización

  const AddScannedItemScreen({
    super.key,
    required this.barcode,
    required this.initialProductName,
    this.initialBrand,
    this.initialImageUrl,
    required this.isFromLocalDB,
  });

  @override
  State<AddScannedItemScreen> createState() => _AddScannedItemScreenState();
}

class _AddScannedItemScreenState extends State<AddScannedItemScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos editables
  late final TextEditingController _productNameController;
  late final TextEditingController _brandController;
  final _quantityController = TextEditingController(text: '1');
  final _dateController = TextEditingController();

  int? _selectedUbicacionId;
  DateTime? _selectedDate;
  var _isLoading = false;
  late Future<List<Ubicacion>> _ubicacionesFuture;

  // Guardamos los datos originales para compararlos al enviar
  late String _originalProductName;
  late String? _originalBrand;

  @override
  void initState() {
    super.initState();
    // Inicializamos los controladores con los datos recibidos
    _productNameController = TextEditingController(text: widget.initialProductName);
    _brandController = TextEditingController(text: widget.initialBrand ?? '');

    // Guardamos los datos originales si vienen de nuestra BBDD
    if (widget.isFromLocalDB) {
      _originalProductName = widget.initialProductName;
      _originalBrand = widget.initialBrand;
    }

    _ubicacionesFuture = fetchUbicaciones();
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _brandController.dispose();
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

  void _presentDatePicker() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
      });
    }
  }

  void _scanDate() async {
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

  void _submitForm() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _selectedDate == null) {
      if (_selectedDate == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Por favor, selecciona una fecha de caducidad.')),
        );
      }
      return;
    }
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    // --- LÓGICA DE CONFIRMACIÓN DE ACTUALIZACIÓN ---
    final bool nameHasChanged = widget.isFromLocalDB && _productNameController.text != _originalProductName;
    final bool brandHasChanged = widget.isFromLocalDB && _brandController.text != (_originalBrand ?? '');

    if (nameHasChanged || brandHasChanged) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Actualizar Producto Maestro'),
          content: const Text(
              'Has modificado los datos de un producto existente. ¿Quieres guardar estos cambios para futuras referencias de este código de barras?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('No')),
            ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sí, Actualizar')),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          await updateProductInCatalog(
            barcode: widget.barcode,
            name: _productNameController.text,
            brand: _brandController.text.isNotEmpty ? _brandController.text : null,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Error al actualizar el producto: ${e.toString()}'),
                backgroundColor: Colors.red));
            setState(() => _isLoading = false);
          }
          return;
        }
      }
    }

    try {
      // Usamos la misma función que el alta manual, ya que ahora los datos son equivalentes
      await addManualStockItem(
        barcode: widget.barcode,
        productName: _productNameController.text,
        brand: _brandController.text.isNotEmpty ? _brandController.text : null,
        imageUrl: widget.initialImageUrl, // <-- NUEVO: Pasamos la URL al guardar
        ubicacionId: _selectedUbicacionId!,
        cantidad: int.parse(_quantityController.text),
        fechaCaducidad: _selectedDate!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Producto añadido con éxito.'),
              backgroundColor: Colors.green),
        );
        // Cierra la pantalla de confirmación y la del escáner, volviendo a la principal.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Estilo unificado para Acción Primaria (igual en manual y escaneado)
    final ButtonStyle primaryActionStyle = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Añadir Producto Escaneado')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // --- CAMPO EAN (NO EDITABLE) ---
              TextFormField(
                initialValue: widget.barcode,
                decoration: const InputDecoration(
                  labelText: 'Código de Barras (EAN)',
                  filled: true, // Fondo gris para indicar que no es editable
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              // --- CAMPOS EDITABLES PARA NOMBRE Y MARCA ---
              TextFormField(
                controller: _productNameController,
                decoration: const InputDecoration(labelText: 'Nombre del Producto *'),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Introduce un nombre.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(labelText: 'Marca (Opcional)'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // --- DROPDOWN DE UBICACIONES ---
              FutureBuilder<List<Ubicacion>>(
                future: _ubicacionesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return const Text('No se pudieron cargar las ubicaciones.');
                  }
                  return DropdownButtonFormField<int>(
                    value: _selectedUbicacionId,
                    decoration: const InputDecoration(labelText: 'Ubicación *'),
                    items: snapshot.data!.map((ubicacion) => DropdownMenuItem(value: ubicacion.id, child: Text(ubicacion.nombre))).toList(),
                    onChanged: (value) => setState(() => _selectedUbicacionId = value),
                    validator: (value) => (value == null) ? 'Selecciona una ubicación.' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              // --- CAMPO CANTIDAD ---
              TextFormField(
                controller: _quantityController,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'Cantidad *',
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: (int.tryParse(_quantityController.text) ?? 1) > 1 ? _decrementQuantity : null,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _incrementQuantity,
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) => _onQuantityChanged(),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Introduce una cantidad.';
                  if (int.tryParse(value) == null || int.parse(value) <= 0)
                    return 'La cantidad debe ser un número positivo.';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      hintText: 'Fecha de Caducidad *',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: _presentDatePicker,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Selecciona una fecha.';
                      return null;
                    },
                  )),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, size: 30),
                    onPressed: _scanDate,
                    tooltip: 'Escanear fecha con la cámara',
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // --- BOTÓN DE GUARDAR ---
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                FilledButton.icon(
                  onPressed: _submitForm,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar Producto'),
                  style: primaryActionStyle,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
