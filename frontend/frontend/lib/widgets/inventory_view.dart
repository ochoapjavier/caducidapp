// frontend/lib/widgets/inventory_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/scanner_screen.dart';
import 'package:frontend/utils/expiry_utils.dart'; // Utilidades centralizadas para lógica de caducidad
import 'package:frontend/utils/error_handler.dart';
import 'package:frontend/widgets/quantity_selection_dialog.dart';
import 'package:frontend/services/shopping_service.dart';
import 'package:frontend/services/hogar_service.dart';
import 'package:frontend/widgets/error_view.dart';

// Eliminado _isLoading (no se usaba)

class InventoryView extends StatefulWidget {
  final VoidCallback? onTicketAction;
  final VoidCallback? onAddItem;
  final VoidCallback? onRemoveItem;

  const InventoryView({
    super.key,
    this.onTicketAction,
    this.onAddItem,
    this.onRemoveItem,
  });

  @override
  State<InventoryView> createState() => InventoryViewState(); // Clave pública
}

class _InventoryFocusRestore {
  const _InventoryFocusRestore({
    required this.fallbackOffset,
    this.preferredStockIds = const [],
  });

  final double? fallbackOffset;
  final List<int> preferredStockIds;
  static const double alignment = 0.35;
}

class _InventoryCompactActionButton extends StatelessWidget {
  const _InventoryCompactActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.expand = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 38,
        width: expand ? null : 38,
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Icon(icon, size: 18, color: foregroundColor),
          ),
        ),
      ),
    );
  }
}

class _InventoryActionCluster extends StatelessWidget {
  const _InventoryActionCluster({
    this.onTicketAction,
    this.onAddItem,
    this.onRemoveItem,
    this.compact = false,
    this.expand = false,
    this.showTicketLabel = true,
  });

  final VoidCallback? onTicketAction;
  final VoidCallback? onAddItem;
  final VoidCallback? onRemoveItem;
  final bool compact;
  final bool expand;
  final bool showTicketLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (compact) {
      final children = <Widget>[];

      void addButton(Widget button) {
        if (children.isNotEmpty) {
          children.add(const SizedBox(width: 4));
        }
        children.add(expand ? Expanded(child: button) : button);
      }

      if (onTicketAction != null) {
        addButton(
          _InventoryCompactActionButton(
            icon: Icons.receipt_long_rounded,
            tooltip: 'Ticket',
            onPressed: onTicketAction,
            backgroundColor: colorScheme.tertiaryContainer,
            foregroundColor: colorScheme.onTertiaryContainer,
            expand: expand,
          ),
        );
      }

      if (onAddItem != null) {
        addButton(
          _InventoryCompactActionButton(
            icon: Icons.add_rounded,
            tooltip: 'Añadir',
            onPressed: onAddItem,
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            expand: expand,
          ),
        );
      }

      if (onRemoveItem != null) {
        addButton(
          _InventoryCompactActionButton(
            icon: Icons.remove_rounded,
            tooltip: 'Quitar',
            onPressed: onRemoveItem,
            backgroundColor: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
            expand: expand,
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.75),
          ),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: children,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.75),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onTicketAction != null)
            showTicketLabel
                ? FilledButton.tonalIcon(
                    onPressed: onTicketAction,
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text('Ticket'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  )
                : IconButton(
                    onPressed: onTicketAction,
                    tooltip: 'Ticket',
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(38, 38),
                      backgroundColor: colorScheme.tertiaryContainer,
                      foregroundColor: colorScheme.onTertiaryContainer,
                    ),
                  ),
          if (onTicketAction != null &&
              (onAddItem != null || onRemoveItem != null)) ...[
            const SizedBox(width: 4),
            Container(width: 1, height: 24, color: colorScheme.outlineVariant),
            const SizedBox(width: 4),
          ],
          if (onAddItem != null)
            IconButton(
              onPressed: onAddItem,
              tooltip: 'Añadir',
              icon: const Icon(Icons.add_rounded),
              style: IconButton.styleFrom(
                minimumSize: const Size(38, 38),
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
              ),
            ),
          if (onAddItem != null && onRemoveItem != null)
            const SizedBox(width: 4),
          if (onRemoveItem != null)
            IconButton(
              onPressed: onRemoveItem,
              tooltip: 'Quitar',
              icon: const Icon(Icons.remove_rounded),
              style: IconButton.styleFrom(
                minimumSize: const Size(38, 38),
                backgroundColor: colorScheme.secondaryContainer,
                foregroundColor: colorScheme.onSecondaryContainer,
              ),
            ),
        ],
      ),
    );
  }
}

class _InventoryToolbarButton extends StatelessWidget {
  const _InventoryToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.trailing,
    this.badgeCount,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final IconData? trailing;
  final int? badgeCount;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 42,
      child: Material(
        color: isActive
            ? colorScheme.secondaryContainer.withValues(alpha: 0.8)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? colorScheme.secondary.withValues(alpha: 0.35)
                    : colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (badgeCount != null && badgeCount! > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    trailing,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryMetaPill extends StatelessWidget {
  const _InventoryMetaPill({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.borderColor,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color? borderColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final content = Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor ?? Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            softWrap: false,
            style: textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: content,
      ),
    );
  }
}

class _InventoryMetaGroup extends StatelessWidget {
  const _InventoryMetaGroup({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: accentColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...[
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              children[index],
            ],
          ],
        ],
      ),
    );
  }
}

class _InventoryItemAction {
  const _InventoryItemAction({
    required this.icon,
    required this.label,
    required this.description,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
}

class _InventoryItemActionButton extends StatelessWidget {
  const _InventoryItemActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.expand = false,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool expand;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: expand ? double.infinity : null,
      height: isPrimary ? 48 : 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isPrimary ? 16 : 14,
              vertical: isPrimary ? 12 : 10,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: foregroundColor.withValues(alpha: isPrimary ? 0.16 : 0.10),
              ),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: foregroundColor.withValues(alpha: 0.10),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Icon(icon, size: isPrimary ? 18 : 17, color: foregroundColor),
                const SizedBox(width: 8),
                if (expand)
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: textTheme.labelLarge?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: 0.1,
                      ),
                    ),
                  )
                else
                  Text(
                    label,
                    style: textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: 0.1,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryItemActionBar extends StatelessWidget {
  const _InventoryItemActionBar({
    required this.primaryAction,
    this.secondaryAction,
    this.onMorePressed,
    this.compact = false,
  });

  final _InventoryItemAction primaryAction;
  final _InventoryItemAction? secondaryAction;
  final VoidCallback? onMorePressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget buildMoreButton({required bool expand}) {
      return _InventoryItemActionButton(
        icon: Icons.more_horiz_rounded,
        label: expand ? 'Más acciones' : 'Más',
        onPressed: onMorePressed!,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurfaceVariant,
        expand: expand,
      );
    }

    if (compact) {
      final footerRowChildren = <Widget>[];

      if (secondaryAction != null) {
        footerRowChildren.add(
          Expanded(
            child: _InventoryItemActionButton(
              icon: secondaryAction!.icon,
              label: secondaryAction!.label,
              onPressed: secondaryAction!.onPressed,
              backgroundColor: secondaryAction!.backgroundColor,
              foregroundColor: secondaryAction!.foregroundColor,
              expand: true,
            ),
          ),
        );
      }

      if (onMorePressed != null) {
        if (footerRowChildren.isNotEmpty) {
          footerRowChildren.add(const SizedBox(width: 8));
        }
        footerRowChildren.add(
          Expanded(
            child: buildMoreButton(expand: true),
          ),
        );
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InventoryItemActionButton(
              icon: primaryAction.icon,
              label: primaryAction.label,
              onPressed: primaryAction.onPressed,
              backgroundColor: primaryAction.backgroundColor,
              foregroundColor: primaryAction.foregroundColor,
              expand: true,
              isPrimary: true,
            ),
            if (footerRowChildren.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: footerRowChildren),
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: secondaryAction == null && onMorePressed == null ? 1 : 3,
            child: _InventoryItemActionButton(
              icon: primaryAction.icon,
              label: primaryAction.label,
              onPressed: primaryAction.onPressed,
              backgroundColor: primaryAction.backgroundColor,
              foregroundColor: primaryAction.foregroundColor,
              expand: true,
              isPrimary: true,
            ),
          ),
          if (secondaryAction != null) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _InventoryItemActionButton(
                icon: secondaryAction!.icon,
                label: secondaryAction!.label,
                onPressed: secondaryAction!.onPressed,
                backgroundColor: secondaryAction!.backgroundColor,
                foregroundColor: secondaryAction!.foregroundColor,
                expand: true,
              ),
            ),
          ],
          if (onMorePressed != null) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: buildMoreButton(
                expand: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class InventoryViewState extends State<InventoryView> {
  late Future<List<dynamic>> _stockItemsFuture;
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};
  Timer? _debounce;
  List<dynamic> _lastVisibleItems = const [];
  _InventoryFocusRestore? _pendingFocusRestore;

  final List<String> _selectedFilters = [];
  String _sortBy = 'expiry_asc';
  bool _showFilters = false;
  bool _isHeaderCollapsed = false;

  String _formatInventoryDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  bool _isFreezerLocation(dynamic locationData) {
    if (locationData is! Map) {
      return false;
    }

    return locationData['es_congelador'] == true ||
        locationData['esCongelador'] == true;
  }

  DateTime? _getStateReferenceDate(dynamic item, String estadoProducto) {
    final rawDate = switch (estadoProducto) {
      'abierto' => item['fecha_apertura'],
      'congelado' => item['fecha_congelacion'],
      'descongelado' => item['fecha_descongelacion'],
      _ => null,
    };

    if (rawDate is! String || rawDate.isEmpty) {
      return null;
    }

    return DateTime.tryParse(rawDate);
  }

  String? _getStateReferenceLabel(String estadoProducto) {
    return switch (estadoProducto) {
      'abierto' => 'Abierto',
      'congelado' => 'Congelado',
      'descongelado' => 'Descongelado',
      _ => null,
    };
  }

  @override
  void initState() {
    super.initState();
    _stockItemsFuture = fetchStockItems(sortBy: _sortBy);
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
    if (mounted) {
      setState(() {});
    }
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      refreshInventory();
    });
  }

  void _scanBarcode() async {
    final barcode = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (ctx) => const ScannerScreen()));
    if (barcode != null && barcode.isNotEmpty) {
      _searchController.text = barcode;
    }
  }

  Future<void> _dismissKeyboardIfNeeded() async {
    final hadFocus = FocusManager.instance.primaryFocus != null;
    FocusManager.instance.primaryFocus?.unfocus();
    if (hadFocus) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<void> _showItemActionsSheet({
    required String productName,
    required List<_InventoryItemAction> actions,
  }) async {
    if (actions.isEmpty) {
      return;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Más acciones',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ...[
                for (var index = 0; index < actions.length; index++) ...[
                  if (index > 0) const SizedBox(height: 10),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        Future<void>.delayed(Duration.zero, () {
                          actions[index].onPressed();
                        });
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: actions[index].backgroundColor.withValues(
                            alpha: 0.58,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: actions[index].foregroundColor.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: actions[index].foregroundColor
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                actions[index].icon,
                                size: 18,
                                color: actions[index].foregroundColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    actions[index].label,
                                    style: textTheme.titleSmall?.copyWith(
                                      color: actions[index].foregroundColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    actions[index].description,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: actions[index].foregroundColor
                                          .withValues(alpha: 0.88),
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: actions[index].foregroundColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTicketAction() async {
    if (widget.onTicketAction == null) {
      return;
    }

    await _dismissKeyboardIfNeeded();
    if (!mounted) {
      return;
    }

    widget.onTicketAction?.call();
  }

  void _restoreScrollOffset(double? offset) {
    if (offset == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      final targetOffset = offset.clamp(0.0, maxScrollExtent);
      if ((_scrollController.offset - targetOffset).abs() < 1) {
        return;
      }

      _scrollController.jumpTo(targetOffset);
    });
  }

  List<dynamic> _flattenInventoryItems(List<dynamic> items) {
    final groupedItems = <String, List<dynamic>>{};
    for (final item in items) {
      final locationName = item['ubicacion']['nombre'] as String;
      groupedItems.putIfAbsent(locationName, () => []).add(item);
    }

    final locationKeys = groupedItems.keys.toList()..sort();
    return [
      for (final locationName in locationKeys) ...groupedItems[locationName]!,
    ];
  }

  void _cacheVisibleItems(List<dynamic> items) {
    _lastVisibleItems = _flattenInventoryItems(items);
    final visibleIds = _lastVisibleItems
        .map<int?>((item) => item['id_stock'] as int?)
        .whereType<int>()
        .toSet();
    _itemKeys.removeWhere((stockId, _) => !visibleIds.contains(stockId));
  }

  GlobalKey _getItemKey(int stockId) {
    return _itemKeys.putIfAbsent(stockId, GlobalKey.new);
  }

  _InventoryFocusRestore _buildRemovalFocusRestore({
    required int stockId,
    required int removedQuantity,
    required int currentQuantity,
  }) {
    final fallbackOffset = _scrollController.hasClients
        ? _scrollController.offset
        : null;
    final currentIndex = _lastVisibleItems.indexWhere(
      (item) => item['id_stock'] == stockId,
    );

    if (currentIndex == -1) {
      return _InventoryFocusRestore(
        fallbackOffset: fallbackOffset,
        preferredStockIds: removedQuantity < currentQuantity
            ? [stockId]
            : const [],
      );
    }

    final preferredStockIds = <int>[];
    if (removedQuantity < currentQuantity) {
      preferredStockIds.add(stockId);
    } else {
      if (currentIndex + 1 < _lastVisibleItems.length) {
        preferredStockIds.add(
          _lastVisibleItems[currentIndex + 1]['id_stock'] as int,
        );
      }
      if (currentIndex > 0) {
        preferredStockIds.add(
          _lastVisibleItems[currentIndex - 1]['id_stock'] as int,
        );
      }
    }

    return _InventoryFocusRestore(
      fallbackOffset: fallbackOffset,
      preferredStockIds: preferredStockIds,
    );
  }

  void _restoreViewport(_InventoryFocusRestore? focusRestore) {
    if (focusRestore == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      for (final stockId in focusRestore.preferredStockIds) {
        final targetContext = _itemKeys[stockId]?.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: _InventoryFocusRestore.alignment,
          );
          return;
        }
      }

      _restoreScrollOffset(focusRestore.fallbackOffset);
    });
  }

  // Hacemos el método público para poder llamarlo desde el widget padre
  Future<void> refreshInventory({bool preserveScrollOffset = false}) async {
    final focusRestore =
        _pendingFocusRestore ??
        (preserveScrollOffset
            ? _InventoryFocusRestore(
                fallbackOffset: _scrollController.hasClients
                    ? _scrollController.offset
                    : null,
              )
            : null);
    _pendingFocusRestore = null;
    final nextFuture = fetchStockItems(
      searchTerm: _searchController.text,
      statusFilter: _selectedFilters,
      sortBy: _sortBy,
    );

    setState(() {
      _stockItemsFuture = nextFuture;
    });

    try {
      final items = await nextFuture;
      _cacheVisibleItems(items);
      _restoreViewport(focusRestore);
    } catch (_) {
      // el FutureBuilder mostrará el error
    }
  }

  // Método _consumeItem eliminado (no usado tras rediseño)

  /// Muestra un diálogo para confirmar y especificar la cantidad a eliminar.
  /// Método público para poder ser invocado desde otras vistas (ej: Alertas)
  void showRemoveQuantityDialog(
    int stockId,
    int currentQuantity,
    String productName,
    int? productId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => QuantitySelectionDialog(
        title: 'Eliminar "$productName"',
        subtitle: 'Disponibles: $currentQuantity',
        maxQuantity: currentQuantity,
        onConfirm: (quantity, addToShoppingList) async {
          final focusRestore = _buildRemovalFocusRestore(
            stockId: stockId,
            removedQuantity: quantity,
            currentQuantity: currentQuantity,
          );

          try {
            // 1. Eliminar del stock
            await removeStockItems(stockId: stockId, cantidad: quantity);

            // 2. Añadir a lista de compra si se solicitó
            if (addToShoppingList) {
              try {
                final hogarId = await HogarService().getHogarActivo();
                if (hogarId != null) {
                  await ShoppingService().addItem(
                    hogarId,
                    productName,
                    fkProducto: productId,
                  );
                }
              } catch (e) {
                debugPrint('Error adding to shopping list: $e');
              }
            }

            // 3. Refrescar inventario
            _pendingFocusRestore = focusRestore;
            await refreshInventory(preserveScrollOffset: true);

            // 4. Notificar
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    addToShoppingList
                        ? 'Eliminado y añadido a la lista.'
                        : 'Producto eliminado.',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ErrorHandler.showError(context, e);
            }
          }
        },
      ),
    );
  }

  // ============================================================================
  // DIÁLOGOS PARA ACCIONES DE ESTADO DE PRODUCTO
  // ============================================================================

  /// Diálogo para abrir un producto cerrado
  Future<void> _showOpenProductDialog(dynamic item) async {
    final stockId = item['id_stock'];
    final productName = item['producto_maestro']['nombre'];
    final currentQuantity = item['cantidad_actual'];
    final int? defaultDiasConsumo =
        item['producto_maestro']['dias_consumo_abierto'];

    int quantity = 1;
    // Si hay un valor por defecto, lo usamos y desactivamos "mantener fecha" por defecto.
    // Si no, usamos 4 días y mantenemos la fecha original por defecto.
    int diasVidaUtil = defaultDiasConsumo ?? 4;
    bool mantenerFechaCaducidad = defaultDiasConsumo == null;

    int? selectedLocationId;

    final colorScheme = Theme.of(context).colorScheme;

    // Obtener ubicaciones para el dropdown
    final locations = await fetchUbicaciones();

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Abrir "$productName"'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Disponible: $currentQuantity unidades',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                // Spinner para cantidad
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cantidad a abrir',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: quantity > 1
                          ? () => setStateDialog(() => quantity--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: colorScheme.primary,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$quantity',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: quantity < currentQuantity
                          ? () => setStateDialog(() => quantity++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      color: colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Nueva ubicación (opcional)',
                    helperText: 'Ej: mover de despensa a nevera',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedLocationId,
                  items: locations
                      .map(
                        (loc) => DropdownMenuItem<int>(
                          value: loc.id,
                          child: Text(loc.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setStateDialog(() => selectedLocationId = value),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mantener fecha de caducidad original'),
                  subtitle: Text(
                    mantenerFechaCaducidad
                        ? 'La fecha no cambiará al abrir'
                        : 'Se recalculará según días de vida útil',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: mantenerFechaCaducidad,
                  onChanged: (value) =>
                      setStateDialog(() => mantenerFechaCaducidad = value),
                ),
                // Campo de días solo si NO mantiene fecha
                if (!mantenerFechaCaducidad) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Días de vida útil',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        onPressed: diasVidaUtil > 1
                            ? () => setStateDialog(() => diasVidaUtil--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: colorScheme.primary,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$diasVidaUtil',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: diasVidaUtil < 30
                            ? () => setStateDialog(() => diasVidaUtil++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                  Text(
                    'Nueva fecha: ${DateTime.now().add(Duration(days: diasVidaUtil)).day}/${DateTime.now().add(Duration(days: diasVidaUtil)).month}/${DateTime.now().add(Duration(days: diasVidaUtil)).year}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          defaultDiasConsumo != null &&
                                  defaultDiasConsumo == diasVidaUtil
                              ? 'Usando tu preferencia guardada para este producto.'
                              : 'Este valor se guardará como preferencia para la próxima vez.',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Abrir'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        if (quantity <= 0 || quantity > currentQuantity) {
          throw Exception('Cantidad inválida');
        }

        await openProduct(
          stockId: stockId,
          cantidad: quantity,
          nuevaUbicacionId: selectedLocationId,
          mantenerFechaCaducidad: mantenerFechaCaducidad,
          diasVidaUtil: diasVidaUtil,
        );

        await refreshInventory(preserveScrollOffset: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Producto abierto correctamente'),
              backgroundColor: colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.showError(context, e);
        }
      }
    }
  }

  /// Diálogo para congelar un producto
  Future<void> _showFreezeProductDialog(dynamic item) async {
    final stockId = item['id_stock'];
    final productName = item['producto_maestro']['nombre'];
    final currentQuantity = item['cantidad_actual'];
    final estadoProducto = item['estado_producto'] ?? 'cerrado';

    int quantity = currentQuantity;
    int? freezerLocationId;

    final colorScheme = Theme.of(context).colorScheme;

    // Obtener ubicaciones y filtrar solo las que son congeladores
    final allLocations = await fetchUbicaciones();
    final locations = allLocations.where((loc) => loc.esCongelador).toList();

    if (!mounted) return;

    // Validar que existen ubicaciones de tipo congelador
    if (locations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No tienes ubicaciones de tipo congelador. Crea una primero en la pantalla de Ubicaciones.',
          ),
          backgroundColor: colorScheme.error,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Congelar "$productName"'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Disponible: $currentQuantity unidades',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                // Advertencia si es producto descongelado
                if (estadoProducto.toLowerCase() == 'descongelado') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(
                        color: Colors.orange.shade700,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '⚠️ No se recomienda re-congelar productos ya descongelados por seguridad alimentaria.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'Al congelar, el producto dejará de aparecer en las alertas de caducidad.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                // Spinner para cantidad
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cantidad a congelar',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: quantity > 1
                          ? () => setStateDialog(() => quantity--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: colorScheme.primary,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$quantity',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: quantity < currentQuantity
                          ? () => setStateDialog(() => quantity++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      color: colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Ubicación del congelador *',
                    border: OutlineInputBorder(),
                  ),
                  value: freezerLocationId,
                  items: locations
                      .map(
                        (loc) => DropdownMenuItem<int>(
                          value: loc.id,
                          child: Text(loc.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setStateDialog(() => freezerLocationId = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: freezerLocationId == null
                  ? null
                  : () => Navigator.of(ctx).pop(true),
              child: const Text('Congelar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && freezerLocationId != null) {
      try {
        if (quantity <= 0 || quantity > currentQuantity) {
          throw Exception('Cantidad inválida');
        }

        await freezeProduct(
          stockId: stockId,
          cantidad: quantity,
          ubicacionCongeladorId: freezerLocationId!,
        );

        await refreshInventory(preserveScrollOffset: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Producto congelado correctamente'),
              backgroundColor: colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.showError(context, e);
        }
      }
    }
  }

  /// Diálogo para descongelar un producto
  Future<void> _showUnfreezeProductDialog(dynamic item) async {
    final stockId = item['id_stock'];
    final productName = item['producto_maestro']['nombre'];
    final currentQuantity = item['cantidad_actual'] as int;

    int? newLocationId;
    int diasVidaUtil = 2;
    int quantity = 1; // Cantidad a descongelar

    final colorScheme = Theme.of(context).colorScheme;

    // Obtener ubicaciones y filtrar solo las que NO son congeladores
    final allLocations = await fetchUbicaciones();
    final locations = allLocations.where((loc) => !loc.esCongelador).toList();

    // Validar que existen ubicaciones que no son congelador
    if (locations.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No tienes ubicaciones normales (no congelador) para descongelar. Crea una primero en la pantalla de Ubicaciones.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Descongelar "$productName"'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Al descongelar, se recomienda consumir el producto en pocos días.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                // Selector de cantidad
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cantidad a descongelar',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: quantity > 1
                          ? () => setStateDialog(() => quantity--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: colorScheme.primary,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$quantity',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: quantity < currentQuantity
                          ? () => setStateDialog(() => quantity++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      color: colorScheme.primary,
                    ),
                  ],
                ),
                Text(
                  'Disponible: $currentQuantity unidades',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Nueva ubicación (no congelador) *',
                    helperText: 'Ej: Nevera, Despensa',
                    border: OutlineInputBorder(),
                  ),
                  value: newLocationId,
                  items: locations
                      .map(
                        (loc) => DropdownMenuItem<int>(
                          value: loc.id,
                          child: Text(loc.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setStateDialog(() => newLocationId = value),
                ),
                const SizedBox(height: 16),
                // Spinner para días
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Días para consumir',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: diasVidaUtil > 1
                          ? () => setStateDialog(() => diasVidaUtil--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: colorScheme.primary,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$diasVidaUtil',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: diasVidaUtil < 7
                          ? () => setStateDialog(() => diasVidaUtil++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      color: colorScheme.primary,
                    ),
                  ],
                ),
                Text(
                  'Nueva fecha: ${DateTime.now().add(Duration(days: diasVidaUtil)).day}/${DateTime.now().add(Duration(days: diasVidaUtil)).month}/${DateTime.now().add(Duration(days: diasVidaUtil)).year}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: newLocationId == null
                  ? null
                  : () => Navigator.of(ctx).pop(true),
              child: const Text('Descongelar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && newLocationId != null) {
      try {
        if (diasVidaUtil <= 0 || diasVidaUtil > 7) {
          throw Exception('Días inválidos (1-7)');
        }

        if (quantity <= 0 || quantity > currentQuantity) {
          throw Exception('Cantidad inválida');
        }

        await unfreezeProduct(
          stockId: stockId,
          cantidad: quantity,
          nuevaUbicacionId: newLocationId!,
          diasVidaUtil: diasVidaUtil,
        );

        await refreshInventory(preserveScrollOffset: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Producto descongelado correctamente'),
              backgroundColor: colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.showError(context, e);
        }
      }
    }
  }

  /// Diálogo para reubicar un producto
  Future<void> _showRelocateProductDialog(dynamic item) async {
    final stockId = item['id_stock'];
    final productName = item['producto_maestro']['nombre'];
    final currentLocationName = item['ubicacion']['nombre'];
    final currentQuantity = item['cantidad_actual'];

    int? newLocationId;
    int quantity = 1;

    final colorScheme = Theme.of(context).colorScheme;

    // Obtener ubicaciones
    final locations = await fetchUbicaciones();

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Reubicar "$productName"'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ubicación actual: $currentLocationName',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Unidades disponibles: $currentQuantity',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Spinner para cantidad a reubicar
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cantidad a reubicar',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: quantity > 1
                          ? () => setStateDialog(() => quantity--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: colorScheme.primary,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$quantity',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: quantity < currentQuantity
                          ? () => setStateDialog(() => quantity++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      color: colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Nueva ubicación *',
                    border: OutlineInputBorder(),
                  ),
                  value: newLocationId,
                  items: locations
                      .map(
                        (loc) => DropdownMenuItem<int>(
                          value: loc.id,
                          child: Text(loc.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setStateDialog(() => newLocationId = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: newLocationId == null
                  ? null
                  : () => Navigator.of(ctx).pop(true),
              child: const Text('Reubicar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && newLocationId != null) {
      try {
        await relocateProduct(
          stockId: stockId,
          cantidad: quantity,
          nuevaUbicacionId: newLocationId!,
        );

        await refreshInventory(preserveScrollOffset: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Producto reubicado correctamente'),
              backgroundColor: colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.showError(context, e);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final effectiveShowFilters = _showFilters && !keyboardVisible;

    Widget buildHeaderContent(BoxConstraints constraints) {
      final isCompact = constraints.maxWidth < 720;
      final hasActions =
          widget.onTicketAction != null ||
          widget.onAddItem != null ||
          widget.onRemoveItem != null;
      final compactActionCluster = _InventoryActionCluster(
        onTicketAction: widget.onTicketAction == null
            ? null
            : _handleTicketAction,
        onAddItem: widget.onAddItem,
        onRemoveItem: widget.onRemoveItem,
        compact: true,
        expand: false,
      );

      final searchField = TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, marca o EAN',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                  tooltip: 'Limpiar búsqueda',
                ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _scanBarcode,
                tooltip: 'Escanear',
              ),
            ],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 11,
          ),
        ),
      );

      final sortButton = PopupMenuButton<String>(
        tooltip: 'Ordenar por',
        initialValue: _sortBy,
        onSelected: (value) {
          setState(() {
            _sortBy = value;
          });
          refreshInventory();
        },
        itemBuilder: (context) => [
          CheckedPopupMenuItem(
            value: 'expiry_asc',
            checked: _sortBy == 'expiry_asc',
            child: const Text('📅 Caducidad (Próxima)'),
          ),
          CheckedPopupMenuItem(
            value: 'expiry_desc',
            checked: _sortBy == 'expiry_desc',
            child: const Text('📅 Caducidad (Lejana)'),
          ),
          CheckedPopupMenuItem(
            value: 'name_asc',
            checked: _sortBy == 'name_asc',
            child: const Text('🔤 Nombre (A-Z)'),
          ),
          CheckedPopupMenuItem(
            value: 'quantity_desc',
            checked: _sortBy == 'quantity_desc',
            child: const Text('🔢 Cantidad (Mayor)'),
          ),
        ],
        child: _InventoryToolbarButton(
          icon: Icons.sort_rounded,
          label: 'Ordenar',
          trailing: isCompact ? null : Icons.expand_more,
          onPressed: null,
        ),
      );

      final filterButton = _InventoryToolbarButton(
        onPressed: () => setState(() => _showFilters = !_showFilters),
        icon: effectiveShowFilters
            ? Icons.tune_rounded
            : Icons.filter_list_rounded,
        label: 'Filtros',
        badgeCount: _selectedFilters.isEmpty ? null : _selectedFilters.length,
        isActive: effectiveShowFilters || _selectedFilters.isNotEmpty,
        trailing: !isCompact && effectiveShowFilters
            ? Icons.expand_less_rounded
            : null,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: sortButton),
              const SizedBox(width: 8),
              Expanded(child: filterButton),
              if (hasActions) ...[
                const SizedBox(width: 8),
                compactActionCluster,
              ],
              const SizedBox(width: 8),
              Tooltip(
                message: _isHeaderCollapsed
                    ? 'Expandir cabecera'
                    : 'Contraer cabecera',
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _isHeaderCollapsed = !_isHeaderCollapsed;
                    });
                  },
                  icon: Icon(
                    _isHeaderCollapsed
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surface,
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (!_isHeaderCollapsed) ...[
            const SizedBox(height: 8),
            searchField,
          ],
        ],
      );
    }

    return Column(
      children: [
        // 1. Buscador y accesos de filtrado
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return buildHeaderContent(constraints);
                },
              ),
            ),
          ),
        ),

        // 2. Filtros y Ordenación (Chips + Sort)
        AnimatedCrossFade(
          crossFadeState: effectiveShowFilters && !_isHeaderCollapsed
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          firstChild: Container(height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // Chips de Filtro
                  FilterChip(
                    label: Icon(
                      Icons.ac_unit,
                      size: 20,
                      color: _selectedFilters.contains('congelado')
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Congelado',
                    selected: _selectedFilters.contains('congelado'),
                    showCheckmark: false,
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    selectedColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? _selectedFilters.add('congelado')
                            : _selectedFilters.remove('congelado');
                      });
                      refreshInventory();
                    },
                  ),
                  FilterChip(
                    label: Icon(
                      Icons.lock_open,
                      size: 20,
                      color: _selectedFilters.contains('abierto')
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Abierto',
                    selected: _selectedFilters.contains('abierto'),
                    showCheckmark: false,
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    selectedColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? _selectedFilters.add('abierto')
                            : _selectedFilters.remove('abierto');
                      });
                      refreshInventory();
                    },
                  ),
                  FilterChip(
                    label: Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: _selectedFilters.contains('por_caducar')
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Próximo a caducar',
                    selected: _selectedFilters.contains('por_caducar'),
                    showCheckmark: false,
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    selectedColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? _selectedFilters.add('por_caducar')
                            : _selectedFilters.remove('por_caducar');
                      });
                      refreshInventory();
                    },
                  ),
                  FilterChip(
                    label: Icon(
                      Icons.report_problem,
                      size: 20,
                      color: _selectedFilters.contains('urgente')
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Urgente',
                    selected: _selectedFilters.contains('urgente'),
                    showCheckmark: false,
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    selectedColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? _selectedFilters.add('urgente')
                            : _selectedFilters.remove('urgente');
                      });
                      refreshInventory();
                    },
                  ),
                  FilterChip(
                    label: Icon(
                      Icons.dangerous,
                      size: 20,
                      color: _selectedFilters.contains('caducado')
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Caducado',
                    selected: _selectedFilters.contains('caducado'),
                    showCheckmark: false,
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    selectedColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? _selectedFilters.add('caducado')
                            : _selectedFilters.remove('caducado');
                      });
                      refreshInventory();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        const Divider(height: 1),

        // 3. Lista de Resultados
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _stockItemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ErrorView(
                  error: snapshot.error!,
                  onRetry: () {
                    refreshInventory();
                  },
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                _cacheVisibleItems(const []);
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No se encontraron productos',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                      if (_selectedFilters.isNotEmpty ||
                          _searchController.text.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _selectedFilters.clear();
                            });
                            refreshInventory();
                          },
                          child: const Text('Limpiar filtros'),
                        ),
                    ],
                  ),
                );
              }

              _cacheVisibleItems(snapshot.data!);

              // --- INICIO DE LA LÓGICA DE AGRUPACIÓN ---
              final Map<String, List<dynamic>> groupedItems = {};
              for (var item in snapshot.data!) {
                final locationName = item['ubicacion']['nombre'] as String;
                if (!groupedItems.containsKey(locationName)) {
                  groupedItems[locationName] = [];
                }
                groupedItems[locationName]!.add(item);
              }
              final locationKeys = groupedItems.keys.toList()..sort();
              // --- FIN DE LA LÓGICA DE AGRUPACIÓN ---

              return RefreshIndicator(
                onRefresh: () async {
                  await refreshInventory(preserveScrollOffset: true);
                },
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(8, 8, 8, 12 + bottomInset),
                  itemCount: locationKeys.length,
                  itemBuilder: (context, index) {
                    final locationName = locationKeys[index];
                    final itemsInLocation = groupedItems[locationName]!;
                    final locationData = itemsInLocation.first['ubicacion'];
                    final isFreezerLocation = _isFreezerLocation(locationData);
                    final locationIcon = isFreezerLocation
                      ? Icons.ac_unit_rounded
                      : Icons.location_on_outlined;
                    final locationIconColor = isFreezerLocation
                      ? Colors.blue.shade700
                      : colorScheme.primary;
                    final locationIconBackground = isFreezerLocation
                      ? Colors.blue.shade50
                      : colorScheme.primaryContainer.withValues(alpha: 0.75);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.75,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withValues(alpha: 0.05),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            key: PageStorageKey(locationName),
                            tilePadding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                            childrenPadding: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            collapsedShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: locationIconBackground,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                locationIcon,
                                color: locationIconColor,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          locationName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            height: 1.1,
                                          ),
                                        ),
                                      ),
                                      if (isFreezerLocation) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(
                                              color: Colors.blue.shade100,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.ac_unit_rounded,
                                                size: 13,
                                                color: Colors.blue.shade700,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Congelador',
                                                style: textTheme.labelSmall?.copyWith(
                                                  color: Colors.blue.shade900,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                  child: Text(
                                    itemsInLocation.length == 1
                                        ? '1 producto'
                                        : '${itemsInLocation.length} productos',
                                    style: textTheme.labelMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            initiallyExpanded: true,
                            children: itemsInLocation.asMap().entries.map((
                              entry,
                            ) {
                              final i = entry.key;
                              final item = entry.value;
                              final productName =
                                  item['producto_maestro']['nombre'];
                              final brand = item['producto_maestro']['marca'];
                              final quantity = item['cantidad_actual'];
                              final imageUrl =
                                  item['producto_maestro']['image_url'];
                              final expiryDate = DateTime.parse(
                                item['fecha_caducidad'],
                              );
                              final stockId = item['id_stock'];
                              final estadoProducto =
                                  item['estado_producto'] ?? 'cerrado';

                              final expiryColor = ExpiryUtils.getExpiryColor(
                                expiryDate,
                                colorScheme,
                              );
                              final statusLabel = ExpiryUtils.getStatusLabel(
                                expiryDate,
                              );
                              final availableActions =
                                  ExpiryUtils.getAvailableActions(
                                    estadoProducto,
                                  );
                              final stateColor =
                                  ExpiryUtils.getStateBadgeColor(
                                    estadoProducto,
                                  );
                              final stateDate = _getStateReferenceDate(
                                item,
                                estadoProducto,
                              );
                              final stateDateLabel = _getStateReferenceLabel(
                                estadoProducto,
                              );
                              final showExpiryStatusPill =
                                  expiryColor != Colors.transparent;
                              final stateBadgeLabel =
                                  stateDateLabel ??
                                  ExpiryUtils.getStateLabel(estadoProducto);
                              return Container(
                                key: _getItemKey(stockId),
                                margin: EdgeInsets.only(
                                  left: 12,
                                  right: 12,
                                  top: i == 0 ? 4 : 2,
                                  bottom: i == itemsInLocation.length - 1
                                      ? 8
                                      : 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.7),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.shadow.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    children: [
                                      if (expiryColor != Colors.transparent)
                                        Positioned(
                                          left: 0,
                                          top: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 10,
                                            color: expiryColor,
                                          ),
                                        ),
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          expiryColor != Colors.transparent
                                              ? 12
                                              : 14,
                                          12,
                                          14,
                                          12,
                                        ),
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            final compactCard =
                                                constraints.maxWidth < 430;

                                            final productArtwork = Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                color: colorScheme
                                                    .surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: colorScheme
                                                      .outlineVariant
                                                      .withValues(alpha: 0.5),
                                                ),
                                              ),
                                              child: imageUrl != null
                                                  ? ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                      child: Image.network(
                                                        imageUrl,
                                                        fit: BoxFit.cover,
                                                        width: 52,
                                                        height: 52,
                                                        loadingBuilder:
                                                            (
                                                              context,
                                                              child,
                                                              progress,
                                                            ) => progress == null
                                                                ? child
                                                                : const SizedBox(
                                                                    width: 20,
                                                                    height: 20,
                                                                    child: CircularProgressIndicator(
                                                                      strokeWidth: 2,
                                                                    ),
                                                                  ),
                                                        errorBuilder:
                                                            (
                                                              context,
                                                              error,
                                                              stackTrace,
                                                            ) => const Icon(
                                                              Icons
                                                                  .image_not_supported,
                                                              color: Colors.grey,
                                                              size: 22,
                                                            ),
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons
                                                          .inventory_2_outlined,
                                                      color: Colors.grey,
                                                      size: 22,
                                                    ),
                                            );

                                            final quantityBadge = Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    colorScheme.primaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: colorScheme.primary
                                                      .withValues(alpha: 0.10),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.layers_rounded,
                                                    size: 13,
                                                    color: colorScheme
                                                        .onPrimaryContainer,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    quantity == 1
                                                        ? '1 ud'
                                                        : '$quantity uds',
                                                    style: textTheme.labelLarge
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: colorScheme
                                                              .onPrimaryContainer,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            );

                                            final editButton = IconButton(
                                              constraints:
                                                  const BoxConstraints.tightFor(
                                                    width: 34,
                                                    height: 34,
                                                  ),
                                              padding: const EdgeInsets.all(6),
                                              tooltip: 'Editar',
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                              ),
                                              onPressed: () =>
                                                  _showEditStockItemDialog(item),
                                              style: IconButton.styleFrom(
                                                backgroundColor: colorScheme
                                                    .surfaceContainerHigh,
                                                foregroundColor: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            );

                                            final titleBlock = Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  productName,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: textTheme.titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      fontSize: 16,
                                                        color: colorScheme
                                                            .onSurface,
                                                      height: 1.14,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                if (brand != null &&
                                                    brand.isNotEmpty)
                                                  Text(
                                                    brand,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: textTheme.bodySmall
                                                        ?.copyWith(
                                                          color: colorScheme
                                                              .onSurfaceVariant
                                                              .withValues(
                                                                alpha: 0.9,
                                                              ),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          letterSpacing: 0.1,
                                                        ),
                                                  ),
                                              ],
                                            );

                                            final expiryMetaGroup =
                                                _InventoryMetaGroup(
                                                  title: 'Caducidad',
                                                  icon: Icons.event_repeat_rounded,
                                                  accentColor:
                                                      showExpiryStatusPill
                                                      ? expiryColor
                                                      : colorScheme.primary,
                                                  children: [
                                                    if (showExpiryStatusPill)
                                                      _InventoryMetaPill(
                                                        icon:
                                                            ExpiryUtils.getStatusIcon(
                                                              expiryDate,
                                                            ),
                                                        label: statusLabel,
                                                        textColor: expiryColor,
                                                        backgroundColor:
                                                            expiryColor
                                                                .withValues(
                                                                  alpha: 0.12,
                                                                ),
                                                        borderColor:
                                                            expiryColor
                                                                .withValues(
                                                                  alpha: 0.24,
                                                                ),
                                                      ),
                                                    _InventoryMetaPill(
                                                      icon: Icons.event_outlined,
                                                      label:
                                                          _formatInventoryDate(
                                                            expiryDate,
                                                          ),
                                                      textColor:
                                                          showExpiryStatusPill
                                                          ? expiryColor
                                                          : colorScheme
                                                                .onSurfaceVariant,
                                                      backgroundColor:
                                                          showExpiryStatusPill
                                                          ? expiryColor
                                                                .withValues(
                                                                  alpha: 0.08,
                                                                )
                                                          : colorScheme
                                                                .surfaceContainerHighest,
                                                      borderColor:
                                                          showExpiryStatusPill
                                                          ? expiryColor
                                                                .withValues(
                                                                  alpha: 0.18,
                                                                )
                                                          : colorScheme
                                                                .outlineVariant
                                                                .withValues(
                                                                  alpha: 0.55,
                                                                ),
                                                    ),
                                                  ],
                                                );

                                            final shouldShowStateGroup =
                                                ExpiryUtils.shouldShowStateBadge(
                                                  estadoProducto,
                                                ) ||
                                                (stateDate != null &&
                                                    stateDateLabel != null);

                                            final stateMetaGroup =
                                                shouldShowStateGroup
                                                ? _InventoryMetaGroup(
                                                    title: 'Estado',
                                                    icon: ExpiryUtils.getStateIcon(
                                                      estadoProducto,
                                                    ),
                                                    accentColor: stateColor,
                                                    children: [
                                                      if (ExpiryUtils.shouldShowStateBadge(
                                                        estadoProducto,
                                                      ))
                                                        _InventoryMetaPill(
                                                          icon: ExpiryUtils.getStateIcon(
                                                            estadoProducto,
                                                          ),
                                                          label:
                                                              stateBadgeLabel,
                                                          textColor: stateColor,
                                                          backgroundColor:
                                                              stateColor
                                                                  .withValues(
                                                                    alpha:
                                                                        0.12,
                                                                  ),
                                                          borderColor:
                                                              stateColor
                                                                  .withValues(
                                                                    alpha:
                                                                        0.24,
                                                                  ),
                                                        ),
                                                      if (stateDate != null &&
                                                          stateDateLabel !=
                                                              null)
                                                        _InventoryMetaPill(
                                                          icon: Icons
                                                              .history_toggle_off_rounded,
                                                          label:
                                                              _formatInventoryDate(
                                                                stateDate,
                                                              ),
                                                          textColor: stateColor,
                                                          backgroundColor:
                                                              stateColor
                                                                  .withValues(
                                                                    alpha:
                                                                        0.08,
                                                                  ),
                                                          borderColor:
                                                              stateColor
                                                                  .withValues(
                                                                    alpha:
                                                                        0.18,
                                                                  ),
                                                          trailing: estadoProducto ==
                                                                      'descongelado' &&
                                                                  item['fecha_congelacion'] !=
                                                                      null &&
                                                                  item['fecha_descongelacion'] !=
                                                                      null
                                                              ? Icon(
                                                                  Icons
                                                                      .info_outline_rounded,
                                                                  size: 15,
                                                                  color: stateColor
                                                                      .withValues(
                                                                        alpha:
                                                                            0.78,
                                                                      ),
                                                                )
                                                              : null,
                                                          onTap: estadoProducto ==
                                                                      'descongelado' &&
                                                                  item['fecha_congelacion'] !=
                                                                      null &&
                                                                  item['fecha_descongelacion'] !=
                                                                      null
                                                              ? () {
                                                                  final fechaCongelacion =
                                                                      DateTime.parse(
                                                                        item['fecha_congelacion'],
                                                                      );
                                                                  final fechaDescongelacion =
                                                                      DateTime.parse(
                                                                        item['fecha_descongelacion'],
                                                                      );
                                                                  showDialog(
                                                                    context:
                                                                        context,
                                                                    builder: (ctx) =>
                                                                        AlertDialog(
                                                                          title: const Text(
                                                                            'Historial de Congelación',
                                                                          ),
                                                                          content: Column(
                                                                            mainAxisSize:
                                                                                MainAxisSize.min,
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            children: [
                                                                              Row(
                                                                                children: [
                                                                                  Icon(
                                                                                    Icons.ac_unit_rounded,
                                                                                    color: Colors.blue.shade700,
                                                                                    size: 20,
                                                                                  ),
                                                                                  const SizedBox(
                                                                                    width: 8,
                                                                                  ),
                                                                                  Text(
                                                                                    'Congelado: ${_formatInventoryDate(fechaCongelacion)}',
                                                                                    style: const TextStyle(
                                                                                      fontSize: 14,
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                              const SizedBox(
                                                                                height: 8,
                                                                              ),
                                                                              Row(
                                                                                children: [
                                                                                  Icon(
                                                                                    Icons.severe_cold_rounded,
                                                                                    color: Colors.teal.shade700,
                                                                                    size: 20,
                                                                                  ),
                                                                                  const SizedBox(
                                                                                    width: 8,
                                                                                  ),
                                                                                  Text(
                                                                                    'Descongelado: ${_formatInventoryDate(fechaDescongelacion)}',
                                                                                    style: const TextStyle(
                                                                                      fontSize: 14,
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                              const SizedBox(
                                                                                height: 12,
                                                                              ),
                                                                              Text(
                                                                                '${fechaDescongelacion.difference(fechaCongelacion).inDays} días congelado',
                                                                                style: TextStyle(
                                                                                  fontSize: 12,
                                                                                  fontStyle: FontStyle.italic,
                                                                                  color: colorScheme.onSurface.withValues(
                                                                                    alpha: 0.6,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                          actions: [
                                                                            TextButton(
                                                                              onPressed: () =>
                                                                                  Navigator.of(
                                                                                    ctx,
                                                                                  ).pop(),
                                                                              child: const Text(
                                                                                'Cerrar',
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                  );
                                                                }
                                                              : null,
                                                        ),
                                                    ],
                                                  )
                                                : null;

                                            final metadataGroups = [
                                              Expanded(child: expiryMetaGroup),
                                              if (stateMetaGroup != null) ...[
                                                const SizedBox(width: 10),
                                                Expanded(child: stateMetaGroup),
                                              ],
                                            ];

                                            final metadataSection = compactCard
                                                ? Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      expiryMetaGroup,
                                                      if (stateMetaGroup !=
                                                          null) ...[
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        stateMetaGroup,
                                                      ],
                                                    ],
                                                  )
                                                : Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: metadataGroups,
                                                  );

                                            final useAction =
                                                _InventoryItemAction(
                                                  icon: Icons
                                                      .remove_circle_outline,
                                                  label: 'Usar',
                                                  description:
                                                      'Descontar unidades del inventario',
                                                  onPressed: () =>
                                                      showRemoveQuantityDialog(
                                                        stockId,
                                                        quantity,
                                                        productName,
                                                        item['producto_maestro']
                                                            ['id_producto'],
                                                      ),
                                                  backgroundColor:
                                                      colorScheme
                                                          .secondaryContainer,
                                                  foregroundColor:
                                                      colorScheme
                                                          .onSecondaryContainer,
                                                );

                                            final secondaryActions =
                                                <_InventoryItemAction>[];

                                            if (availableActions['abrir'] ==
                                                true) {
                                              secondaryActions.add(
                                                _InventoryItemAction(
                                                  icon: Icons
                                                      .open_in_new_rounded,
                                                  label: 'Abrir',
                                                  description:
                                                      'Marcar como abierto y ajustar su vida útil',
                                                  onPressed: () =>
                                                      _showOpenProductDialog(
                                                        item,
                                                      ),
                                                  backgroundColor:
                                                      Colors.orange.shade100,
                                                  foregroundColor:
                                                      Colors.orange.shade800,
                                                ),
                                              );
                                            }

                                            if (availableActions['descongelar'] ==
                                                true) {
                                              secondaryActions.add(
                                                _InventoryItemAction(
                                                  icon: Icons.wb_sunny_rounded,
                                                  label: 'Descongelar',
                                                  description:
                                                      'Pasarlo a una ubicación normal y recalcular consumo',
                                                  onPressed: () =>
                                                      _showUnfreezeProductDialog(
                                                        item,
                                                      ),
                                                  backgroundColor:
                                                      Colors.amber.shade100,
                                                  foregroundColor:
                                                      Colors.amber.shade800,
                                                ),
                                              );
                                            }

                                            if (availableActions['congelar'] ==
                                                true) {
                                              secondaryActions.add(
                                                _InventoryItemAction(
                                                  icon: Icons.ac_unit_rounded,
                                                  label: 'Congelar',
                                                  description:
                                                      'Moverlo al congelador y pausar alertas de caducidad',
                                                  onPressed: () =>
                                                      _showFreezeProductDialog(
                                                        item,
                                                      ),
                                                  backgroundColor:
                                                      Colors.blue.shade100,
                                                  foregroundColor:
                                                      Colors.blue.shade800,
                                                ),
                                              );
                                            }

                                            if (availableActions['reubicar'] ==
                                                true) {
                                              secondaryActions.add(
                                                _InventoryItemAction(
                                                  icon: Icons.move_up_rounded,
                                                  label: 'Reubicar',
                                                  description:
                                                      'Moverlo a otra ubicación dentro del hogar',
                                                  onPressed: () =>
                                                      _showRelocateProductDialog(
                                                        item,
                                                      ),
                                                  backgroundColor:
                                                      Colors.indigo.shade100,
                                                  foregroundColor:
                                                      Colors.indigo.shade800,
                                                ),
                                              );
                                            }

                                            final promotedSecondaryAction =
                                                secondaryActions.isNotEmpty
                                                ? secondaryActions.first
                                                : null;
                                            final overflowActions =
                                                secondaryActions.length > 1
                                                ? secondaryActions.sublist(1)
                                                : const <_InventoryItemAction>[];

                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                if (compactCard) ...[
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      productArtwork,
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: titleBlock,
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    children: [
                                                      quantityBadge,
                                                      const Spacer(),
                                                      editButton,
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  metadataSection,
                                                ] else
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      productArtwork,
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            titleBlock,
                                                            const SizedBox(
                                                              height: 10,
                                                            ),
                                                            metadataSection,
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .end,
                                                        children: [
                                                          quantityBadge,
                                                          const SizedBox(
                                                            height: 8,
                                                          ),
                                                          editButton,
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                            const SizedBox(height: 12),
                                            Divider(
                                              color: colorScheme.outlineVariant
                                                  .withValues(alpha: 0.3),
                                              thickness: 1,
                                              height: 1,
                                            ),
                                            const SizedBox(height: 12),
                                            _InventoryItemActionBar(
                                              primaryAction: useAction,
                                              secondaryAction:
                                                  promotedSecondaryAction,
                                              onMorePressed:
                                                  overflowActions.isNotEmpty
                                                  ? () =>
                                                        _showItemActionsSheet(
                                                          productName:
                                                              productName,
                                                          actions:
                                                              overflowActions,
                                                        )
                                                  : null,
                                              compact: compactCard,
                                            ),
                                          ],
                                        );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditStockItemDialog(dynamic item) {
    final colorScheme = Theme.of(context).colorScheme;
    final producto = item['producto_maestro'];
    final stockId = item['id_stock'] as int;
    final initialName = producto['nombre'] as String? ?? '';
    final initialBrand = (producto['marca'] as String?) ?? '';
    final initialQty = item['cantidad_actual'] as int;
    final initialExpiry = DateTime.parse(item['fecha_caducidad']);

    final nameController = TextEditingController(text: initialName);
    final brandController = TextEditingController(text: initialBrand);
    final qtyController = TextEditingController(text: initialQty.toString());
    final dateController = TextEditingController(
      text:
          '${initialExpiry.day.toString().padLeft(2, '0')}/${initialExpiry.month.toString().padLeft(2, '0')}/${initialExpiry.year}',
    );
    DateTime selectedDate = initialExpiry;
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    Future<void> pickDate(StateSetter setStateModal) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
      );
      if (picked != null) {
        setStateModal(() {
          selectedDate = picked;
          dateController.text =
              '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateModal) {
            final modalColorScheme = Theme.of(ctx).colorScheme;
            final modalTextTheme = Theme.of(ctx).textTheme;

            return SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.of(ctx).viewInsets.bottom +
                      MediaQuery.of(ctx).padding.bottom +
                      16,
                  left: 16,
                  right: 16,
                  top: 8,
                ),
                child: Material(
                  color: modalColorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: modalColorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Form(
                      key: formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 42,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: modalColorScheme.outlineVariant,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: modalColorScheme.primaryContainer.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: modalColorScheme.surface,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.edit_outlined,
                                      color: modalColorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Editar producto',
                                          style: modalTextTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Ajusta nombre, marca, cantidad y caducidad sin salir del inventario.',
                                          style: modalTextTheme.bodySmall?.copyWith(
                                            color: modalColorScheme.onSurfaceVariant,
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: nameController,
                              decoration: InputDecoration(
                                labelText: 'Nombre del producto',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                prefixIcon: const Icon(Icons.inventory_2_outlined),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Introduce un nombre'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: brandController,
                              decoration: InputDecoration(
                                labelText: 'Marca (opcional)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                prefixIcon: const Icon(Icons.branding_watermark_outlined),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: modalColorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: modalColorScheme.outlineVariant.withValues(alpha: 0.55),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cantidad y fecha',
                                    style: modalTextTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: qtyController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      labelText: 'Cantidad',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      prefixIcon: IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: saving
                                            ? null
                                            : () {
                                                final current =
                                                    int.tryParse(qtyController.text) ??
                                                    1;
                                                if (current > 1) {
                                                  setStateModal(
                                                    () => qtyController.text =
                                                        (current - 1).toString(),
                                                  );
                                                }
                                              },
                                      ),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: saving
                                            ? null
                                            : () {
                                                final current =
                                                    int.tryParse(qtyController.text) ??
                                                    0;
                                                setStateModal(
                                                  () => qtyController.text =
                                                      (current + 1).toString(),
                                                );
                                              },
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Requerido';
                                      final n = int.tryParse(v);
                                      if (n == null || n <= 0) return '> 0';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: dateController,
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      labelText: 'Fecha de caducidad',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                                    ),
                                    onTap: saving ? null : () => pickDate(setStateModal),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (saving)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: const Text('Cancelar'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () async {
                                        if (!(formKey.currentState?.validate() ??
                                            false)) {
                                          return;
                                        }
                                        setStateModal(() => saving = true);
                                        try {
                                          await updateStockItem(
                                            stockId: stockId,
                                            productName:
                                                nameController.text.trim() !=
                                                    initialName
                                                ? nameController.text.trim()
                                                : null,
                                            brand:
                                                brandController.text.trim() !=
                                                    initialBrand
                                                ? brandController.text.trim()
                                                : null,
                                            cantidadActual: int.parse(
                                              qtyController.text,
                                            ),
                                            fechaCaducidad:
                                                selectedDate != initialExpiry
                                                ? selectedDate
                                                : null,
                                          );
                                          await refreshInventory();
                                          if (!mounted || !ctx.mounted) {
                                            return;
                                          }
                                          if (mounted) {
                                            Navigator.of(ctx).pop();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                  'Ítem actualizado.',
                                                ),
                                                backgroundColor: colorScheme.primary,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (!mounted || !ctx.mounted) {
                                            return;
                                          }
                                          setStateModal(() => saving = false);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error al actualizar: $e'),
                                              backgroundColor: colorScheme.error,
                                            ),
                                          );
                                        }
                                      },
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: const Text('Guardar'),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
