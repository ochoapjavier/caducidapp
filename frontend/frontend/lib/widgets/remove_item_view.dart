// frontend/lib/widgets/remove_item_view.dart
import 'package:flutter/material.dart';
import 'package:frontend/screens/remove_manual_item_screen.dart';
// import 'package:frontend/screens/remove_scanned_item_screen.dart';

class RemoveItemView extends StatelessWidget {
  const RemoveItemView({super.key});

  @override
  Widget build(BuildContext context) {
    // Esta pantalla es un punto de partida para los dos flujos de eliminación.
    // Por ahora, solo la estructura.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Salida de Stock'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear para Salida'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  textStyle: Theme.of(context).textTheme.titleLarge,
                ),
                onPressed: () {
                  // TODO: Navegar a la pantalla de eliminación por escáner
                    ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Flujo de escáner para salida no implementado.')),
                   );
                },
              ),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('O'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_note),
                label: const Text('Salida Manual'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  textStyle: Theme.of(context).textTheme.titleLarge,
                ),
                onPressed: () {
                  // Navegamos a la nueva pantalla y pasamos el resultado hacia atrás.
                  Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (ctx) => const RemoveManualItemScreen()),
                  ).then((result) {
                    // Si la pantalla de eliminación devuelve true, cerramos esta también
                    // para que la vista de inventario se refresque.
                    if (result == true) Navigator.of(context).pop(true);
                  }); // <-- Se corrigieron los paréntesis y el punto y coma aquí.
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}