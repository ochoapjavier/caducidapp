import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/models/alerta.dart';
import 'package:frontend/screens/scanner_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/utils/expiry_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late Future<List<AlertaItem>> _alertasFuture;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  Timer? _undoTimer;
  OverlayEntry? _undoOverlay;
  List<dynamic> _quickResults = [];
  bool _isSearching = false;
  Object? _quickError;
  bool _showCaducidadDetalle = false;

  @override
  void initState() {
    super.initState();
    _alertasFuture = fetchAlertas();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _undoTimer?.cancel();
    _undoOverlay?.remove();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() {
      _alertasFuture = fetchAlertas();
    });
    await _runQuickSearch(_searchController.text);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runQuickSearch(_searchController.text);
    });
  }

  Future<void> _runQuickSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      if (mounted) {
        setState(() {
          _quickResults = [];
          _isSearching = false;
          _quickError = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
        _quickError = null;
      });
    }

    try {
      final results = await fetchStockItems(searchTerm: trimmed);
      if (!mounted) return;
      setState(() {
        _quickResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _quickError = e;
        _isSearching = false;
      });
    }
  }

  Future<void> _consumeQuick(dynamic item) async {
    final stockId = item['id_stock'] as int?;
    final currentQuantity = item['cantidad_actual'] as int? ?? 0;
    final productName = item['producto_maestro']?['nombre'] as String? ?? '';

    if (stockId == null || currentQuantity <= 0) {
      return;
    }

    try {
      await removeStockItems(stockId: stockId, cantidad: 1);
      if (mounted) {
        _showUndoToast(
          message: 'Consumido 1 de $productName',
          actionLabel: currentQuantity > 1 ? 'Deshacer' : null,
          onAction: currentQuantity > 1
              ? () async {
                  try {
                    await updateStockItem(
                      stockId: stockId,
                      cantidadActual: currentQuantity,
                    );
                    if (mounted) {
                      _showUndoToast(message: 'Consumo deshecho.');
                    }
                    await refresh();
                  } catch (e) {
                    if (mounted) {
                      _showUndoToast(message: 'No se pudo deshacer: $e');
                    }
                  }
                }
              : null,
        );
      }
      await refresh();
    } catch (e) {
      if (mounted) {
        _showUndoToast(message: 'Error al consumir: $e');
      }
    }
  }

  Future<void> _consumeAlert(AlertaItem item) async {
    try {
      final currentQuantity = item.cantidad;
      await removeStockItems(stockId: item.id, cantidad: 1);
      if (mounted) {
        _showUndoToast(
          message: 'Consumido 1 de ${item.producto}',
          actionLabel: currentQuantity > 1 ? 'Deshacer' : null,
          onAction: currentQuantity > 1
              ? () async {
                  try {
                    await updateStockItem(
                      stockId: item.id,
                      cantidadActual: currentQuantity,
                    );
                    if (mounted) {
                      _showUndoToast(message: 'Consumo deshecho.');
                    }
                    await refresh();
                  } catch (e) {
                    if (mounted) {
                      _showUndoToast(message: 'No se pudo deshacer: $e');
                    }
                  }
                }
              : null,
        );
      }
      await refresh();
    } catch (e) {
      if (mounted) {
        _showUndoToast(message: 'Error al consumir: $e');
      }
    }
  }

  Future<void> _scanQuickConsume() async {
    final barcode = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (ctx) => const ScannerScreen()));
    if (barcode == null || barcode.trim().isEmpty) {
      return;
    }
    _searchController.text = barcode;
  }

  Widget _buildSectionCard({
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  void _showUndoToast({
    required String message,
    String? actionLabel,
    Future<void> Function()? onAction,
  }) {
    _undoTimer?.cancel();
    _undoOverlay?.remove();

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        final bottomInset = MediaQuery.of(context).padding.bottom;
        return Positioned(
          left: 16,
          right: 16,
          bottom: 16 + bottomInset,
          child: _UndoToastCard(
            message: message,
            actionLabel: actionLabel,
            onAction: actionLabel == null
                ? null
                : () async {
                    entry.remove();
                    _undoOverlay = null;
                    await onAction?.call();
                  },
          ),
        );
      },
    );

    _undoOverlay = entry;
    overlay.insert(entry);
    _undoTimer = Timer(const Duration(seconds: 4), () {
      entry.remove();
      _undoOverlay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final quickConsumeCard = _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Consumo rápido',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Consumo rápido'),
                      content: const Text(
                        'Busca por nombre o EAN. También puedes escanear el código para consumir en un toque.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Entendido'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline_rounded),
                tooltip: 'Info',
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o EAN',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _scanQuickConsume,
                tooltip: 'Escanear EAN',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
          ),
          const SizedBox(height: 12),
          if (_isSearching)
            const Center(child: CircularProgressIndicator())
          else if (_quickError != null)
            Text(
              'No se pudo buscar el producto.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            )
          else if (_quickResults.isEmpty)
            const SizedBox.shrink()
          else
            Column(
              children: _quickResults.take(6).map((item) {
                final name =
                    item['producto_maestro']?['nombre'] as String? ?? '';
                final quantity = item['cantidad_actual'] as int? ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'x$quantity',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed:
                            quantity > 0 ? () => _consumeQuick(item) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        tooltip: 'Consumir 1',
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );

    final caducidadesCard = _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Caducidades',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'resumen',
                    label: Text('Resumen'),
                  ),
                  ButtonSegment<String>(
                    value: 'detalle',
                    label: Text('Detalle'),
                  ),
                ],
                selected: <String>{
                  _showCaducidadDetalle ? 'detalle' : 'resumen',
                },
                onSelectionChanged: (value) {
                  setState(() {
                    _showCaducidadDetalle = value.contains('detalle');
                  });
                },
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<AlertaItem>>(
              future: _alertasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    'No se pudieron cargar las alertas.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  );
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return Text(
                    'No tienes productos próximos a caducar.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  );
                }

                Widget buildResumenList() {
                  return Scrollbar(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final statusColor = ExpiryUtils.getExpiryColor(
                          item.fechaCaducidad,
                          colorScheme,
                        );
                        return Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.producto,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'x${item.cantidad}',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _consumeAlert(item),
                              icon: const Icon(Icons.remove_circle_outline),
                              tooltip: 'Consumir 1',
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    colorScheme.primaryContainer,
                                foregroundColor:
                                    colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                }

                Widget buildDetalleList() {
                  return Scrollbar(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final expiryDate = _formatDate(item.fechaCaducidad);
                        final statusColor = ExpiryUtils.getExpiryColor(
                          item.fechaCaducidad,
                          colorScheme,
                        );
                        final statusLabel = ExpiryUtils.getStatusLabel(
                          item.fechaCaducidad,
                        );
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.producto} (x${item.cantidad})',
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ubicación: ${item.ubicacion}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Caduca: $expiryDate',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  statusLabel,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                IconButton(
                                  onPressed: () => _consumeAlert(item),
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                  ),
                                  tooltip: 'Consumir 1',
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        colorScheme.primaryContainer,
                                    foregroundColor:
                                        colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  );
                }

                return AnimatedCrossFade(
                  firstChild: buildResumenList(),
                  secondChild: buildDetalleList(),
                  crossFadeState: _showCaducidadDetalle
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 180),
                  layoutBuilder: (topChild, topKey, bottomChild, bottomKey) {
                    return Stack(
                      children: [
                        Positioned.fill(key: topKey, child: topChild),
                        Positioned.fill(key: bottomKey, child: bottomChild),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: constraints.maxHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: caducidadesCard),
                      const SizedBox(height: 16),
                      quickConsumeCard,
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _UndoToastCard extends StatelessWidget {
  const _UndoToastCard({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Material(
        elevation: 10,
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    textStyle: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
