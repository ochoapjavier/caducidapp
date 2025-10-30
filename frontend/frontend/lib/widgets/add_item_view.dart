// frontend/lib/widgets/add_item_view.dart
import 'package:flutter/material.dart';
import 'package:frontend/screens/add_manual_item_screen.dart';

class AddItemView extends StatelessWidget {
  const AddItemView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear Producto'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: Theme.of(context).textTheme.titleLarge,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Funcionalidad de escáner pendiente.')),
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
              icon: const Icon(Icons.edit),
              label: const Text('Añadir Manualmente'),
               style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: Theme.of(context).textTheme.titleLarge,
              ),
              onPressed: () {
                 Navigator.of(context).push(MaterialPageRoute(
                   builder: (ctx) => const AddManualItemScreen(),
                 ));
              },
            ),
          ],
        ),
      ),
    );
  }
}