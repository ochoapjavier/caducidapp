// frontend/lib/screens/hogar_detalle_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/hogar.dart';
import '../services/api_service.dart';

class HogarDetalleScreen extends StatefulWidget {
  final int hogarId;
  
  const HogarDetalleScreen({Key? key, required this.hogarId}) : super(key: key);

  @override
  State<HogarDetalleScreen> createState() => _HogarDetalleScreenState();
}

class _HogarDetalleScreenState extends State<HogarDetalleScreen> {
  HogarDetalle? _hogarDetalle;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetalles();
  }

  Future<void> _loadDetalles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detalle = await fetchHogarDetalle(widget.hogarId);
      setState(() {
        _hogarDetalle = detalle;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _copiarCodigo() {
    if (_hogarDetalle != null) {
      Clipboard.setData(ClipboardData(text: _hogarDetalle!.codigoInvitacion));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código copiado al portapapeles'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _regenerarCodigo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Regenerar código?'),
        content: const Text(
          'El código actual dejará de funcionar. Los miembros actuales no se verán afectados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final nuevoCodigo = await regenerarCodigoInvitacion(widget.hogarId);
      setState(() {
        _hogarDetalle = HogarDetalle(
          idHogar: _hogarDetalle!.idHogar,
          nombre: _hogarDetalle!.nombre,
          icono: _hogarDetalle!.icono,
          codigoInvitacion: nuevoCodigo,
          miembros: _hogarDetalle!.miembros,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código regenerado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _compartirCodigo() {
    if (_hogarDetalle != null) {
      final mensaje = 'Únete a mi hogar "${_hogarDetalle!.nombre}" en CaducidApp!\n\n'
          'Código de invitación: ${_hogarDetalle!.codigoInvitacion}\n\n'
          'Abre la app y usa este código para unirte.';
      
      // Copiar al portapapeles
      Clipboard.setData(ClipboardData(text: mensaje));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mensaje copiado. Compártelo por WhatsApp, email, etc.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _mostrarDialogoEditarHogar() {
    if (_hogarDetalle == null) return;
    
    final nombreController = TextEditingController(text: _hogarDetalle!.nombre);
    String iconoSeleccionado = _hogarDetalle!.icono;
    final parentContext = context;
    
    showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Editar Hogar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del hogar',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Icono:'),
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
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(content: Text('El nombre no puede estar vacío')),
                  );
                  return;
                }
                
                // Cerrar diálogo de edición
                Navigator.pop(dialogContext);
                
                // Mostrar loading sobre parentContext
                showDialog(
                  context: parentContext,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );
                
                try {
                  await updateHogar(widget.hogarId, nombre, iconoSeleccionado);
                  if (mounted) {
                    Navigator.of(parentContext).pop(); // Cerrar loading
                    await _loadDetalles(); // Recargar detalles
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(
                        content: Text('Hogar actualizado'),
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
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarMiembro(Miembro miembro) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar miembro?'),
        content: Text('¿Estás seguro de que deseas eliminar a ${miembro.apodo} del hogar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await expulsarMiembro(widget.hogarId, miembro.userId);
      if (mounted) {
        await _loadDetalles(); // Recargar lista de miembros
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${miembro.apodo} eliminado del hogar'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarDialogoEditarMiApodo(Miembro miembro) {
    final parentContext = context;
    final controller = TextEditingController(text: miembro.apodo);

    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar mi nombre'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Apodo'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final nuevo = controller.text.trim();
              if (nuevo.isEmpty) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text('El apodo no puede estar vacío')),
                );
                return;
              }

              // Cerrar diálogo
              Navigator.pop(dialogContext);

              // Mostrar indicador de carga
              showDialog(
                context: parentContext,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              try {
                await updateMyApodo(widget.hogarId, nuevo);
                if (mounted) {
                  Navigator.of(parentContext).pop(); // cerrar loading
                  await _loadDetalles();
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(content: Text('Apodo actualizado'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(parentContext).pop();
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Verificar si el usuario actual es administrador
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    Miembro? miembroActual;
    try {
      miembroActual = _hogarDetalle?.miembros.firstWhere(
        (m) => m.userId == currentUserId,
      );
    } catch (e) {
      miembroActual = null;
    }
    final esAdmin = miembroActual?.rol == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(_hogarDetalle?.nombre ?? 'Detalles del Hogar'),
        actions: [
          // Botón de editar (solo para administradores)
          if (esAdmin && _hogarDetalle != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Editar hogar',
              onPressed: _mostrarDialogoEditarHogar,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: $_error'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadDetalles,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDetalles,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icono y nombre del hogar
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                child: Icon(_getIcono(_hogarDetalle!.icono), size: 40),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _hogarDetalle!.nombre,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Código de invitación
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.vpn_key, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Código de Invitación',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _hogarDetalle!.codigoInvitacion,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _copiarCodigo,
                                        icon: const Icon(Icons.copy, size: 18),
                                        label: const Text('Copiar'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _compartirCodigo,
                                        icon: const Icon(Icons.share, size: 18),
                                        label: const Text('Compartir'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _regenerarCodigo,
                                        icon: const Icon(Icons.refresh, size: 18),
                                        label: const Text('Nuevo'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Comparte este código con otras personas para que se unan a tu hogar',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Lista de miembros
                        Row(
                          children: [
                            const Icon(Icons.people, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Miembros (${_hogarDetalle!.miembros.length})',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._hogarDetalle!.miembros.map((miembro) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getRolColor(miembro.rol).withOpacity(0.2),
                                child: Text(
                                  miembro.apodo.isNotEmpty
                                      ? miembro.apodo[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getRolColor(miembro.rol),
                                  ),
                                ),
                              ),
                              title: Text(
                                miembro.apodo,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                'Unido el ${_formatFecha(miembro.fechaUnion)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _RolChip(rol: miembro.rol),
                                  // Botón para editar tu propio apodo
                                  if (miembro.userId == currentUserId)
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      tooltip: 'Editar mi nombre',
                                      onPressed: () => _mostrarDialogoEditarMiApodo(miembro),
                                    ),
                                  // Botón de eliminar (solo para admins y no el mismo usuario)
                                  if (esAdmin && miembro.userId != currentUserId)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20),
                                      color: Colors.red,
                                      tooltip: 'Eliminar miembro',
                                      onPressed: () => _eliminarMiembro(miembro),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 16),
                        
                        // Info adicional
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Todos los miembros pueden ver y gestionar el inventario del hogar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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

  Color _getRolColor(String rol) {
    switch (rol) {
      case 'admin':
        return Colors.purple;
      case 'miembro':
        return Colors.blue;
      case 'invitado':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatFecha(String fechaIso) {
    try {
      final fecha = DateTime.parse(fechaIso);
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    } catch (e) {
      return fechaIso.split('T')[0];
    }
  }
}

// Widget auxiliar para mostrar el rol
class _RolChip extends StatelessWidget {
  final String rol;

  const _RolChip({required this.rol});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String text;

    switch (rol) {
      case 'admin':
        color = Colors.purple;
        icon = Icons.admin_panel_settings;
        text = 'Admin';
        break;
      case 'miembro':
        color = Colors.blue;
        icon = Icons.person;
        text = 'Miembro';
        break;
      case 'invitado':
        color = Colors.grey;
        icon = Icons.visibility;
        text = 'Invitado';
        break;
      default:
        color = Colors.grey;
        icon = Icons.person;
        text = rol;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
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
