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
              label: const Text('Añadir Producto Escaneado'),
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

                  // --- INICIO DE LA NUEVA LÓGICA DE BÚSQUEDA ---
                  Map<String, dynamic>? productData;
                  bool foundInLocalDB = false;

                  // 1. Buscar primero en nuestro catálogo
                  productData = await fetchProductFromCatalog(barcode);

                  if (productData != null) {
                    foundInLocalDB = true;
                  } else {
                    // 2. Si no, buscar en OpenFoodFacts
                    final offData = await fetchProductFromOpenFoodFacts(barcode);
                    if (offData != null) {
                      // Adaptamos la respuesta de OFF a un mapa más simple
                      final nameEs = offData['product_name_es'] as String?;
                      final nameEn = offData['product_name_en'] as String?;
                      final nameGeneric = offData['product_name'] as String?;

                      productData = {
                        'nombre': (nameEs != null && nameEs.isNotEmpty) ? nameEs
                                : (nameEn != null && nameEn.isNotEmpty) ? nameEn
                                : (nameGeneric != null && nameGeneric.isNotEmpty) ? nameGeneric
                                : 'Nombre no encontrado',
                        'marca': offData['brands'],
                        'image_url': offData['image_front_thumb_url'], // <-- AÑADIMOS LA URL DE LA IMAGEN
                      };
                    }
                  }
                  // --- FIN DE LA NUEVA LÓGICA DE BÚSQUEDA ---

                  Navigator.of(context).pop(); // Cierra el spinner

                  if (productData != null && context.mounted) {
                    // Producto encontrado, navegamos a la pantalla de confirmación
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (ctx) => AddScannedItemScreen(
                        barcode: barcode,
                        initialProductName: productData!['nombre'] as String,
                        initialBrand: productData['marca'] as String?,
                        initialImageUrl: productData['image_url'] as String?, // <-- LA PASAMOS A LA PANTALLA
                        isFromLocalDB: foundInLocalDB, // Le decimos a la pantalla de dónde vienen los datos
                      ),
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