
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addAndReloadUbicacion() async {
    if (_addController.text.isEmpty) return;
    try {
      await createUbicacion(_addController.text);
      _addController.clear();
      _reloadUbicaciones();
      _showSnackbar('Ubicación creada con éxito!');
    } catch (e) {
      _showSnackbar('Error al crear: ${e.toString()}', isError: true);
    }
  }

  void _editAndReloadUbicacion(int id, String newName) async {
    try {
      await updateUbicacion(id, newName);
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
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Editar Ubicación'),
          content: TextField(
            controller: editController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nuevo nombre',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Guardar'),
              onPressed: () {
                if (editController.text.isNotEmpty) {
                  Navigator.of(context).pop();
                  _editAndReloadUbicacion(ubicacion.id, editController.text);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteConfirmationDialog(Ubicacion ubicacion) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Seguro que quieres eliminar "${ubicacion.nombre}"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
      elevation: 2.0,
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
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _addAndReloadUbicacion,
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ],
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
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final ubicacion = snapshot.data![index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(ubicacion.nombre),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () => _showEditDialog(ubicacion),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _showDeleteConfirmationDialog(ubicacion),
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
