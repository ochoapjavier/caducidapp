import 'package:flutter/material.dart';
import '../models/nutri_scan_result.dart';
import 'nutri_scan_card.dart';

class SupermarketCompareDrawer extends StatefulWidget {
  final List<NutriScanResult> history;
  final VoidCallback onScanNext;
  final Function(NutriScanResult)? onAddToList;
  final Function(NutriScanResult)? onSaveToCatalog;

  const SupermarketCompareDrawer({
    super.key,
    required this.history,
    required this.onScanNext,
    this.onAddToList,
    this.onSaveToCatalog,
  });

  @override
  State<SupermarketCompareDrawer> createState() => _SupermarketCompareDrawerState();
}

class _SupermarketCompareDrawerState extends State<SupermarketCompareDrawer> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final history = widget.history;

    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentProduct = history[_selectedIndex.clamp(0, history.length - 1)];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Indicador de Arrastre
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Barra de Productos Escaneados en Sesión (si hay más de 1)
        if (history.length > 1) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.compare_arrows_rounded, size: 18, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Comparar Escaneados (${history.length}):',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedIndex;
                final prod = history[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(
                      prod.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(height: 12),
        ],

        // Ficha del producto seleccionado
        Flexible(
          child: NutriScanCard(
            result: currentProduct,
            onScanNext: widget.onScanNext,
            onAddToList: widget.onAddToList != null
                ? () => widget.onAddToList!(currentProduct)
                : null,
            onSaveToCatalog: widget.onSaveToCatalog != null
                ? () => widget.onSaveToCatalog!(currentProduct)
                : null,
          ),
        ),
      ],
    );
  }
}
