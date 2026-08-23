// frontend/lib/screens/catalog_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/models/catalog_product.dart';
import 'package:frontend/services/api_service.dart' as api;
import 'package:frontend/services/shopping_service.dart';
import 'package:frontend/services/hogar_service.dart';
import 'package:frontend/widgets/product_rating_modal.dart';
import 'package:frontend/widgets/app_toast.dart';
import 'package:frontend/widgets/error_view.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  late Future<List<CatalogProduct>> _productsFuture;

  // Filtros y ordenación
  String _activeFilter = 'todos'; // 'todos', 'favoritos', 'stock', 'top'
  String _sortBy = 'name_asc'; // 'name_asc', 'rating_desc', 'rating_asc', 'stock_desc'
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _refreshProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _refreshProducts();
    });
  }

  void _refreshProducts() {
    setState(() {
      _productsFuture = api.fetchCatalogProducts(
        search: _searchController.text.trim(),
        onlyFavorites: _activeFilter == 'favoritos',
        onlyInStock: _activeFilter == 'stock',
        minRating: _activeFilter == 'top' ? 4.0 : null,
        sortBy: _sortBy,
      );
    });
  }

  Future<void> _toggleFavorite(CatalogProduct product) async {
    try {
      final newFavState = await api.toggleCatalogProductFavorite(product.idProducto);
      if (!mounted) return;
      AppToast.show(
        context,
        message: newFavState
            ? '${product.nombre} añadido a favoritos ❤️'
            : '${product.nombre} quitado de favoritos',
        type: AppToastType.info,
      );
      _refreshProducts();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'Error al cambiar favorito: $e',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _quickAddToShoppingList(CatalogProduct product) async {
    try {
      final hogarService = HogarService();
      final hogarId = await hogarService.getHogarActivo();
      if (hogarId == null) throw Exception('Sin hogar activo');

      final shoppingService = ShoppingService();
      await shoppingService.addItem(
        hogarId,
        product.nombre,
        fkProducto: product.idProducto,
      );

      if (!mounted) return;
      AppToast.show(
        context,
        message: '¡${product.nombre} añadido a la Lista de la Compra!',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'Error al añadir a la lista: $e',
        type: AppToastType.error,
      );
    }
  }

  void _openRatingModal(CatalogProduct product) {
    ProductRatingModal.show(
      context,
      product: product,
      onRatingSaved: _refreshProducts,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Productos'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            tooltip: _isGridView ? 'Vista lista' : 'Vista cuadrícula',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Ordenar por',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _refreshProducts();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'name_asc',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Nombre (A-Z)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'rating_desc',
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, size: 20, color: Colors.amber),
                    SizedBox(width: 12),
                    Text('Mayor valoración'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'rating_asc',
                child: Row(
                  children: [
                    Icon(Icons.star_outline_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Menor valoración'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'stock_desc',
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Mayor stock'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda y Filtros
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Campo de Búsqueda
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar en el catálogo...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              _refreshProducts();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 10),
                // Barra de Filtros Rápida Estilo Segmented Control
                Container(

                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(3),
                    children: [
                      _buildSegmentFilter('todos', 'Todos', Icons.grid_view_rounded),
                      _buildSegmentFilter('favoritos', 'Favoritos ❤️', Icons.favorite_rounded),
                      _buildSegmentFilter('stock', 'En Stock 📦', Icons.inventory_2_rounded),
                      _buildSegmentFilter('top', 'Top 4+ ⭐', Icons.star_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Tira de Sugerencias de Tags Rápidos
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      if (_searchController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InputChip(
                            avatar: const Icon(Icons.search_rounded, size: 14),
                            label: Text('"${_searchController.text}"'),
                            onDeleted: () {
                              _searchController.clear();
                              _refreshProducts();
                            },
                            deleteIconColor: colorScheme.error,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ...['¡Recomendado!', 'Imprescindible', 'Top Sabor', 'Buen Precio', 'Calidad Alta', 'No repito'].map((tag) {
                        final isSearched = _searchController.text.trim().toLowerCase() == tag.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            showCheckmark: false,
                            label: Text('#$tag'),
                            selected: isSearched,
                            selectedColor: colorScheme.primaryContainer,
                            visualDensity: VisualDensity.compact,
                            labelStyle: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: isSearched ? FontWeight.bold : FontWeight.w500,
                              color: isSearched ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                _searchController.text = tag;
                              } else {
                                _searchController.clear();
                              }
                              _refreshProducts();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista / Grid de Productos
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refreshProducts(),
              child: FutureBuilder<List<CatalogProduct>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return ErrorView(
                      error: snapshot.error!,
                      onRetry: _refreshProducts,
                    );
                  }

                  final products = snapshot.data ?? [];

                  if (products.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.menu_book_rounded,
                                  size: 48,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No se encontraron productos'
                                    : 'Catálogo vacío',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  _searchController.text.isNotEmpty
                                      ? 'Prueba con otro término de búsqueda o cambia los filtros.'
                                      : 'Los productos que agregues a tu inventario aparecerán en este catálogo para que puedas valorarlos siempre.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  if (_isGridView) {
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.62,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        return _buildProductGridCard(context, products[index]);
                      },
                    );
                  } else {
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _buildProductListTile(context, products[index]);
                      },
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentFilter(String value, String label, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _activeFilter == value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Material(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _activeFilter = value;
                _refreshProducts();
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductGridCard(BuildContext context, CatalogProduct product) {

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        onTap: () => _openRatingModal(product),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen y Botón Favorito
              Stack(
                children: [
                  Container(
                    height: 75,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),

                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.inventory_2_outlined,
                                size: 36,
                                color: colorScheme.primary.withOpacity(0.7),
                              ),
                            ),
                          )
                        : Icon(
                            Icons.inventory_2_outlined,
                            size: 36,
                            color: colorScheme.primary.withOpacity(0.7),
                          ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => _toggleFavorite(product),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          product.esFavorito ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 18,
                          color: product.esFavorito ? Colors.red : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  // Badge Stock
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: product.stockActual > 0
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.stockActual > 0 ? '${product.stockActual} en stock' : 'Sin stock',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Nombre
              Text(
                product.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              // Marca
              if (product.marca != null && product.marca!.isNotEmpty)
                Text(
                  product.marca!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                )
              else
                const SizedBox(height: 4),

              if (product.misTags != null && product.misTags!.isNotEmpty) ...[
                const SizedBox(height: 2),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: product.misTags!.split(',').map((t) {
                      final tag = t.trim();
                      if (tag.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: InkWell(
                          onTap: () {
                            _searchController.text = tag;
                            _refreshProducts();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '#$tag',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              const Spacer(),

              // Puntuación Estrellas y botón rápido
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        product.ratingPromedio != null
                            ? product.ratingPromedio!.toStringAsFixed(1)
                            : '-',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (product.totalValoraciones > 0)
                        Text(
                          ' (${product.totalValoraciones})',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    tooltip: 'Añadir a la lista',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _quickAddToShoppingList(product),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductListTile(BuildContext context, CatalogProduct product) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.05),
      child: InkWell(
        onTap: () => _openRatingModal(product),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.4),
            ),
          ),
          child: Row(
            children: [
              // Imagen
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.inventory_2_outlined,
                            size: 24,
                            color: colorScheme.primary,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.inventory_2_outlined,
                        size: 24,
                        color: colorScheme.primary,
                      ),
              ),
              const SizedBox(width: 14),

              // Datos principales
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (product.marca != null && product.marca!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        product.marca!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (product.misTags != null && product.misTags!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: product.misTags!.split(',').map((t) {
                          final tag = t.trim();
                          if (tag.isEmpty) return const SizedBox.shrink();
                          return InkWell(
                            onTap: () {
                              _searchController.text = tag;
                              _refreshProducts();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#$tag',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Rating
                        const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          product.ratingPromedio != null
                              ? product.ratingPromedio!.toStringAsFixed(1)
                              : 'Sin valorar',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (product.totalValoraciones > 0)
                          Text(
                            ' (${product.totalValoraciones})',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(width: 12),
                        // Stock
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: product.stockActual > 0
                                ? Colors.green.withOpacity(0.15)
                                : colorScheme.errorContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.stockActual > 0 ? '${product.stockActual} en stock' : 'Sin stock',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: product.stockActual > 0 ? Colors.green.shade800 : colorScheme.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),


              // Acciones
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      product.esFavorito ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: product.esFavorito ? Colors.red : colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => _toggleFavorite(product),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    tooltip: 'Añadir a la lista',
                    onPressed: () => _quickAddToShoppingList(product),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
