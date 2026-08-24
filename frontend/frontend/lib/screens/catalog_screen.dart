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
import 'package:frontend/screens/supermarket_scanner_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  double _savedScrollOffset = 0.0;
  Timer? _debounce;
  late Future<List<CatalogProduct>> _productsFuture;
  late Future<Map<String, dynamic>> _healthSummaryFuture;

  // Filtros agrupados
  String _tabFilter = 'todos'; // 'todos', 'stock', 'favoritos'
  String _healthFilter = 'ninguno'; // 'ninguno', 'realfood', 'iron', 'protein', 'low_sugar', 'high_fiber'
  double _ratingFilter = 0.0; // 0.0, 4.0, 3.0
  String _sortBy = 'name_asc'; // 'name_asc', 'rating_desc', 'rating_asc', 'stock_desc'
  bool _isGridView = true;
  bool _isSyncingNutrition = false;
  bool _showHealthDashboard = true;
  bool _healthSummaryOnlyInStock = true;

  Future<void> _triggerBulkNutritionSync() async {
    setState(() => _isSyncingNutrition = true);
    AppToast.show(
      context,
      message: 'Sincronizando información nutricional...',
      type: AppToastType.info,
    );
    try {
      final count = await api.syncBulkNutrition();
      if (!mounted) return;
      if (count > 0) {
        AppToast.show(
          context,
          message: '¡Nutrición actualizada en $count productos!',
          type: AppToastType.success,
        );
        _refreshProducts();
      } else {
        AppToast.show(
          context,
          message: 'Todos los productos ya tienen nutrición al día',
          type: AppToastType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'Error al sincronizar nutrición: $e',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncingNutrition = false);
      }
    }
  }

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
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _refreshProducts();
    });
  }

  void _refreshProducts({bool preserveScroll = false}) {
    if (preserveScroll && _scrollController.hasClients) {
      _savedScrollOffset = _scrollController.offset;
    } else {
      _savedScrollOffset = 0.0;
    }

    setState(() {
      _productsFuture = api.fetchCatalogProducts(
        search: _searchController.text.trim(),
        onlyFavorites: _tabFilter == 'favoritos',
        onlyInStock: _tabFilter == 'stock',
        onlyRealfood: _healthFilter == 'realfood',
        onlyHighIron: _healthFilter == 'iron',
        onlyHighProtein: _healthFilter == 'protein',
        onlyLowSugar: _healthFilter == 'low_sugar',
        onlyHighFiber: _healthFilter == 'high_fiber',
        minRating: _ratingFilter > 0 ? _ratingFilter : null,
        sortBy: _sortBy,
      );
      _healthSummaryFuture = api.fetchCatalogHealthSummary(onlyInStock: _healthSummaryOnlyInStock);
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
      _refreshProducts(preserveScroll: true);
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

  /// Método de refresco público invocado al cambiar de pestaña o desde el exterior
  void refresh() {
    if (mounted) {
      _refreshProducts(preserveScroll: true);
    }
  }

  Future<void> _openRatingModal(CatalogProduct product) async {
    await ProductRatingModal.show(
      context,
      product: product,
      onRatingSaved: () => _refreshProducts(preserveScroll: true),
    );
    // Auto-refrescar siempre al cerrar la ficha, haya guardado o no, manteniendo la posición de scroll
    _refreshProducts(preserveScroll: true);
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.greenAccent),
            tooltip: 'NutriScanner Supermercado',
            onPressed: () async {
              final activeHogarId = await HogarService().getHogarActivo();
              if (context.mounted) {

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SupermarketScannerScreen(hogarId: activeHogarId),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: _isSyncingNutrition
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: 'Sincronizar nutrición del catálogo',
            onPressed: _isSyncingNutrition ? null : _triggerBulkNutritionSync,
          ),
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
                // 1. Pestañas de Estado / Navegación Principal
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildTabFilter('todos', 'Todos', Icons.grid_view_rounded)),
                      Expanded(child: _buildTabFilter('stock', 'En Stock 📦', Icons.inventory_2_rounded)),
                      Expanded(child: _buildTabFilter('favoritos', 'Favoritos ❤️', Icons.favorite_rounded)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 2. Filtros Desplegables Agrupados (Salud / Valoración)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      // Desplegable Salud & Nutrición
                      PopupMenuButton<String>(
                        onSelected: (val) {
                          setState(() {
                            _healthFilter = val;
                            _refreshProducts();
                          });
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'ninguno', child: Text('Ver toda la nutrición')),
                          const PopupMenuItem(value: 'realfood', child: Text('🟢 Comida Real (NOVA 1)')),
                          const PopupMenuItem(value: 'iron', child: Text('🩸 Rico en Hierro (>= 2.1 mg)')),
                          const PopupMenuItem(value: 'protein', child: Text('💪 Alto en Proteínas (>= 10g)')),
                          const PopupMenuItem(value: 'low_sugar', child: Text('🚫🍬 Bajo en Azúcar (<= 5g)')),
                          const PopupMenuItem(value: 'high_fiber', child: Text('🌾 Alto en Fibra (>= 3g)')),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _healthFilter != 'ninguno'
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _healthFilter != 'ninguno' ? colorScheme.primary : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.health_and_safety_rounded,
                                size: 16,
                                color: _healthFilter != 'ninguno' ? colorScheme.primary : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getHealthFilterLabel(),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: _healthFilter != 'ninguno' ? FontWeight.bold : FontWeight.normal,
                                  color: _healthFilter != 'ninguno' ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Desplegable Valoración ⭐
                      PopupMenuButton<double>(
                        onSelected: (val) {
                          setState(() {
                            _ratingFilter = val;
                            _refreshProducts();
                          });
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 0.0, child: Text('Cualquier valoración')),
                          const PopupMenuItem(value: 4.0, child: Text('Top 4+ ⭐')),
                          const PopupMenuItem(value: 3.0, child: Text('Top 3+ ⭐')),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _ratingFilter > 0
                                ? Colors.amber.shade100
                                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _ratingFilter > 0 ? Colors.amber : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: _ratingFilter > 0 ? Colors.amber.shade800 : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _ratingFilter > 0 ? 'Top ${_ratingFilter.toInt()}+ ⭐' : 'Valoración ⭐',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: _ratingFilter > 0 ? FontWeight.bold : FontWeight.normal,
                                  color: _ratingFilter > 0 ? Colors.amber.shade900 : colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Tira de Sugerencias de Tags Rápidos
                const SizedBox(height: 6),
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

          // Dashboard de Salud del Hogar (Collapsible)
          _buildHealthDashboardCard(),

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

                  if (_savedScrollOffset > 0) {


                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        final maxScroll = _scrollController.position.maxScrollExtent;
                        _scrollController.jumpTo(_savedScrollOffset.clamp(0.0, maxScroll));
                      }
                    });
                  }

                  if (_isGridView) {
                    return GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.68,
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
                      controller: _scrollController,
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

  Widget _buildTabFilter(String value, String label, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _tabFilter == value;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: isSelected ? colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _tabFilter = value;
              _refreshProducts();
            });
          },
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getHealthFilterLabel() {
    switch (_healthFilter) {
      case 'realfood': return 'Comida Real 🟢';
      case 'iron': return 'Rico en Hierro 🩸';
      case 'protein': return 'Alto en Proteínas 💪';
      case 'low_sugar': return 'Bajo en Azúcar 🚫🍬';
      case 'high_fiber': return 'Alto en Fibra 🌾';
      default: return 'Salud & Nutrición 🥗';
    }
  }

  Widget _buildHealthSummaryChip(String label, String filterKey) {
    final isSelected = _healthFilter == filterKey;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () {
        setState(() {
          _healthFilter = isSelected ? 'ninguno' : filterKey;
          _refreshProducts();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? colorScheme.primary : colorScheme.outlineVariant),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  void _showHealthExplanationDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.health_and_safety_rounded, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('Salud del Hogar', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🎓 Modelo Nutricional Oficial:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'El índice se calcula combinando dos estándares internacionales avalados por la OMS (Organización Mundial de la Salud) y la FAO:',
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              const Text(
                '1️⃣ Escala FSAn-NPS (Nutri-Score Oficial):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              const Text('Asigna puntos según el perfil de nutrientes (A=10 pts, B=8 pts, C=6 pts, D=4 pts, E=2 pts).'),
              const SizedBox(height: 10),
              const Text(
                '2️⃣ Clasificación NOVA (FAO / OMS):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              const Text('Valora el grado de procesamiento industrial (NOVA 1 Comida Real=10 pts, NOVA 2 Culinario=7.5 pts, NOVA 3 Procesado=5 pts, NOVA 4 Ultraprocesado=1.5 pts).'),
              const SizedBox(height: 14),
              const Text(
                '🧮 Cálculo de la Puntuación (0 a 10):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Puntuación = Media aritmética del valor Nutri-Score y NOVA de todos los productos seleccionados.\n\n• 10/10: Despensa 100% Comida Real (Nutri-Score A / NOVA 1).\n• 1.5/10: Despensa compuesta íntegramente por ultraprocesados.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '🔄 Filtro por Alcance (Toggle superior):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text('• 📦 En Stock (Predeterminado): Evalúa únicamente los productos guardados físicamente en tu despensa ahora mismo.'),
              const SizedBox(height: 4),
              const Text('• 📚 Todo el Catálogo: Evalúa el histórico completo de productos de tu hogar.'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthHeaderRow({
    required bool isExpanded,
    required int total,
    required double score,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.health_and_safety_rounded, color: Colors.green, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Salud del Hogar',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                icon: Icon(Icons.info_outline_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                tooltip: '¿Cómo se calcula?',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _showHealthExplanationDialog,
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: score >= 7.0 ? Colors.green.shade100 : Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$score/10 💚',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: score >= 7.0 ? Colors.green.shade900 : Colors.amber.shade900,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                isExpanded ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              tooltip: isExpanded ? 'Ocultar dashboard' : 'Ver dashboard',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _showHealthDashboard = !isExpanded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHealthDashboardCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!_showHealthDashboard) {
      return FutureBuilder<Map<String, dynamic>>(
        future: _healthSummaryFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final total = data?['total_products'] as int? ?? 0;
          final score = (data?['health_score'] as num? ?? 7.0).toDouble();

          return Container(
            margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Material(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => setState(() => _showHealthDashboard = true),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: _buildHealthHeaderRow(
                    isExpanded: false,
                    total: total,
                    score: score,
                    theme: theme,
                    colorScheme: colorScheme,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _healthSummaryFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!;
        final total = data['total_products'] as int? ?? 0;
        if (total == 0) return const SizedBox.shrink();

        final rfPct = (data['realfood_pct'] as num? ?? 0.0).toDouble();
        final prPct = (data['processed_pct'] as num? ?? 0.0).toDouble();
        final upPct = (data['ultraprocessed_pct'] as num? ?? 0.0).toDouble();
        final score = (data['health_score'] as num? ?? 10.0).toDouble();

        final ironCount = data['high_iron_count'] as int? ?? 0;
        final proteinCount = data['high_protein_count'] as int? ?? 0;
        final fiberCount = data['high_fiber_count'] as int? ?? 0;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer.withValues(alpha: 0.35),
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHealthHeaderRow(
                isExpanded: true,
                total: total,
                score: score,
                theme: theme,
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 8),

              // Selector de Alcance (Toggle En Stock vs Todo el Catálogo)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        if (!_healthSummaryOnlyInStock) {
                          setState(() {
                            _healthSummaryOnlyInStock = true;
                            _healthSummaryFuture = api.fetchCatalogHealthSummary(onlyInStock: true);
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _healthSummaryOnlyInStock ? colorScheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _healthSummaryOnlyInStock ? Colors.transparent : colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '📦 En Stock ($total)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _healthSummaryOnlyInStock ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        if (_healthSummaryOnlyInStock) {
                          setState(() {
                            _healthSummaryOnlyInStock = false;
                            _healthSummaryFuture = api.fetchCatalogHealthSummary(onlyInStock: false);
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: !_healthSummaryOnlyInStock ? colorScheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: !_healthSummaryOnlyInStock ? Colors.transparent : colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '📚 Todo el Catálogo',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: !_healthSummaryOnlyInStock ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Tríada Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      if (rfPct > 0) Expanded(flex: (rfPct * 10).toInt(), child: Container(color: Colors.green)),
                      if (prPct > 0) Expanded(flex: (prPct * 10).toInt(), child: Container(color: Colors.amber.shade700)),
                      if (upPct > 0) Expanded(flex: (upPct * 10).toInt(), child: Container(color: Colors.red)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('🟢 Real: ${rfPct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                  Text('🟡 Procesado: ${prPct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                  Text('🔴 Ultra: ${upPct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildHealthSummaryChip('🩸 $ironCount Hierro', 'iron'),
                    const SizedBox(width: 6),
                    _buildHealthSummaryChip('💪 $proteinCount Proteínas', 'protein'),
                    const SizedBox(width: 6),
                    _buildHealthSummaryChip('🌾 $fiberCount Fibra', 'high_fiber'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductGridCard(BuildContext context, CatalogProduct product) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        onTap: () => _openRatingModal(product),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Imagen del producto (Cabecera destacada)
              Stack(
                children: [
                  Container(
                    height: 105,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                product.imageUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.inventory_2_outlined,
                                  size: 40,
                                  color: colorScheme.primary.withValues(alpha: 0.7),
                                ),
                              ),
                            )
                          : Icon(
                              Icons.inventory_2_outlined,
                              size: 40,
                              color: colorScheme.primary.withValues(alpha: 0.7),
                            ),
                    ),
                  ),

                  // Botón Favorito Flotante
                  Positioned(
                    top: 6,
                    right: 6,
                    child: InkWell(
                      onTap: () => _toggleFavorite(product),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          product.esFavorito ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 16,
                          color: product.esFavorito ? Colors.red : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),

                  // Badge de Stock
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: product.stockActual > 0
                            ? Colors.green.shade800
                            : Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            product.stockActual > 0 ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            product.stockActual > 0 ? '${product.stockActual} disp.' : 'Sin stock',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // 2. Información del Producto (Cuerpo compacto)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Marca
                      if (product.marca != null && product.marca!.isNotEmpty)
                        Text(
                          product.marca!.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 9.5,
                            letterSpacing: 0.5,
                          ),
                        ),

                      // Nombre (2 líneas)
                      Text(
                        product.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          height: 1.15,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Insignias de Salud (NOVA, NutriScore, Micronutrientes)
                      _buildMiniHealthBadges(product),

                      // Tags si existen
                      if (product.misTags != null && product.misTags!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: product.misTags!.split(',').map((t) {
                              final tag = t.trim();
                              if (tag.isEmpty) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],

                      const Spacer(),

                      // Bar de Calificación y Acción Rápida
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 15, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                product.ratingPromedio != null
                                    ? product.ratingPromedio!.toStringAsFixed(1)
                                    : 'Sin nota',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              if (product.totalValoraciones > 0)
                                Text(
                                  ' (${product.totalValoraciones})',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 9.5,
                                  ),
                                ),
                            ],
                          ),

                          // Botón rápido de añadir a la lista de compra
                          Material(
                            color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _quickAddToShoppingList(product),
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Icon(
                                  Icons.add_shopping_cart_rounded,
                                  size: 15,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                    _buildMiniHealthBadges(product),

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

  Widget _buildMiniHealthBadges(CatalogProduct product) {
    final hasNova = product.novaGroup != null;
    final hasNutriscore = product.nutriscoreGrade != null && product.nutriscoreGrade!.isNotEmpty;

    if (!hasNova && !hasNutriscore) {
      if (product.barcode != null && product.barcode!.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: InkWell(
            onTap: () async {
              AppToast.show(context, message: 'Descargando datos nutricionales...', type: AppToastType.info);
              try {
                final res = await api.fetchCatalogProductNutrition(product.idProducto);
                if (res['status'] == 'success') {
                  if (!mounted) return;
                  AppToast.show(context, message: '¡Nutrición actualizada!', type: AppToastType.success);
                  _refreshProducts(preserveScroll: true);
                }
              } catch (e) {
                if (!mounted) return;
                AppToast.show(context, message: 'Sin información nutricional en OpenFoodFacts', type: AppToastType.error);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sync_rounded, size: 12, color: Colors.blue.shade800),
                  const SizedBox(width: 4),
                  Text(
                    'Obtener nutrición',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    String novaText = '';
    Color novaBg = Colors.grey;
    Color novaTextCol = Colors.white;

    if (hasNova) {
      switch (product.novaGroup) {
        case 1:
          novaText = '🟢 Real';
          novaBg = Colors.green.shade100;
          novaTextCol = Colors.green.shade900;
          break;
        case 2:
        case 3:
          novaText = '🟡 Procesado';
          novaBg = Colors.amber.shade100;
          novaTextCol = Colors.amber.shade900;
          break;
        default:
          novaText = '🔴 Ultraprocesado';
          novaBg = Colors.red.shade100;
          novaTextCol = Colors.red.shade900;
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 3, bottom: 3),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          if (hasNova) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: novaBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                novaText,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: novaTextCol,
                ),
              ),
            ),
          ],
          if (hasNutriscore) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: _getNutriscoreColor(product.nutriscoreGrade!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Nutri ${product.nutriscoreGrade!.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getNutriscoreColor(String grade) {
    switch (grade.toLowerCase()) {
      case 'a': return const Color(0xFF038141);
      case 'b': return const Color(0xFF85BB2F);
      case 'c': return const Color(0xFFFECB02);
      case 'd': return const Color(0xFFEE8100);
      default: return const Color(0xFFE63E11);
    }
  }
}

