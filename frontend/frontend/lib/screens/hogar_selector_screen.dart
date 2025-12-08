// frontend/lib/screens/hogar_selector_screen.dart

import 'package:flutter/material.dart';
import '../models/hogar.dart';
import '../services/api_service.dart';
import '../services/hogar_service.dart';
import '../widgets/error_view.dart';

class HogarSelectorScreen extends StatefulWidget {
  const HogarSelectorScreen({Key? key}) : super(key: key);

  @override
  State<HogarSelectorScreen> createState() => _HogarSelectorScreenState();
}

class _HogarSelectorScreenState extends State<HogarSelectorScreen> {
  final HogarService _hogarService = HogarService();
  List<Hogar> _hogares = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHogares();
  }

  Future<void> _loadHogares() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final hogares = await fetchHogares();
      setState(() {
        _hogares = hogares;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _seleccionarHogar(Hogar hogar) async {
    await _hogarService.setHogarActivo(hogar.idHogar);
    if (mounted) {
      // Volver al root para recargar HogarAwareMainScreen
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  void _mostrarDialogoCrearHogar() {
    final nombreController = TextEditingController();
    String iconoSeleccionado = 'home';
    final parentContext = context;
    
    showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Crear Nuevo Hogar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del hogar',
                  hintText: 'Ej: Casa Madrid, Casa de Playa',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('Selecciona un icono:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _IconOption(
                    icon: Icons.home,
                    value: 'home',
                    selected: iconoSeleccionado == 'home',
                    onTap: () => setDialogState(() => iconoSeleccionado = 'home'),
                  ),
                  _IconOption(
                    icon: Icons.apartment,
                    value: 'apartment',
                    selected: iconoSeleccionado == 'apartment',
                    onTap: () => setDialogState(() => iconoSeleccionado = 'apartment'),
                  ),
                  _IconOption(
                    icon: Icons.cabin,
                    value: 'cabin',
                    selected: iconoSeleccionado == 'cabin',
                    onTap: () => setDialogState(() => iconoSeleccionado = 'cabin'),
                  ),
                  _IconOption(
                    icon: Icons.business,
                    value: 'office',
                    selected: iconoSeleccionado == 'office',
                    onTap: () => setDialogState(() => iconoSeleccionado = 'office'),
                  ),
                  _IconOption(
                    icon: Icons.cottage,
                    value: 'cottage',
                    selected: iconoSeleccionado == 'cottage',
                    onTap: () => setDialogState(() => iconoSeleccionado = 'cottage'),
                  ),
                  _IconOption(
                    icon: Icons.landscape,
                    value: 'mountain',
                    selected: iconoSeleccionado == 'mountain',
                    onTap: () => setDialogState(() => iconoSeleccionado = 'mountain'),
                  ),
                  _IconOption(
                    icon: Icons.beach_access,
                    value: 'beach',
                    selected: iconoSeleccionado == 'beach',
                    onTap: () => setDialogState(() => iconoSeleccionado = 'beach'),
                  ),
                  _IconOption(
                    icon: Icons.sailing,
                    value: 'sea',
                    selected: iconoSeleccionado == 'sea',
                    onTap: () => setDialogState(() => iconoSeleccionado = 'sea'),
                  ),
                  _IconOption(
                    icon: Icons.ac_unit,
                    value: 'snow',
                    selected: iconoSeleccionado == 'snow',
                    onTap: () => setDialogState(() => iconoSeleccionado = 'snow'),
                  ),
                  _IconOption(
                    icon: Icons.forest,
                    value: 'forest',
                    selected: iconoSeleccionado == 'forest',
                    onTap: () => setDialogState(() => iconoSeleccionado = 'forest'),
                  ),
                  _IconOption(
                    icon: Icons.park,
                    value: 'park',
                    selected: iconoSeleccionado == 'park',
                    onTap: () => setDialogState(() => iconoSeleccionado = 'park'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final nombre = nombreController.text.trim();
                if (nombre.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor ingresa un nombre')),
                  );
                  return;
                }
                // Cerrar diálogo de creación
                Navigator.pop(dialogContext);

                // Mostrar indicador de carga sobre el parentContext
                showDialog(
                  context: parentContext,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  final nuevoHogar = await createHogar(nombre, icono: iconoSeleccionado);
                  await _hogarService.setHogarActivo(nuevoHogar.idHogar);
                  if (mounted) {
                    Navigator.of(parentContext).pop(); // Cerrar loading
                    Navigator.of(parentContext).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(parentContext).pop(); // Cerrar loading
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoUnirseHogar() {
    final codigoController = TextEditingController();
    final parentContext = context;
    
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unirse a un Hogar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codigoController,
              decoration: const InputDecoration(
                labelText: 'Código de invitación',
                hintText: 'Ej: ABC12345',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'Pide el código al administrador del hogar',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final codigo = codigoController.text.trim().toUpperCase();
              if (codigo.isEmpty) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text('Por favor ingresa el código')),
                );
                return;
              }
              
              // Cerrar diálogo de introducir código
              Navigator.pop(dialogContext);
              
              // Mostrar indicador de carga sobre parentContext
              showDialog(
                context: parentContext,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );
              
              try {
                await unirseAHogar(codigo);
                await _loadHogares(); // Recargar lista
                if (mounted) {
                  Navigator.of(parentContext).pop(); // Cerrar loading
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text('¡Te has unido al hogar!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(parentContext).pop(); // Cerrar loading
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Unirse'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determinar si podemos volver atrás (si hay una ruta previa)
    final canPop = Navigator.of(context).canPop();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Hogar'),
        automaticallyImplyLeading: canPop, // Mostrar botón solo si hay ruta previa
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(
                  error: _error!,
                  onRetry: _loadHogares,
                )
              : _hogares.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.home_outlined,
                              size: 80,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No tienes ningún hogar',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Crea tu primer hogar o únete a uno existente',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 32),
                            FilledButton.icon(
                              onPressed: _mostrarDialogoCrearHogar,
                              icon: const Icon(Icons.add),
                              label: const Text('Crear Mi Hogar'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _mostrarDialogoUnirseHogar,
                              icon: const Icon(Icons.group_add),
                              label: const Text('Unirse con Código'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Selecciona el hogar que deseas gestionar',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _hogares.length,
                            itemBuilder: (context, index) {
                              final hogar = _hogares[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    radius: 28,
                                    child: Icon(_getIcono(hogar.icono), size: 28),
                                  ),
                                  title: Text(
                                    hogar.nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.people, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text('${hogar.totalMiembros} miembro(s)'),
                                        const SizedBox(width: 12),
                                        _RolChip(rol: hogar.rol),
                                      ],
                                    ),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                  onTap: () => _seleccionarHogar(hogar),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
      floatingActionButton: _hogares.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.add),
                          title: const Text('Crear nuevo hogar'),
                          onTap: () {
                            Navigator.pop(context);
                            _mostrarDialogoCrearHogar();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.group_add),
                          title: const Text('Unirse con código'),
                          onTap: () {
                            Navigator.pop(context);
                            _mostrarDialogoUnirseHogar();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Nuevo'),
            )
          : null,
    );
  }

  IconData _getIcono(String icono) {
    switch (icono) {
      case 'apartment':
        return Icons.apartment;
      case 'cabin':
        return Icons.cabin;
      case 'office':
        return Icons.business;
      case 'cottage':
        return Icons.cottage;
      case 'mountain':
        return Icons.landscape;
      case 'beach':
        return Icons.beach_access;
      case 'sea':
        return Icons.sailing;
      case 'snow':
        return Icons.ac_unit;
      case 'forest':
        return Icons.forest;
      case 'park':
        return Icons.park;
      default:
        return Icons.home;
    }
  }
}

// Widget auxiliar para seleccionar iconos
class _IconOption extends StatelessWidget {
  final IconData icon;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _IconOption({
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : null,
        ),
        child: Icon(
          icon,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade600,
        ),
      ),
    );
  }
}

// Widget auxiliar para mostrar el rol
class _RolChip extends StatelessWidget {
  final String rol;

  const _RolChip({required this.rol});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (rol) {
      case 'admin':
        color = Colors.purple;
        text = 'Admin';
        break;
      case 'miembro':
        color = Colors.blue;
        text = 'Miembro';
        break;
      case 'invitado':
        color = Colors.grey;
        text = 'Invitado';
        break;
      default:
        color = Colors.grey;
        text = rol;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
