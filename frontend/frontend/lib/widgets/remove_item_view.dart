// frontend/lib/widgets/remove_item_view.dart
import 'package:flutter/material.dart';
import 'package:frontend/screens/remove_manual_item_screen.dart';
import 'package:frontend/screens/scanner_screen.dart';
import 'package:frontend/screens/remove_scanned_item_screen.dart';
// import 'package:frontend/screens/remove_scanned_item_screen.dart';

class RemoveItemView extends StatelessWidget {
  const RemoveItemView({super.key});

  @override
  Widget build(BuildContext context) {
    // Esta pantalla es un punto de partida para los dos flujos de eliminación.
    // Por ahora, solo la estructura.
    return Scaffold(
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
                onPressed: () async {
                  // 1. Navega a la pantalla del escáner y espera un código de barras.
                  final barcode = await Navigator.of(context).push<String>(
                    MaterialPageRoute(builder: (ctx) => const ScannerScreen()),
                  );

                  // 2. Si se escaneó un código y el widget sigue montado...
                  if (barcode != null && context.mounted) {
                    // 3. Navega a la nueva pantalla de selección, pasándole el código.
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (ctx) =>
                          RemoveScannedItemScreen(barcode: barcode),
                    ));
                  }
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
                  // Simplemente navegamos a la pantalla. El refresco se gestiona en la pantalla contenedora.
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const RemoveManualItemScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}