// frontend/lib/screens/add_manual_item_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/models/ubicacion.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/date_scanner_screen.dart';

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
  final _quantityController = TextEditingController(text: '1'); // Valor por defecto

  // Variables para almacenar los valores del formulario.
  int? _selectedUbicacionId;
  DateTime? _selectedDate;
  
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
    _quantityController.dispose();
    super.dispose();
  }

  /// Muestra el selector de fecha y actualiza el estado.
  void _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now, // No se pueden seleccionar fechas pasadas.
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
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

    try {
      await addManualStockItem(
        productName: _productNameController.text,
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
              // --- CAMPO NOMBRE DEL PRODUCTO ---
              TextFormField(
                controller: _productNameController,
                decoration: const InputDecoration(labelText: 'Nombre del Producto'),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Introduce un nombre.' : null,
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
                    decoration: const InputDecoration(labelText: 'Ubicación'),
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
                decoration: const InputDecoration(labelText: 'Cantidad'),
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
                  Expanded(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
                      leading: const Icon(Icons.calendar_today),
                      title: Text(
                        _selectedDate == null
                            ? 'Seleccionar Fecha de Caducidad'
                            : 'Caduca: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                      ),
                      onTap: _pickDate,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
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
