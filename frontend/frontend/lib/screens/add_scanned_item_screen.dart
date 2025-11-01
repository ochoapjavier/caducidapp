// frontend/lib/screens/add_scanned_item_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/models/ubicacion.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/date_scanner_screen.dart';
import 'package:intl/intl.dart'; // Importamos el paquete intl

class AddScannedItemScreen extends StatefulWidget {
  final String barcode;
  final String productName;
  final String? brand;

  const AddScannedItemScreen({
    super.key,
    required this.barcode,
    required this.productName,
    this.brand,
  });

  @override
  State<AddScannedItemScreen> createState() => _AddScannedItemScreenState();
}

class _AddScannedItemScreenState extends State<AddScannedItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  final _dateController = TextEditingController(); // Controlador para la fecha

  int? _selectedUbicacionId;
  DateTime? _selectedDate;
  var _isLoading = false;
  late Future<List<Ubicacion>> _ubicacionesFuture;

  @override
  void initState() {
    super.initState();
    _ubicacionesFuture = fetchUbicaciones();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _presentDatePicker() {
    showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    ).then((pickedDate) {
      if (pickedDate == null) {
        return;
      }
      setState(() {
        _selectedDate = pickedDate;
        _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
      });
    });
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
          const SnackBar(content: Text('Por favor, selecciona una fecha de caducidad.')),
        );
      }
      return;
    }
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      await addScannedStockItem(
        barcode: widget.barcode,
        productName: widget.productName,
        brand: widget.brand,
        ubicacionId: _selectedUbicacionId!,
        cantidad: int.parse(_quantityController.text),
        fechaCaducidad: _selectedDate!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto añadido con éxito.'), backgroundColor: Colors.green),
        );
        // Cierra la pantalla de confirmación y la del escáner, volviendo a la principal.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar Producto'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Mostramos la información del producto (no editable)
              ListTile(
                leading: const Icon(Icons.label_important_outline),
                title: Text(widget.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text(widget.brand ?? 'Marca no disponible'),
              ),
              const Divider(height: 32),

              // El resto del formulario es igual al manual
              FutureBuilder<List<Ubicacion>>(
                future: _ubicacionesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('No se pudieron cargar las ubicaciones.');
                  }
                  return DropdownButtonFormField<int>(
                    value: _selectedUbicacionId,
                    decoration: const InputDecoration(labelText: 'Ubicación'),
                    items: snapshot.data!.map((ubicacion) => DropdownMenuItem(value: ubicacion.id, child: Text(ubicacion.nombre))).toList(),
                    onChanged: (value) => setState(() => _selectedUbicacionId = value),
                    validator: (value) => (value == null) ? 'Selecciona una ubicación.' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Cantidad'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Introduce una cantidad.';
                  if (int.tryParse(value) == null || int.parse(value) <= 0) return 'La cantidad debe ser un número positivo.';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Fecha de Caducidad',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
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
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton.icon(
                  onPressed: _submitForm,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar Producto'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
