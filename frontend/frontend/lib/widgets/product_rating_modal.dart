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
    _rating = widget.product.miPuntuacion ?? widget.product.ratingPromedio ?? 5.0;
    _isFavorite = widget.product.esFavorito;
    _noteController = TextEditingController(text: widget.product.miNota ?? '');
    _customTagController = TextEditingController();
    
    final rawTags = widget.product.misTags ?? '';
    _selectedTags = rawTags.isNotEmpty
        ? rawTags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
        : [];

    _allAvailableTags = List.from(_availableTags);
    for (final tag in _selectedTags) {
      if (!_allAvailableTags.contains(tag)) {
        _allAvailableTags.add(tag);
      }
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
              // Barra de agarre superior
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
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
                  // Botón Corazón Favorito
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
}
