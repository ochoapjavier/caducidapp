// frontend/lib/screens/add_manual_item_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/models/ubicacion.dart';
import 'package:frontend/screens/scanner_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/date_scanner_screen.dart';
import 'package:intl/intl.dart'; // Importamos el paquete intl

class AddManualItemScreen extends StatefulWidget {
  const AddManualItemScreen({super.key});

  @override
  State<AddManualItemScreen> createState() => _AddManualItemScreenState();
}

class _AddManualItemScreenState extends State<AddManualItemScreen> {
  // Clave para nuestro formulario, para validación y guardado.
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos de texto.
  final _productNameController = TextEditingController();
  final _brandController = TextEditingController(); // <-- NUEVO: Controlador para la marca
  final _barcodeController = TextEditingController(); // <-- NUEVO: Controlador para el EAN
  final _quantityController = TextEditingController(text: '1'); // Valor por defecto
  final _dateController = TextEditingController(); // Controlador para la fecha

  // Variables para almacenar los valores del formulario.
  int? _selectedUbicacionId;
  DateTime? _selectedDate;
  // NUEVO: Guardamos el nombre original del producto si se carga desde la BBDD
  String? _originalProductName;
  String? _originalBrand;
  
  // Estado para manejar la carga de la API y el Future para las ubicaciones.
  var _isLoading = false;
  late Future<List<Ubicacion>> _ubicacionesFuture;

  @override
  void initState() {
    super.initState();
    // Al iniciar la pantalla, cargamos las ubicaciones del usuario.
    _ubicacionesFuture = fetchUbicaciones();
  }

  @override
  void dispose() {
    // Limpiamos los controladores cuando la pantalla se destruye.
    _productNameController.dispose();
    _brandController.dispose(); // <-- NUEVO: Limpiar controlador de marca
    _barcodeController.dispose(); // <-- NUEVO: Limpiar controlador de EAN
    _quantityController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  /// Muestra el selector de fecha y actualiza el estado.
  void _presentDatePicker() {
    showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      // El locale se toma automáticamente de la configuración en main.dart
    ).then((pickedDate) {
      if (pickedDate == null) {
        return;
      }
      setState(() {
        _selectedDate = pickedDate;
        // Usamos intl para formatear la fecha a dd/MM/yyyy
        _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
      });
    });
  }

  /// NUEVO: Abre el escáner de códigos de barras y rellena el campo EAN.
  void _scanBarcode() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (ctx) => const ScannerScreen()),
    );

    if (barcode != null && barcode.isNotEmpty) {
      setState(() {
        // Primero, ponemos el EAN en el campo
        _barcodeController.text = barcode;
        // Reseteamos el nombre original para una nueva búsqueda
        _originalProductName = null;
        _originalBrand = null;
      });

      // Mostramos un spinner mientras buscamos
      showDialog(context: context, builder: (ctx) => const Center(child: CircularProgressIndicator()), barrierDismissible: false);

      try {
        // Buscamos el producto en nuestro catálogo
        final productData = await fetchProductFromCatalog(barcode);
        Navigator.of(context).pop(); // Cerramos el spinner

        if (productData != null) {
          // ¡Producto encontrado! Rellenamos los campos.
          setState(() {
            _productNameController.text = productData['nombre'];
            _brandController.text = productData['marca'] ?? '';
            _originalProductName = productData['nombre']; // Guardamos el original
            _originalBrand = productData['marca']; // Guardamos el original
          });
        }
      } catch (e) {
        Navigator.of(context).pop(); // Cerramos el spinner en caso de error
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al buscar producto: ${e.toString()}')));
      }
    }
  }


  /// Valida y envía el formulario al backend.
  void _submitForm() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid || _selectedDate == null) {
      // Si la fecha no está seleccionada, muestra un mensaje.
      if (_selectedDate == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, selecciona una fecha de caducidad.')),
        );
      }
      return;
    }

    _formKey.currentState!.save();

    setState(() { _isLoading = true; });

    // --- NUEVA LÓGICA DE CONFIRMACIÓN DE ACTUALIZACIÓN ---
    final bool hasBarcode = _barcodeController.text.isNotEmpty;
    final bool nameHasChanged = _originalProductName != null && _productNameController.text != _originalProductName;
    final bool brandHasChanged = _originalBrand != _brandController.text; // Compara incluso si son null

    if (hasBarcode && (nameHasChanged || brandHasChanged)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Actualizar Producto Maestro'),
          content: const Text('Has modificado los datos de un producto existente. ¿Quieres guardar estos cambios para futuras referencias de este código de barras?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sí, Actualizar')),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          await updateProductInCatalog(
            barcode: _barcodeController.text,
            name: _productNameController.text,
            brand: _brandController.text.isNotEmpty ? _brandController.text : null,
          );
        } catch (e) {
          // Si falla la actualización, informamos y detenemos el proceso.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar el producto: ${e.toString()}'), backgroundColor: Colors.red));
            setState(() { _isLoading = false; });
          }
          return;
        }
      }
    }

    try {
      await addManualStockItem(
        productName: _productNameController.text,
        brand: _brandController.text.isNotEmpty ? _brandController.text : null, // <-- NUEVO: Pasamos la marca
        barcode: _barcodeController.text.isNotEmpty ? _barcodeController.text : null, // <-- NUEVO: Pasamos el EAN
        ubicacionId: _selectedUbicacionId!,
        cantidad: int.parse(_quantityController.text),
        fechaCaducidad: _selectedDate!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto añadido con éxito.'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(); // Vuelve a la pantalla anterior.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _scanDate() async {
    final scannedDate = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(builder: (ctx) => const DateScannerScreen()),
    );
    if (scannedDate != null) {
      setState(() {
        _selectedDate = scannedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir Producto Manualmente'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView( // Usamos ListView para evitar desbordamientos en pantallas pequeñas.
            children: [
              // --- NUEVO: Nota sobre campos obligatorios ---
              const Padding(
                padding: EdgeInsets.only(bottom: 24.0),
                child: Text(
                  'Los campos marcados con * son obligatorios.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),

              // --- CAMPO NOMBRE DEL PRODUCTO ---
              TextFormField(
                controller: _productNameController,
                decoration: const InputDecoration(labelText: 'Nombre del Producto *'),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Introduce un nombre.' : null,
              ),
              const SizedBox(height: 16),

              // --- NUEVO: CAMPO MARCA ---
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(labelText: 'Marca (Opcional)'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // --- NUEVO: CAMPO CÓDIGO DE BARRAS (EAN) ---
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

              // --- DROPDOWN DE UBICACIONES ---
              FutureBuilder<List<Ubicacion>>(
                future: _ubicacionesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('No se pudieron cargar las ubicaciones. Añade una en la pestaña "Ubicaciones".');
                  }
                  
                  return DropdownButtonFormField<int>(
                    value: _selectedUbicacionId,
                    decoration: const InputDecoration(labelText: 'Ubicación *'),
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
                    validator: (value) => (value == null) ? 'Selecciona una ubicación.' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              // --- CAMPO CANTIDAD ---
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Cantidad *'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Introduce una cantidad.';
                  if (int.tryParse(value) == null || int.parse(value) <= 0) return 'La cantidad debe ser un número positivo.';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // --- SELECTOR DE FECHA ---
              Row(
                children: [
                  Expanded(child: TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Fecha de Caducidad *',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true, // Para forzar el uso del picker
                    onTap: _presentDatePicker,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, selecciona una fecha.';
                      }
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
                ElevatedButton.icon(
                  onPressed: _submitForm,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar Producto'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
