
import 'package:flutter/material.dart';
import '../models/ubicacion.dart';
import '../services/api_service.dart';

class UbicacionManager extends StatefulWidget {
  const UbicacionManager({super.key});

  @override
  State<UbicacionManager> createState() => _UbicacionManagerState();
}

class _UbicacionManagerState extends State<UbicacionManager> {
  final TextEditingController _addController = TextEditingController();
  late Future<List<Ubicacion>> _futureUbicaciones;
  bool _isNewLocationFreezer = false; // Estado para el checkbox de crear

  @override
  void initState() {
    super.initState();
    _reloadUbicaciones();
  }

  void _reloadUbicaciones() {
    setState(() {
      _futureUbicaciones = fetchUbicaciones();
    });
  }

  void _showSnackbar(String message, {bool isError = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? scheme.error : scheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addAndReloadUbicacion() async {
    if (_addController.text.isEmpty) return;
    try {
      await createUbicacion(_addController.text, esCongelador: _isNewLocationFreezer);
      _addController.clear();
      setState(() {
        _isNewLocationFreezer = false; // Reset checkbox después de crear
      });
      _reloadUbicaciones();
      _showSnackbar('Ubicación creada con éxito!');
    } catch (e) {
      _showSnackbar('Error al crear: ${e.toString()}', isError: true);
    }
  }

  void _editAndReloadUbicacion(int id, String newName, {bool? esCongelador}) async {
    try {
      await updateUbicacion(id, newName, esCongelador: esCongelador);
      _reloadUbicaciones();
      _showSnackbar('Ubicación actualizada con éxito!');
    } catch (e) {
      _showSnackbar('Error al actualizar: ${e.toString()}', isError: true);
    }
  }

  void _deleteAndReloadUbicacion(int id) async {
    try {
      await deleteUbicacion(id);
      _reloadUbicaciones();
      _showSnackbar('Ubicación eliminada con éxito!');
    } catch (e) {
      _showSnackbar('Error al eliminar: ${e.toString()}', isError: true);
    }
  }

  Future<void> _showEditDialog(Ubicacion ubicacion) async {
    final editController = TextEditingController(text: ubicacion.nombre);
    bool isEditFreezer = ubicacion.esCongelador; // Estado inicial
    
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Editar Ubicación'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: editController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nuevo nombre',
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: const [
                        Icon(Icons.ac_unit, size: 18),
                        SizedBox(width: 8),
                        Text('Es congelador'),
                      ],
                    ),
                    subtitle: const Text(
                      'Las ubicaciones de tipo congelador aparecerán al congelar productos',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: isEditFreezer,
                    onChanged: (bool? value) {
                      setStateDialog(() {
                        isEditFreezer = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                FilledButton(
                  child: const Text('Guardar'),
                  onPressed: () {
                    if (editController.text.isNotEmpty) {
                      Navigator.of(context).pop();
                      _editAndReloadUbicacion(
                        ubicacion.id, 
                        editController.text,
                        esCongelador: isEditFreezer,
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteConfirmationDialog(Ubicacion ubicacion) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Seguro que quieres eliminar "${ubicacion.nombre}"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              child: const Text('Eliminar'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAndReloadUbicacion(ubicacion.id);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAddUbicacionCard(),
            const SizedBox(height: 20),
            const Text('Ubicaciones Existentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: _buildUbicacionesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddUbicacionCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Añadir Nueva Ubicación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la ubicación',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _addAndReloadUbicacion,
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: const [
                  Icon(Icons.ac_unit, size: 18),
                  SizedBox(width: 8),
                  Text('Es congelador'),
                ],
              ),
              subtitle: const Text(
                'Las ubicaciones de tipo congelador aparecerán al congelar productos',
                style: TextStyle(fontSize: 11),
              ),
              value: _isNewLocationFreezer,
              onChanged: (bool? value) {
                setState(() {
                  _isNewLocationFreezer = value ?? false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUbicacionesList() {
    return FutureBuilder<List<Ubicacion>>(
      future: _futureUbicaciones,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error al cargar: ${snapshot.error}'));
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final items = snapshot.data!;
          final scheme = Theme.of(context).colorScheme;
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final ubicacion = items[index];
              return Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: ubicacion.esCongelador 
                              ? Colors.blue.shade100
                              : scheme.primary.withAlpha((255 * 0.12).round()),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          ubicacion.esCongelador ? Icons.ac_unit : Icons.location_on_outlined,
                          color: ubicacion.esCongelador ? Colors.blue.shade700 : scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                ubicacion.nombre,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (ubicacion.esCongelador) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue.shade300, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.ac_unit, size: 10, color: Colors.blue.shade700),
                                    const SizedBox(width: 3),
                                    Text(
                                      'CONGELADOR',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.blue.shade700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Acciones',
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _showEditDialog(ubicacion);
                              break;
                            case 'delete':
                              _showDeleteConfirmationDialog(ubicacion);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: const [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Renombrar'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: const [
                                Icon(Icons.delete_outline, size: 18),
                                SizedBox(width: 8),
                                Text('Eliminar'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }
        return const Center(child: Text('No hay ubicaciones registradas.'));
      },
    );
  }
}
