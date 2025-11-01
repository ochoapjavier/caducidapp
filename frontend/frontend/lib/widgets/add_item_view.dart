// frontend/lib/widgets/add_item_view.dart
import 'package:flutter/material.dart';
import 'package:frontend/screens/scanner_screen.dart';
import 'package:frontend/screens/add_manual_item_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/add_scanned_item_screen.dart';
import 'package:intl/intl.dart';

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
              onPressed: () async {
                // Navega a la pantalla del escáner y espera un resultado (el código de barras)
                final barcode = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (ctx) => const ScannerScreen()),
                );

                if (barcode != null && context.mounted) {
                  // Mostramos un spinner mientras buscamos el producto
                  showDialog(context: context, builder: (ctx) => const Center(child: CircularProgressIndicator()), barrierDismissible: false);

                  final productData = await fetchProductFromOpenFoodFacts(barcode);

                  Navigator.of(context).pop(); // Cierra el spinner

                  if (productData != null && context.mounted) {
                    // Producto encontrado, navegamos a la pantalla de confirmación
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (ctx) {
                        // --- INICIO DE LA NUEVA LÓGICA DE SELECCIÓN DE NOMBRE ---
                        final nameEs = productData['product_name_es'] as String?;
                        final nameEn = productData['product_name_en'] as String?;
                        final nameGeneric = productData['product_name'] as String?;

                        final productName = (nameEs != null && nameEs.isNotEmpty) ? nameEs
                                          : (nameEn != null && nameEn.isNotEmpty) ? nameEn
                                          : (nameGeneric != null && nameGeneric.isNotEmpty) ? nameGeneric
                                          : 'Nombre no encontrado';
                        // --- FIN DE LA NUEVA LÓGICA ---

                        return AddScannedItemScreen(barcode: barcode, productName: productName, brand: productData['brands']);
                      },
                    ));
                  } else if (context.mounted) {
                    // Producto no encontrado
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Producto no encontrado en la base de datos online. Intenta añadirlo manualmente.'), backgroundColor: Colors.orange),
                    );
                  }
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