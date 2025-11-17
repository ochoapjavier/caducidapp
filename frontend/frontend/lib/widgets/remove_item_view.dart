// frontend/lib/widgets/remove_item_view.dart
import 'package:flutter/material.dart';
import 'package:frontend/screens/remove_manual_item_screen.dart';
import 'package:frontend/screens/scanner_screen.dart';
import 'package:frontend/screens/remove_scanned_item_screen.dart';

class RemoveItemView extends StatelessWidget {
  const RemoveItemView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // Estilo común: mantener el formato de "escaneado" para ambos botones
    final ButtonStyle primaryActionStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 18),
      textStyle: textTheme.titleMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Eliminar producto escaneado'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: textTheme.titleMedium,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final barcode = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (ctx) => const ScannerScreen()),
                );

                if (barcode != null && context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => RemoveScannedItemScreen(barcode: barcode),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'O',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_note),
              label: const Text('Eliminar producto manualmente'),
              style: primaryActionStyle,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const RemoveManualItemScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}