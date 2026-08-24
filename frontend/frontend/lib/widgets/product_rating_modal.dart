// frontend/lib/widgets/product_rating_modal.dart

import 'package:flutter/material.dart';
import 'package:frontend/models/catalog_product.dart';
import 'package:frontend/services/api_service.dart' as api;
import 'package:frontend/services/shopping_service.dart';
import 'package:frontend/services/hogar_service.dart';
import 'package:frontend/widgets/app_toast.dart';

class ProductRatingModal extends StatefulWidget {
  final CatalogProduct product;
  final VoidCallback? onRatingSaved;

  const ProductRatingModal({
    super.key,
    required this.product,
    this.onRatingSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required CatalogProduct product,
    VoidCallback? onRatingSaved,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(

        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ProductRatingModal(
          product: product,
          onRatingSaved: onRatingSaved,
        ),
      ),
    );
  }

  @override
  State<ProductRatingModal> createState() => _ProductRatingModalState();
}

class _ProductRatingModalState extends State<ProductRatingModal> {
  late CatalogProduct _product;
  late double _rating;
  late bool _isFavorite;
  late TextEditingController _noteController;
  late TextEditingController _customTagController;
  late List<String> _selectedTags;
  late List<String> _allAvailableTags;
  bool _isSaving = false;
  bool _isAddingToShopping = false;


  final List<String> _availableTags = const [
    '¡Recomendado!',
    'Imprescindible',
    'Top Sabor',
    'Buen Precio',
    'Calidad Alta',
    'No repito',
  ];

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _rating = _product.miPuntuacion ?? _product.ratingPromedio ?? 5.0;
    _isFavorite = _product.esFavorito;
    _noteController = TextEditingController(text: _product.miNota ?? '');
    _customTagController = TextEditingController();
    
    final rawTags = _product.misTags ?? '';
    _selectedTags = rawTags.isNotEmpty
        ? rawTags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
        : [];

    _allAvailableTags = List.from(_availableTags);
    for (final tag in _selectedTags) {
      if (!_allAvailableTags.contains(tag)) {
        _allAvailableTags.add(tag);
      }
    }

    if (_product.barcode != null && _product.barcode!.isNotEmpty && _product.novaGroup == null) {
      _fetchNutritionData();
    }
  }

  Future<void> _fetchNutritionData() async {
    try {
      final res = await api.fetchCatalogProductNutrition(_product.idProducto);
      if (res['status'] == 'success' && res['nutrition'] != null) {
        final nut = res['nutrition'];
        if (!mounted) return;
        setState(() {
          _product = _product.copyWith(
            novaGroup: nut['nova_group'] as int?,
            nutriscoreGrade: nut['nutriscore_grade'] as String?,
            alergenos: nut['alergenos'] as String?,
            aditivosCount: nut['aditivos_count'] as int? ?? 0,
            semaforoNutricional: nut['semaforo_nutricional'] as String?,
            nutrientes100g: nut['nutrientes_100g'] as String?,
            imageUrl: nut['image_url'] as String? ?? _product.imageUrl,
          );
        });
      }
    } catch (e) {
      debugPrint('Error al auto-cargar nutrición de OpenFoodFacts: $e');
    }
  }



  @override
  void dispose() {
    _noteController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  void _addCustomTag() {
    final text = _customTagController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      if (!_allAvailableTags.contains(text)) {
        _allAvailableTags.add(text);
      }
      if (!_selectedTags.contains(text)) {
        _selectedTags.add(text);
      }
      _customTagController.clear();
    });
  }


  String _getRatingSubtitle(double rating) {
    if (rating >= 5.0) return '¡Excelente! Producto imprescindible ⭐⭐⭐⭐⭐';
    if (rating >= 4.0) return 'Muy bueno, altamente recomendado ⭐⭐⭐⭐';
    if (rating >= 3.0) return 'Aceptable / Cumple lo esperado ⭐⭐⭐';
    if (rating >= 2.0) return 'No muy convencido / Mejorable ⭐⭐';
    return 'Mala calidad / No volver a comprar ⭐';
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _saveRating() async {
    setState(() => _isSaving = true);
    try {
      final tagsString = _selectedTags.isNotEmpty ? _selectedTags.join(', ') : null;
      final noteText = _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null;

      await api.rateCatalogProduct(
        productId: widget.product.idProducto,
        puntuacion: _rating,
        esFavorito: _isFavorite,
        nota: noteText,
        tags: tagsString,
      );

      if (!mounted) return;
      AppToast.show(
        context,
        message: '¡Valoración guardada con éxito!',
        type: AppToastType.success,
      );
      Navigator.of(context).pop();
      widget.onRatingSaved?.call();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'Error al guardar la valoración: $e',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteRating() async {
    setState(() => _isSaving = true);
    try {
      await api.deleteCatalogProductRating(widget.product.idProducto);

      if (!mounted) return;
      AppToast.show(
        context,
        message: 'Valoración eliminada',
        type: AppToastType.info,
      );
      Navigator.of(context).pop();
      widget.onRatingSaved?.call();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'Error al eliminar valoración: $e',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addToShoppingList() async {
    setState(() => _isAddingToShopping = true);
    try {
      final hogarService = HogarService();
      final hogarId = await hogarService.getHogarActivo();
      if (hogarId == null) {
        throw Exception('No hay ningún hogar activo seleccionado');
      }

      final shoppingService = ShoppingService();
      await shoppingService.addItem(
        hogarId,
        widget.product.nombre,
        fkProducto: widget.product.idProducto,
      );

      if (!mounted) return;
      AppToast.show(
        context,
        message: '¡${widget.product.nombre} añadido a la Lista de la Compra!',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'Error al añadir a la lista: $e',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _isAddingToShopping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de agarre superior deslizable e interactiva para cerrar
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  if (details.primaryDelta != null && details.primaryDelta! > 4) {
                    Navigator.of(context).pop();
                  }
                },
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),

              // Cabecera del Producto
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Imagen o icono del producto
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    child: widget.product.imageUrl != null && widget.product.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              widget.product.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.inventory_2_outlined,
                                size: 32,
                                color: colorScheme.primary,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.inventory_2_outlined,
                            size: 32,
                            color: colorScheme.primary,
                          ),
                  ),
                  const SizedBox(width: 16),
                  // Nombre y marca
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.nombre,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.product.marca != null && widget.product.marca!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.product.marca!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        // Badge de Stock
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.product.stockActual > 0
                                ? Colors.green.withOpacity(0.12)
                                : colorScheme.errorContainer.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.product.stockActual > 0
                                ? 'En stock: ${widget.product.stockActual} ud.'
                                : 'Sin stock',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: widget.product.stockActual > 0
                                  ? Colors.green.shade700
                                  : colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Botones Favorito y Cerrar X
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        onPressed: () {
                          setState(() => _isFavorite = !_isFavorite);
                        },
                        icon: Icon(
                          _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: _isFavorite ? Colors.red : colorScheme.onSurfaceVariant,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: _isFavorite
                              ? Colors.red.withOpacity(0.15)
                              : colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Cerrar modal',
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ],
              ),


              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 20),

              // Selector de Estrellas Interactivo
              Center(
                child: Text(
                  '¿Qué te parece este producto?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Estrellas
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = (index + 1).toDouble();
                  final isFilled = _rating >= starValue;
                  return IconButton(
                    iconSize: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: () {
                      setState(() => _rating = starValue);
                    },
                    icon: Icon(
                      isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isFilled ? Colors.amber.shade600 : colorScheme.outlineVariant,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),

              // Subtítulo explicativo según estrellas
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _getRatingSubtitle(_rating),
                    key: ValueKey(_rating),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Tags / Etiquetas de opinión
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Etiquetas de valoración:',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_selectedTags.isNotEmpty)
                    Text(
                      '${_selectedTags.length} seleccionada(s)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._allAvailableTags.map((tag) {
                    final isSelected = _selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: isSelected,
                      onSelected: (_) => _toggleTag(tag),
                      selectedColor: colorScheme.primaryContainer,
                      checkmarkColor: colorScheme.primary,
                      labelStyle: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 10),
              // Campo para agregar etiquetas personalizadas
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customTagController,
                      decoration: InputDecoration(
                        hintText: 'Añadir otra etiqueta personalizada...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerLow,
                      ),
                      onSubmitted: (_) => _addCustomTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _addCustomTag,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    tooltip: 'Añadir etiqueta',
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Nota / Reseña personal
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Nota o comentario personal (Opcional)',
                  hintText: 'Ej. Comprar siempre marca hacendado, la versión 0% sabe mejor',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLow,
                ),
              ),

              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 20),

              // Sección Nutricional & Salud (MyRealFood + NutriScore + Tabla por 100g)
              _buildNutritionSection(context),

              const SizedBox(height: 24),


              // Botón Acción: Añadir a la Lista de la Compra
              OutlinedButton.icon(
                onPressed: _isAddingToShopping ? null : _addToShoppingList,
                icon: _isAddingToShopping
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Añadir a la Lista de la Compra'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Botón Principal: Guardar Valoración
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveRating,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Guardar Valoración'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              if (widget.product.miPuntuacion != null) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _isSaving ? null : _deleteRating,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  child: const Text('Eliminar mi valoración'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final product = _product;
    final nutrientes = product.nutrientesMap;
    final semaforo = product.semaforoMap;


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.health_and_safety_rounded, size: 22, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              'Información Nutricional & Salud',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Badges principales: MyRealFood (NOVA) + Nutri-Score (Wrap anti-overflow)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (product.novaGroup != null)
              _buildNovaBadge(product.novaGroup!),
            if (product.nutriscoreGrade != null && product.nutriscoreGrade!.isNotEmpty)
              _buildNutriscoreBadge(product.nutriscoreGrade!),
            if (product.aditivosCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Text(
                  '⚠️ ${product.aditivosCount} Aditivos',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
          ],
        ),


        const SizedBox(height: 14),

        // Tabla de Valores por 100g
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Valores por 100 g',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              
              // ⚡ Energía (kcal)
              _buildMacroItem(
                label: '⚡ Energía',
                value: nutrientes != null && nutrientes['energy_kcal'] != null
                    ? '${nutrientes['energy_kcal']} kcal'
                    : 'Sin info',
                isSub: false,
              ),
              const Divider(height: 12),

              // 🍞 Hidratos de carbono
              _buildMacroItem(
                label: '🍞 Hidratos de carbono',
                value: nutrientes != null && nutrientes['carbohydrates'] != null
                    ? '${nutrientes['carbohydrates']} g'
                    : 'Sin info',
                isSub: false,
              ),
              // ↳ Azúcares (con semáforo)
              _buildMacroItem(
                label: '    ↳ de los cuales Azúcares',
                value: nutrientes != null && nutrientes['sugars'] != null
                    ? '${nutrientes['sugars']} g'
                    : 'Sin info',
                level: _getSemaforoLevel(semaforo, 'sugars'),
                isSub: true,
              ),
              const Divider(height: 12),

              // 🥑 Grasas
              _buildMacroItem(
                label: '🥑 Grasas',
                value: nutrientes != null && nutrientes['fat'] != null
                    ? '${nutrientes['fat']} g'
                    : 'Sin info',
                level: _getSemaforoLevel(semaforo, 'fat'),
                isSub: false,
              ),
              // ↳ Saturadas (con semáforo)
              _buildMacroItem(
                label: '    ↳ de las cuales Saturadas',
                value: nutrientes != null && (nutrientes['saturated_fat'] ?? nutrientes['saturated-fat']) != null
                    ? '${nutrientes['saturated_fat'] ?? nutrientes['saturated-fat']} g'
                    : 'Sin info',
                level: _getSemaforoLevel(semaforo, 'saturated_fat'),
                isSub: true,
              ),
              const Divider(height: 12),

              // 💪 Proteínas
              _buildMacroItem(
                label: '💪 Proteínas',
                value: nutrientes != null && nutrientes['proteins'] != null
                    ? '${nutrientes['proteins']} g'
                    : 'Sin info',
                isSub: false,
              ),
              const Divider(height: 12),

              // 🧂 Sal
              _buildMacroItem(
                label: '🧂 Sal',
                value: nutrientes != null && nutrientes['salt'] != null
                    ? '${nutrientes['salt']} g'
                    : 'Sin info',
                level: _getSemaforoLevel(semaforo, 'salt'),
                isSub: false,
              ),

              // 🌾 Fibra
              const Divider(height: 12),
              _buildMacroItem(
                label: '🌾 Fibra alimentaria',
                value: nutrientes != null && nutrientes['fiber'] != null
                    ? '${nutrientes['fiber']} g'
                    : 'Sin info',
                customBadge: nutrientes != null ? _buildFiberBadge(nutrientes['fiber']) : null,
                isSub: false,
              ),

              // 🩸 Hierro
              const Divider(height: 12),
              _buildMacroItem(
                label: '🩸 Hierro',
                value: nutrientes != null && nutrientes['iron_mg'] != null
                    ? '${nutrientes['iron_mg']} mg'
                    : 'Sin info',
                customBadge: nutrientes != null ? _buildIronBadge(nutrientes['iron_mg']) : null,
                isSub: false,
              ),

              // 🦴 Calcio
              const Divider(height: 12),
              _buildMacroItem(
                label: '🦴 Calcio',
                value: nutrientes != null && nutrientes['calcium_mg'] != null
                    ? '${nutrientes['calcium_mg']} mg'
                    : 'Sin info',
                customBadge: nutrientes != null ? _buildCalciumBadge(nutrientes['calcium_mg']) : null,
                isSub: false,
              ),



            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNovaBadge(int nova) {
    String label;
    Color color;
    Color textColor;

    switch (nova) {
      case 1:
        label = '🟢 Comida Real';
        color = Colors.green.shade100;
        textColor = Colors.green.shade900;
        break;
      case 2:
      case 3:
        label = '🟡 Buen Procesado';
        color = Colors.amber.shade100;
        textColor = Colors.amber.shade900;
        break;
      default:
        label = '🔴 Ultraprocesado';
        color = Colors.red.shade100;
        textColor = Colors.red.shade900;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
      ),
    );
  }

  Widget _buildNutriscoreBadge(String grade) {
    final clean = grade.toLowerCase();
    Color bg;
    switch (clean) {
      case 'a': bg = const Color(0xFF038141); break;
      case 'b': bg = const Color(0xFF85BB2F); break;
      case 'c': bg = const Color(0xFFFECB02); break;
      case 'd': bg = const Color(0xFFEE8100); break;
      default:  bg = const Color(0xFFE63E11); break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Nutri-Score ${grade.toUpperCase()}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
      ),
    );
  }

  String? _getSemaforoLevel(Map<String, dynamic>? semaforo, String key) {
    if (semaforo == null) return null;
    final val = semaforo[key] ??
        semaforo[key.replaceAll('_', '-')] ??
        semaforo[key.replaceAll('-', '_')];
    return val?.toString();
  }

  Widget? _buildIronBadge(dynamic rawIron) {
    if (rawIron == null) return null;
    final val = double.tryParse(rawIron.toString());
    if (val == null) return null;
    final vrn = ((val / 14.0) * 100).round();
    if (val >= 4.2) {
      return _buildMiniBadge('Alto 🌟 ($vrn% VRN)', Colors.purple.shade800, Colors.purple.shade50);
    } else if (val >= 2.1) {
      return _buildMiniBadge('Medio 🟢 ($vrn% VRN)', Colors.green.shade800, Colors.green.shade50);
    } else if (val >= 0.7) {
      return _buildMiniBadge('Moderado 🟡 ($vrn% VRN)', Colors.amber.shade900, Colors.amber.shade50);
    }
    return _buildMiniBadge('Bajo ⚪ ($vrn% VRN)', Colors.grey.shade700, Colors.grey.shade100);
  }

  Widget? _buildFiberBadge(dynamic rawFiber) {
    if (rawFiber == null) return null;
    final val = double.tryParse(rawFiber.toString());
    if (val == null) return null;
    if (val >= 6.0) {
      return _buildMiniBadge('Alto 🌾 (${val}g)', Colors.brown.shade800, Colors.amber.shade50);
    } else if (val >= 3.0) {
      return _buildMiniBadge('Medio 🟢 (${val}g)', Colors.green.shade800, Colors.green.shade50);
    } else if (val >= 1.5) {
      return _buildMiniBadge('Moderado 🟡 (${val}g)', Colors.amber.shade900, Colors.amber.shade50);
    }
    return _buildMiniBadge('Bajo ⚪ (${val}g)', Colors.grey.shade700, Colors.grey.shade100);
  }

  Widget? _buildCalciumBadge(dynamic rawCalcium) {
    if (rawCalcium == null) return null;
    final val = double.tryParse(rawCalcium.toString());
    if (val == null) return null;
    final vrn = ((val / 800.0) * 100).round();
    if (val >= 240) {
      return _buildMiniBadge('Alto 🦴 ($vrn% VRN)', Colors.blue.shade900, Colors.blue.shade50);
    } else if (val >= 120) {
      return _buildMiniBadge('Medio 🟢 ($vrn% VRN)', Colors.teal.shade800, Colors.teal.shade50);
    } else if (val >= 40) {
      return _buildMiniBadge('Moderado 🟡 ($vrn% VRN)', Colors.amber.shade900, Colors.amber.shade50);
    }
    return _buildMiniBadge('Bajo ⚪ ($vrn% VRN)', Colors.grey.shade700, Colors.grey.shade100);
  }


  Widget _buildMiniBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Widget _buildMacroItem({
    required String label,
    required String value,
    String? level,
    Widget? customBadge,
    required bool isSub,
  }) {
    Color? levelColor;
    String? levelText;


    if (level != null && level != 'unknown') {
      switch (level.toLowerCase()) {
        case 'low':
          levelColor = Colors.green.shade700;
          levelText = 'Bajo';
          break;
        case 'moderate':
          levelColor = Colors.amber.shade800;
          levelText = 'Medio';
          break;
        case 'high':
          levelColor = Colors.red.shade700;
          levelText = 'Alto';
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isSub ? 12 : 13,
              fontWeight: isSub ? FontWeight.w500 : FontWeight.w600,
              color: isSub ? Colors.grey.shade700 : null,
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: value == 'Sin info'
                    ? TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade500,
                      )
                    : TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: levelColor,
                      ),
              ),
              if (customBadge != null) ...[
                const SizedBox(width: 6),
                customBadge,
              ] else if (levelText != null && levelColor != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    levelText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: levelColor,
                    ),
                  ),
                ),
              ],

            ],
          ),
        ],
      ),
    );
  }
}

