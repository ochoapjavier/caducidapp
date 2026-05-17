import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/screens/date_scanner_screen.dart';
import 'package:intl/intl.dart';
import 'package:frontend/models/supermercado.dart';
import 'package:frontend/models/ticket_item.dart';
import 'package:frontend/models/ticket_review_submission.dart';
import 'package:frontend/models/ubicacion.dart';
import 'package:frontend/screens/scanner_screen.dart';
import 'package:frontend/services/api_service.dart' as api;

class MatchmakerScreen extends StatefulWidget {
  final List<TicketItem> initialItems;
  final String guessedSupermercado;

  const MatchmakerScreen({
    super.key,
    required this.initialItems,
    required this.guessedSupermercado,
  });

  @override
  State<MatchmakerScreen> createState() => _MatchmakerScreenState();
}

class _MatchmakerScreenState extends State<MatchmakerScreen> {
  static const Color _eanActionColor = Color(0xFF0B57D0);

  late List<TicketReviewLine> reviewLines;

  List<Supermercado> supermercados = [];
  List<Ubicacion> ubicaciones = [];
  List<_DictionaryEntry> dictionaryEntries = [];
  Map<String, List<_DictionaryProductMatch>> _suggestedMatchesByName = {};

  int? selectedSupermercadoId;
  String customSupermercadoNombre = 'Desconocido';
  bool isLoadingContext = true;
  int? _defaultLocationId;
  bool _isHelpExpanded = false;

  @override
  void initState() {
    super.initState();
    reviewLines = widget.initialItems
        .map((item) => TicketReviewLine(item: _cloneItem(item)))
        .toList();
    customSupermercadoNombre = widget.guessedSupermercado;
    _loadContext();
  }

  TicketItem _cloneItem(TicketItem item) {
    return TicketItem(
      nombre: item.nombre,
      precioUnitario: item.precioUnitario,
      cantidad: item.cantidad,
      requiereRevisionCantidad: item.requiereRevisionCantidad,
      eansAsignados: List<String>.from(item.eansAsignados),
    );
  }

  TicketLineAllocation _buildDefaultAllocation(
    TicketItem item, {
    int? quantity,
    TicketLineAllocation? seed,
  }) {
    return TicketLineAllocation(
      cantidad: quantity ?? item.cantidad,
      productName: seed?.productName ?? item.nombre,
      barcode: seed?.barcode,
      ubicacionId: seed?.ubicacionId ?? _defaultLocationId,
      fechaCaducidad: null,
      brand: seed?.brand,
      imageUrl: seed?.imageUrl,
      usesKnownProduct: seed?.usesKnownProduct ?? false,
      productSource: seed?.productSource,
    );
  }

  bool _isValidItem(TicketItem item) {
    return item.nombre.trim().isNotEmpty &&
        item.cantidad > 0 &&
        item.precioUnitario > 0 &&
        !item.requiereRevisionCantidad;
  }

  int _allocatedQuantity(TicketReviewLine line) {
    return line.allocations.fold(
      0,
      (sum, allocation) => sum + allocation.cantidad,
    );
  }

  bool _hasBalancedAllocations(TicketReviewLine line) {
    return line.allocations.isNotEmpty &&
        _allocatedQuantity(line) == line.item.cantidad;
  }

  bool _isAllocationComplete(TicketLineAllocation allocation) {
    return allocation.cantidad > 0 &&
        allocation.productName.trim().isNotEmpty &&
        allocation.ubicacionId != null &&
        allocation.fechaCaducidad != null;
  }

  bool _isReadyToPersist(TicketReviewLine line) {
    return _isValidItem(line.item) &&
        _hasBalancedAllocations(line) &&
        line.allocations.every(_isAllocationComplete);
  }

  int? _resolveDefaultLocationId(List<Ubicacion> locations) {
    if (locations.isEmpty) {
      return null;
    }

    for (final location in locations) {
      if (location.nombre.toLowerCase().contains('despensa')) {
        return location.id;
      }
    }

    return locations.first.id;
  }

  Supermercado? get _selectedSupermercado {
    if (selectedSupermercadoId == null) {
      return null;
    }

    for (final supermercado in supermercados) {
      if (supermercado.id == selectedSupermercadoId) {
        return supermercado;
      }
    }

    return null;
  }

  bool _isSvgUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return false;
    }

    return url.toLowerCase().contains('.svg');
  }

  bool _usesSplitUi(TicketReviewLine line) {
    return line.item.cantidad > 1;
  }

  String? _resolveRasterLogoUrl(String? logoUrl) {
    if (logoUrl == null) {
      return null;
    }

    final trimmed = logoUrl.trim();
    if (trimmed.isEmpty || _isSvgUrl(trimmed)) {
      return null;
    }

    return trimmed;
  }

  String _buildSupermercadoInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'SM';
    }

    final words = trimmed
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.replaceAll(RegExp(r'[^A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ]'), ''),
        )
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.length >= 2) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }

    final compact = words.isNotEmpty ? words.first : trimmed;
    final limit = compact.length >= 2 ? 2 : 1;
    return compact.substring(0, limit).toUpperCase();
  }

  Color _foregroundColorFor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.45
        ? Colors.black87
        : Colors.white;
  }

  int _allocationCompletenessScore(TicketLineAllocation allocation) {
    var score = 0;
    if ((allocation.barcode?.trim().isNotEmpty ?? false)) {
      score += 3;
    }
    if (allocation.ubicacionId != null) {
      score += 2;
    }
    if (allocation.fechaCaducidad != null) {
      score += 2;
    }
    if ((allocation.brand?.trim().isNotEmpty ?? false)) {
      score += 1;
    }
    if ((allocation.imageUrl?.trim().isNotEmpty ?? false)) {
      score += 1;
    }
    return score;
  }

  String? _firstNonEmptyText(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    return null;
  }

  int? _firstNonNullLocationId(Iterable<TicketLineAllocation> allocations) {
    for (final allocation in allocations) {
      if (allocation.ubicacionId != null) {
        return allocation.ubicacionId;
      }
    }

    return _defaultLocationId;
  }

  DateTime? _firstNonNullExpiry(Iterable<TicketLineAllocation> allocations) {
    for (final allocation in allocations) {
      if (allocation.fechaCaducidad != null) {
        return allocation.fechaCaducidad;
      }
    }

    return null;
  }

  TicketLineAllocation _collapseToSingleAllocation(TicketReviewLine line) {
    final candidates = line.allocations.isEmpty
        ? <TicketLineAllocation>[_buildDefaultAllocation(line.item)]
        : List<TicketLineAllocation>.from(line.allocations);

    candidates.sort(
      (left, right) => _allocationCompletenessScore(
        right,
      ).compareTo(_allocationCompletenessScore(left)),
    );

    final primary = candidates.first;
    return TicketLineAllocation(
      cantidad: 1,
      productName:
          _firstNonEmptyText(
            candidates.map((allocation) => allocation.productName),
          ) ??
          line.item.nombre,
      barcode: _firstNonEmptyText(
        candidates.map((allocation) => allocation.barcode),
      ),
      ubicacionId: primary.ubicacionId ?? _firstNonNullLocationId(candidates),
      fechaCaducidad: _firstNonNullExpiry(candidates),
      brand: _firstNonEmptyText(
        candidates.map((allocation) => allocation.brand),
      ),
      imageUrl: _firstNonEmptyText(
        candidates.map((allocation) => allocation.imageUrl),
      ),
      usesKnownProduct: candidates.any(
        (allocation) => allocation.usesKnownProduct,
      ),
      productSource: _firstNonEmptyText(
        candidates.map((allocation) => allocation.productSource),
      ),
    );
  }

  void _syncAllocationsWithItemQuantity(TicketReviewLine line) {
    if (line.allocations.isEmpty) {
      line.allocations.add(_buildDefaultAllocation(line.item));
      return;
    }

    if (line.item.cantidad <= 1) {
      final collapsed = _collapseToSingleAllocation(line);
      line.allocations
        ..clear()
        ..add(collapsed);
      return;
    }

    if (line.allocations.length == 1) {
      line.allocations.first.cantidad = line.item.cantidad;
    }
  }

  Widget _buildSupermercadoIdentityBadge({
    required String supermercadoNombre,
    required String? logoUrl,
    required Color accentColor,
    required TextTheme textTheme,
  }) {
    final foregroundColor = _foregroundColorFor(accentColor);
    final rasterLogoUrl = _resolveRasterLogoUrl(logoUrl);
    final initials = _buildSupermercadoInitials(supermercadoNombre);

    Widget markChild() {
      if (rasterLogoUrl != null) {
        return Image.network(
          rasterLogoUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(
            initials,
            style: textTheme.labelLarge?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        );
      }

      return Text(
        initials,
        style: textTheme.labelLarge?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      );
    }

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: foregroundColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: foregroundColor.withValues(alpha: 0.22),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: markChild(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              supermercadoNombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationImage(TicketLineAllocation allocation) {
    final imageUrl = allocation.imageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade100,
          alignment: Alignment.center,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey.shade600,
            size: 22,
          ),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return Container(
            color: Colors.grey.shade100,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      ),
    );
  }

  int _countReadyAllocations(TicketReviewLine line) {
    return line.allocations.where(_isAllocationComplete).length;
  }

  Future<void> _scanExpiryDate(int lineIndex, int allocationIndex) async {
    final scannedDate = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(builder: (context) => const DateScannerScreen()),
    );

    if (scannedDate == null || !mounted) {
      return;
    }

    setState(() {
      reviewLines[lineIndex].allocations[allocationIndex].fechaCaducidad =
          scannedDate;
    });
  }

  Widget _buildAllocationMetaFields({
    required TicketLineAllocation allocation,
    required int lineIndex,
    required int allocationIndex,
    required TextTheme textTheme,
  }) {
    final locationField = DropdownButtonFormField<int>(
      isExpanded: true,
      initialValue: allocation.ubicacionId,
      decoration: InputDecoration(
        labelText: 'Ubicación',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: ubicaciones.map((ubicacion) {
        return DropdownMenuItem<int>(
          value: ubicacion.id,
          child: Text(
            ubicacion.nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          allocation.ubicacionId = value;
        });
      },
    );

    final expiryField = InputDecorator(
      decoration: InputDecoration(
        labelText: 'Caducidad',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _pickExpiryDate(lineIndex, allocationIndex),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  allocation.fechaCaducidad == null
                      ? 'Seleccionar'
                      : DateFormat(
                          'dd/MM/yyyy',
                        ).format(allocation.fechaCaducidad!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _pickExpiryDate(lineIndex, allocationIndex),
            visualDensity: VisualDensity.compact,
            tooltip: 'Elegir fecha',
            icon: const Icon(Icons.calendar_today, size: 18),
          ),
          IconButton(
            onPressed: () => _scanExpiryDate(lineIndex, allocationIndex),
            visualDensity: VisualDensity.compact,
            tooltip: 'Escanear caducidad',
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320) {
          return Column(
            children: [locationField, const SizedBox(height: 12), expiryField],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: locationField),
            const SizedBox(width: 12),
            Expanded(child: expiryField),
          ],
        );
      },
    );
  }

  Future<void> _loadContext() async {
    try {
      final supermercadosList = await api.getSupermercados();
      final locations = await api.fetchUbicaciones();
      List<Map<String, dynamic>> rawDictionary = [];

      try {
        rawDictionary = await api.getDictionaryMemory();
      } catch (_) {}

      _defaultLocationId = _resolveDefaultLocationId(locations);
      dictionaryEntries = rawDictionary.map(_DictionaryEntry.fromJson).toList();

      for (final line in reviewLines) {
        _syncAllocationsWithItemQuantity(line);
      }

      int? inferredSupermercadoId;
      var inferredSupermercadoNombre = customSupermercadoNombre;
      for (final supermercado in supermercadosList) {
        if (supermercado.nombre.toLowerCase() ==
            widget.guessedSupermercado.toLowerCase()) {
          inferredSupermercadoId = supermercado.id;
          inferredSupermercadoNombre = supermercado.nombre;
          break;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        supermercados = supermercadosList;
        ubicaciones = locations;
        selectedSupermercadoId = inferredSupermercadoId;
        customSupermercadoNombre = inferredSupermercadoNombre;
        _suggestedMatchesByName = _buildSuggestedMatchesByName(
          inferredSupermercadoId,
        );
        isLoadingContext = false;
      });

      await _autofillKnownMatches();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoadingContext = false;
      });
    }
  }

  Map<String, List<_DictionaryProductMatch>> _buildSuggestedMatchesByName(
    int? supermercadoId,
  ) {
    if (supermercadoId == null) {
      return {};
    }

    final suggestions = <String, List<_DictionaryProductMatch>>{};
    for (final line in reviewLines) {
      final matches = dictionaryEntries
          .where(
            (entry) =>
                entry.supermercadoId == supermercadoId &&
                entry.ticketNombre == line.item.nombre,
          )
          .expand((entry) => entry.matches)
          .toList();

      if (matches.isNotEmpty) {
        suggestions[line.item.nombre] = matches;
      }
    }

    return suggestions;
  }

  Future<void> _autofillKnownMatches() async {
    for (var lineIndex = 0; lineIndex < reviewLines.length; lineIndex++) {
      final line = reviewLines[lineIndex];
      final suggestions = _suggestedMatchesByName[line.item.nombre] ?? const [];
      if (suggestions.length != 1) {
        continue;
      }

      if (line.allocations.length != 1) {
        continue;
      }

      final allocation = line.allocations.first;
      if ((allocation.barcode?.trim().isNotEmpty ?? false)) {
        continue;
      }

      await _assignMatchToAllocation(
        lineIndex,
        0,
        suggestions.first,
        announce: false,
      );
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Color _parseColor(String? colorHex, Color fallback) {
    if (colorHex == null || colorHex.isEmpty) {
      return fallback;
    }

    final normalized = colorHex.replaceFirst('#', '');
    if (normalized.length != 6) {
      return fallback;
    }

    final parsed = int.tryParse('FF$normalized', radix: 16);
    if (parsed == null) {
      return fallback;
    }

    return Color(parsed);
  }

  String _formatAllocationStatus(TicketReviewLine line) {
    final allocated = _allocatedQuantity(line);
    if (allocated == line.item.cantidad) {
      return 'Reparto correcto: $allocated/${line.item.cantidad} uds';
    }
    return 'Reparte $allocated/${line.item.cantidad} uds';
  }

  String _formatAllocationProduct(TicketLineAllocation allocation) {
    final brand = allocation.brand?.trim();
    if (brand == null || brand.isEmpty) {
      return allocation.productName;
    }
    return '${allocation.productName} · $brand';
  }

  String _formatMatchLabel(_DictionaryProductMatch match) {
    final brand = match.brand?.trim();
    if (brand == null || brand.isEmpty) {
      return match.productName?.trim().isNotEmpty == true
          ? '${match.productName} · ${match.barcode}'
          : match.barcode;
    }
    return '${match.productName ?? match.barcode} · $brand';
  }

  void _showCreateSupermercadoDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir Nuevo Supermercado'),
        content: TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre (ej: Alimerka)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) {
                return;
              }

              Navigator.pop(context);
              setState(() => isLoadingContext = true);

              try {
                final newSuper = await api.createSupermercado(newName);
                if (!mounted) {
                  return;
                }

                setState(() {
                  supermercados.add(newSuper);
                  supermercados.sort((a, b) => a.nombre.compareTo(b.nombre));
                  selectedSupermercadoId = newSuper.id;
                  customSupermercadoNombre = newSuper.nombre;
                  _suggestedMatchesByName = _buildSuggestedMatchesByName(
                    newSuper.id,
                  );
                  isLoadingContext = false;
                });
              } catch (_) {
                if (!mounted) {
                  return;
                }

                setState(() => isLoadingContext = false);
              }
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  Future<_ResolvedBarcodeProduct> _resolveProductForBarcode(
    String barcode,
    String fallbackName,
  ) async {
    Map<String, dynamic>? offData;

    try {
      final productData = await api.fetchProductFromCatalog(barcode);
      if (productData != null) {
        final localImageUrl = (productData['image_url'] as String?)?.trim();
        if (localImageUrl == null || localImageUrl.isEmpty) {
          try {
            offData = await api.fetchProductFromOpenFoodFacts(barcode);
          } catch (_) {}
        }

        return _ResolvedBarcodeProduct(
          productName:
              (productData['nombre'] as String?)?.trim().isNotEmpty == true
              ? productData['nombre'] as String
              : fallbackName,
          brand: productData['marca'] as String?,
          imageUrl: localImageUrl?.isNotEmpty == true
              ? localImageUrl
              : (offData?['image_front_thumb_url'] as String?),
          isLocalCatalogMatch: true,
          sourceLabel: localImageUrl?.isNotEmpty == true
              ? 'Catálogo del hogar'
              : 'Catálogo del hogar · imagen completada',
        );
      }
    } catch (_) {}

    try {
      offData ??= await api.fetchProductFromOpenFoodFacts(barcode);
      if (offData != null) {
        final nameEs = (offData['product_name_es'] as String?)?.trim();
        final nameEn = (offData['product_name_en'] as String?)?.trim();
        final genericName = (offData['product_name'] as String?)?.trim();
        final resolvedName = (nameEs != null && nameEs.isNotEmpty)
            ? nameEs
            : (nameEn != null && nameEn.isNotEmpty)
            ? nameEn
            : (genericName != null && genericName.isNotEmpty)
            ? genericName
            : fallbackName;

        return _ResolvedBarcodeProduct(
          productName: resolvedName,
          brand: offData['brands'] as String?,
          imageUrl: offData['image_front_thumb_url'] as String?,
          isLocalCatalogMatch: false,
          sourceLabel: 'Propuesta de OpenFoodFacts',
        );
      }
    } catch (_) {}

    return _ResolvedBarcodeProduct(
      productName: fallbackName,
      brand: null,
      imageUrl: null,
      isLocalCatalogMatch: false,
      sourceLabel: 'Sin coincidencia automática',
    );
  }

  Future<void> _assignMatchToAllocation(
    int lineIndex,
    int allocationIndex,
    _DictionaryProductMatch match, {
    bool announce = true,
  }) async {
    final resolved = match.hasProductData
        ? _ResolvedBarcodeProduct(
            productName: match.productName?.trim().isNotEmpty == true
                ? match.productName!
                : reviewLines[lineIndex].item.nombre,
            brand: match.brand,
            imageUrl: match.imageUrl,
            isLocalCatalogMatch: true,
            sourceLabel: 'Coincidencia guardada',
          )
        : await _resolveProductForBarcode(
            match.barcode,
            reviewLines[lineIndex].item.nombre,
          );

    if (!mounted) {
      return;
    }

    setState(() {
      final allocation = reviewLines[lineIndex].allocations[allocationIndex];
      allocation.barcode = match.barcode;
      allocation.productName = resolved.productName;
      allocation.brand = resolved.brand;
      allocation.imageUrl = resolved.imageUrl;
      allocation.usesKnownProduct = resolved.isLocalCatalogMatch;
      allocation.productSource = resolved.sourceLabel;
    });

    if (announce) {
      _showSnackBar(
        'EAN ${match.barcode} aplicado a ${reviewLines[lineIndex].item.nombre}.',
      );
    }
  }

  Future<void> _assignScannedBarcodeToAllocation(
    int lineIndex,
    int allocationIndex,
    String barcode,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final resolved = await _resolveProductForBarcode(
      barcode,
      reviewLines[lineIndex].item.nombre,
    );

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      final allocation = reviewLines[lineIndex].allocations[allocationIndex];
      allocation.barcode = barcode;
      allocation.productName = resolved.productName;
      allocation.brand = resolved.brand;
      allocation.imageUrl = resolved.imageUrl;
      allocation.usesKnownProduct = resolved.isLocalCatalogMatch;
      allocation.productSource = resolved.sourceLabel;
    });

    HapticFeedback.lightImpact();
  }

  Future<void> _scanBarcodeForAllocation(
    int lineIndex,
    int allocationIndex,
  ) async {
    final scannedBarcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    if (scannedBarcode == null || scannedBarcode.isEmpty) {
      return;
    }

    await _assignScannedBarcodeToAllocation(
      lineIndex,
      allocationIndex,
      scannedBarcode,
    );
  }

  void _clearBarcodeForAllocation(int lineIndex, int allocationIndex) {
    setState(() {
      final allocation = reviewLines[lineIndex].allocations[allocationIndex];
      allocation.barcode = null;
      allocation.productName = reviewLines[lineIndex].item.nombre;
      allocation.brand = null;
      allocation.imageUrl = null;
      allocation.usesKnownProduct = false;
      allocation.productSource = null;
    });
  }

  Future<void> _pickExpiryDate(int lineIndex, int allocationIndex) async {
    final allocation = reviewLines[lineIndex].allocations[allocationIndex];
    final initialDate = allocation.fechaCaducidad ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (pickedDate != null) {
      setState(() {
        allocation.fechaCaducidad = pickedDate;
      });
    }
  }

  void _editAllocationProduct(int lineIndex, int allocationIndex) {
    final allocation = reviewLines[lineIndex].allocations[allocationIndex];
    final nameController = TextEditingController(text: allocation.productName);
    final brandController = TextEditingController(text: allocation.brand ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar producto asociado'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: brandController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Marca'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isEmpty) {
                _showSnackBar('El nombre del producto no puede estar vacío.');
                return;
              }

              setState(() {
                allocation.productName = newName;
                allocation.brand = brandController.text.trim().isEmpty
                    ? null
                    : brandController.text.trim();
                allocation.productSource = 'Editado manualmente';
                allocation.usesKnownProduct = false;
              });
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _editAllocationQuantity(int lineIndex, int allocationIndex) {
    final allocation = reviewLines[lineIndex].allocations[allocationIndex];
    final quantityController = TextEditingController(
      text: allocation.cantidad.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cantidad de esta partición'),
        content: TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Unidades *'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(quantityController.text.trim());
              if (parsed == null || parsed <= 0) {
                _showSnackBar(
                  'La cantidad debe ser un número entero positivo.',
                );
                return;
              }

              setState(() {
                allocation.cantidad = parsed;
              });
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _copyAllocationLocationToOthers(int lineIndex, int allocationIndex) {
    final line = reviewLines[lineIndex];
    final sourceLocationId = line.allocations[allocationIndex].ubicacionId;
    if (sourceLocationId == null) {
      return;
    }

    setState(() {
      for (var index = 0; index < line.allocations.length; index++) {
        if (index == allocationIndex) {
          continue;
        }
        line.allocations[index].ubicacionId = sourceLocationId;
      }
    });

    _showSnackBar('Ubicación copiada al resto de particiones.');
  }

  void _copyAllocationExpiryToOthers(int lineIndex, int allocationIndex) {
    final line = reviewLines[lineIndex];
    final sourceExpiry = line.allocations[allocationIndex].fechaCaducidad;
    if (sourceExpiry == null) {
      return;
    }

    setState(() {
      for (var index = 0; index < line.allocations.length; index++) {
        if (index == allocationIndex) {
          continue;
        }
        line.allocations[index].fechaCaducidad = sourceExpiry;
      }
    });

    _showSnackBar('Caducidad copiada al resto de particiones.');
  }

  void _addAllocation(int lineIndex) {
    final line = reviewLines[lineIndex];
    if (line.item.cantidad <= 1) {
      _showSnackBar(
        'Esta línea solo tiene una unidad; no hace falta dividirla.',
      );
      return;
    }

    var canSplit = true;
    setState(() {
      final currentTotal = _allocatedQuantity(line);
      var newQuantity = 1;
      if (currentTotal >= line.item.cantidad) {
        final donorIndex = line.allocations.lastIndexWhere(
          (allocation) => allocation.cantidad > 1,
        );
        if (donorIndex == -1) {
          canSplit = false;
          return;
        }
        line.allocations[donorIndex].cantidad -= 1;
      } else {
        newQuantity = line.item.cantidad - currentTotal;
      }

      final seed = line.allocations.isNotEmpty ? line.allocations.first : null;
      line.allocations.add(
        _buildDefaultAllocation(line.item, quantity: newQuantity, seed: seed),
      );
    });

    if (!canSplit) {
      _showSnackBar(
        'No hay margen para dividir más esta línea sin reajustar cantidades.',
      );
    }
  }

  void _removeAllocation(int lineIndex, int allocationIndex) {
    final line = reviewLines[lineIndex];
    if (line.allocations.length == 1) {
      _showSnackBar('Cada línea necesita al menos una partición.');
      return;
    }

    setState(() {
      final removed = line.allocations.removeAt(allocationIndex);
      final targetIndex = allocationIndex == 0 ? 0 : allocationIndex - 1;
      line.allocations[targetIndex].cantidad += removed.cantidad;
    });
  }

  void _editItem(int index) {
    final line = reviewLines[index];
    final item = line.item;
    final oldName = item.nombre;
    final quantityController = TextEditingController(
      text: item.cantidad.toString(),
    );
    final nameController = TextEditingController(text: item.nombre);
    final priceController = TextEditingController(
      text: item.precioUnitario.toStringAsFixed(2).replaceAll('.', ','),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar línea del ticket'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad *',
                  helperText:
                      'Si ya dividiste la línea, revisa el reparto después.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Precio unitario *',
                  prefixText: '€ ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final newName = nameController.text.trim();
              final newQuantity = int.tryParse(quantityController.text.trim());
              final newPrice = double.tryParse(
                priceController.text.trim().replaceAll(',', '.'),
              );

              if (newName.isEmpty) {
                _showSnackBar('El nombre no puede estar vacío.');
                return;
              }
              if (newQuantity == null || newQuantity <= 0) {
                _showSnackBar(
                  'La cantidad debe ser un número entero positivo.',
                );
                return;
              }
              if (newPrice == null || newPrice <= 0) {
                _showSnackBar('El precio unitario debe ser mayor que cero.');
                return;
              }

              setState(() {
                item.nombre = newName.toUpperCase();
                item.cantidad = newQuantity;
                item.precioUnitario = newPrice;
                item.requiereRevisionCantidad = false;

                for (final allocation in line.allocations) {
                  if (allocation.productName == oldName) {
                    allocation.productName = item.nombre;
                  }
                }

                _syncAllocationsWithItemQuantity(line);

                _suggestedMatchesByName = _buildSuggestedMatchesByName(
                  selectedSupermercadoId,
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _removeItem(int index) {
    final removedLine = reviewLines[index];

    setState(() {
      reviewLines.removeAt(index);
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Se ha quitado "${removedLine.item.nombre}" del ticket.',
          ),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () {
              setState(() {
                reviewLines.insert(
                  index.clamp(0, reviewLines.length),
                  removedLine,
                );
                _suggestedMatchesByName = _buildSuggestedMatchesByName(
                  selectedSupermercadoId,
                );
              });
            },
          ),
        ),
      );
  }

  Future<void> _handleSupermercadoChange(int? value) async {
    if (value == -1) {
      _showCreateSupermercadoDialog();
      return;
    }

    setState(() {
      selectedSupermercadoId = value;
      if (value != null) {
        customSupermercadoNombre = supermercados
            .firstWhere((supermercado) => supermercado.id == value)
            .nombre;
      }
      _suggestedMatchesByName = _buildSuggestedMatchesByName(value);
    });

    await _autofillKnownMatches();
  }

  void _finishMatching() {
    if (reviewLines.isEmpty) {
      _showSnackBar('Añade o conserva al menos un producto antes de guardar.');
      return;
    }

    final invalidIndex = reviewLines.indexWhere(
      (line) => !_isValidItem(line.item),
    );
    if (invalidIndex != -1) {
      final invalidItem = reviewLines[invalidIndex].item;
      if (invalidItem.requiereRevisionCantidad) {
        _showSnackBar(
          'Revisa y confirma la cantidad de los productos vendidos por peso antes de guardar.',
        );
      } else {
        _showSnackBar('Revisa nombre, cantidad y precio antes de guardar.');
      }
      _editItem(invalidIndex);
      return;
    }

    final quantityMismatchIndex = reviewLines.indexWhere(
      (line) => !_hasBalancedAllocations(line),
    );
    if (quantityMismatchIndex != -1) {
      final line = reviewLines[quantityMismatchIndex];
      _showSnackBar(
        'La línea ${line.item.nombre} debe repartir exactamente ${line.item.cantidad} unidades entre sus particiones.',
      );
      return;
    }

    for (var lineIndex = 0; lineIndex < reviewLines.length; lineIndex++) {
      final line = reviewLines[lineIndex];
      for (
        var allocationIndex = 0;
        allocationIndex < line.allocations.length;
        allocationIndex++
      ) {
        final allocation = line.allocations[allocationIndex];
        if (allocation.productName.trim().isEmpty) {
          _showSnackBar(
            'Revisa el nombre del producto en ${line.item.nombre}, partición ${allocationIndex + 1}.',
          );
          return;
        }
        if (allocation.ubicacionId == null ||
            allocation.fechaCaducidad == null) {
          _showSnackBar(
            'Selecciona ubicación y caducidad para ${line.item.nombre}, partición ${allocationIndex + 1}.',
          );
          return;
        }
      }
    }

    Navigator.of(context).pop(
      TicketReviewSubmission(
        lineas: reviewLines,
        supermercadoId: selectedSupermercadoId,
        supermercadoNombre: customSupermercadoNombre,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selectedSupermercado = _selectedSupermercado;
    final accentColor = _parseColor(
      selectedSupermercado?.colorHex,
      colorScheme.primary,
    );
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificar Ticket'),
        backgroundColor: colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            onPressed: isLoadingContext ? null : _finishMatching,
            tooltip: 'Confirmar y Guardar',
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isHelpExpanded = !_isHelpExpanded;
                    });
                  },
                  icon: Icon(
                    _isHelpExpanded ? Icons.expand_less : Icons.info_outline,
                    size: 18,
                  ),
                  label: Text(
                    _isHelpExpanded
                        ? 'Ocultar ayuda rápida'
                        : 'Mostrar ayuda rápida',
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withAlpha(
                    (255 * 0.3).round(),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Escanea una vez por partición. Si toda la línea es el mismo producto, no repitas el EAN; si hay sabores o ubicaciones distintas, divide la línea y reparte cantidades.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: _isHelpExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: isLoadingContext
                        ? const SizedBox(
                            height: 48,
                            child: Center(child: LinearProgressIndicator()),
                          )
                        : DropdownButtonFormField<int?>(
                            initialValue: selectedSupermercadoId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Supermercado',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: [
                              ...supermercados.map(
                                (supermercado) => DropdownMenuItem<int?>(
                                  value: supermercado.id,
                                  child: Text(
                                    supermercado.nombre,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const DropdownMenuItem<int?>(
                                value: -1,
                                child: Text(
                                  '+ Crear Nuevo...',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              _handleSupermercadoChange(value);
                            },
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: _buildSupermercadoIdentityBadge(
                      supermercadoNombre: customSupermercadoNombre,
                      logoUrl: selectedSupermercado?.logoUrl,
                      accentColor: accentColor,
                      textTheme: textTheme,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Scrollbar(
                child: ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + bottomInset),
                  itemCount: reviewLines.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final line = reviewLines[index];
                    final item = line.item;
                    final requiresQuantityReview =
                        item.requiereRevisionCantidad;
                    final isReady = _isReadyToPersist(line);
                    final readyAllocationCount = _countReadyAllocations(line);
                    final showSplitUi = _usesSplitUi(line);
                    final suggestions =
                        _suggestedMatchesByName[item.nombre] ??
                        const <_DictionaryProductMatch>[];

                    return Dismissible(
                      key: ValueKey(
                        'ticket-item-$index-${item.nombre}-${item.precioUnitario}',
                      ),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline, color: Colors.white),
                            SizedBox(height: 4),
                            Text(
                              'Quitar',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      onDismissed: (_) => _removeItem(index),
                      child: Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        color: isReady
                            ? Colors.green.withValues(alpha: 0.05)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: isReady
                                ? Colors.green.withValues(alpha: 0.25)
                                : colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isReady
                                        ? Colors.green.withValues(alpha: 0.18)
                                        : requiresQuantityReview
                                        ? Colors.orange.withValues(alpha: 0.18)
                                        : colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      isReady
                                          ? Icons.inventory_2_outlined
                                          : requiresQuantityReview
                                          ? Icons.warning_amber_rounded
                                          : Icons.receipt_long,
                                      color: isReady
                                          ? Colors.green.shade700
                                          : requiresQuantityReview
                                          ? Colors.orange.shade700
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.nombre,
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Cantidad ${item.cantidad} · ${item.precioUnitario.toStringAsFixed(2)} € / ud · ${item.precioTotal.toStringAsFixed(2)} € total',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _editItem(index),
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Editar línea',
                                  ),
                                ],
                              ),
                              if (requiresQuantityReview)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.orange.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Producto vendido por peso: revisa la cantidad final antes de guardar',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: Colors.orange.shade800,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (showSplitUi)
                                    Chip(
                                      avatar: Icon(
                                        _hasBalancedAllocations(line)
                                            ? Icons.rule_folder_outlined
                                            : Icons.warning_amber_rounded,
                                        size: 18,
                                        color: _hasBalancedAllocations(line)
                                            ? Colors.green.shade700
                                            : Colors.orange.shade800,
                                      ),
                                      label: Text(
                                        _formatAllocationStatus(line),
                                      ),
                                    ),
                                  if (suggestions.isNotEmpty)
                                    Chip(
                                      avatar: Icon(
                                        Icons.auto_awesome,
                                        size: 18,
                                        color: accentColor,
                                      ),
                                      label: Text(
                                        '${suggestions.length} coincidencia(s) guardada(s)',
                                      ),
                                    ),
                                  if (showSplitUi)
                                    Chip(
                                      avatar: Icon(
                                        readyAllocationCount ==
                                                line.allocations.length
                                            ? Icons.check_circle_outline
                                            : Icons.inventory_outlined,
                                        size: 18,
                                        color:
                                            readyAllocationCount ==
                                                line.allocations.length
                                            ? Colors.green.shade700
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                      label: Text(
                                        '$readyAllocationCount/${line.allocations.length} particiones listas',
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Column(
                                children: line.allocations.asMap().entries.map((
                                  entry,
                                ) {
                                  final allocationIndex = entry.key;
                                  final allocation = entry.value;
                                  final allocationReady = _isAllocationComplete(
                                    allocation,
                                  );

                                  return Container(
                                    margin: EdgeInsets.only(
                                      bottom:
                                          allocationIndex ==
                                              line.allocations.length - 1
                                          ? 0
                                          : 12,
                                    ),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: allocationReady
                                          ? Colors.green.withValues(alpha: 0.08)
                                          : colorScheme.surfaceContainerHighest
                                                .withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: allocationReady
                                            ? Colors.green.withValues(
                                                alpha: 0.25,
                                              )
                                            : colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            final useStackedHeader =
                                                showSplitUi &&
                                                constraints.maxWidth < 430;
                                            final allocationLabel = showSplitUi
                                                ? 'Partición ${allocationIndex + 1}'
                                                : 'Asignación principal';
                                            final statusBadge = Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: allocationReady
                                                    ? Colors.green.withValues(
                                                        alpha: 0.14,
                                                      )
                                                    : colorScheme.surface,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                allocationReady
                                                    ? 'Lista'
                                                    : 'Pendiente',
                                                style: textTheme.labelSmall
                                                    ?.copyWith(
                                                      color: allocationReady
                                                          ? Colors
                                                                .green
                                                                .shade700
                                                          : colorScheme
                                                                .onSurfaceVariant,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            );
                                            final quantityChip = ActionChip(
                                              onPressed: () =>
                                                  _editAllocationQuantity(
                                                    index,
                                                    allocationIndex,
                                                  ),
                                              label: Text(
                                                '${allocation.cantidad} uds',
                                              ),
                                              avatar: const Icon(
                                                Icons.tune,
                                                size: 18,
                                              ),
                                            );
                                            final canRemoveAllocation =
                                                showSplitUi &&
                                                line.allocations.length > 1;

                                            Widget titleWidget() {
                                              return Expanded(
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Text(
                                                      allocationLabel,
                                                      maxLines: 1,
                                                      softWrap: false,
                                                      style: textTheme
                                                          .titleSmall
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }

                                            if (useStackedHeader) {
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      titleWidget(),
                                                      const SizedBox(width: 8),
                                                      statusBadge,
                                                    ],
                                                  ),
                                                  if (showSplitUi) ...[
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      children: [
                                                        quantityChip,
                                                        if (canRemoveAllocation)
                                                          const Spacer(),
                                                        if (canRemoveAllocation)
                                                          IconButton(
                                                            onPressed: () =>
                                                                _removeAllocation(
                                                                  index,
                                                                  allocationIndex,
                                                                ),
                                                            icon: const Icon(
                                                              Icons.close,
                                                            ),
                                                            tooltip:
                                                                'Eliminar partición',
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              );
                                            }

                                            return Row(
                                              children: [
                                                titleWidget(),
                                                const SizedBox(width: 8),
                                                statusBadge,
                                                if (showSplitUi) ...[
                                                  const SizedBox(width: 8),
                                                  quantityChip,
                                                ],
                                                if (canRemoveAllocation) ...[
                                                  const SizedBox(width: 4),
                                                  IconButton(
                                                    onPressed: () =>
                                                        _removeAllocation(
                                                          index,
                                                          allocationIndex,
                                                        ),
                                                    icon: const Icon(
                                                      Icons.close,
                                                    ),
                                                    tooltip:
                                                        'Eliminar partición',
                                                  ),
                                                ],
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                        if ((allocation.barcode
                                                ?.trim()
                                                .isNotEmpty ??
                                            false))
                                          Text(
                                            'EAN ${allocation.barcode}',
                                            style: textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          )
                                        else
                                          Text(
                                            'EAN opcional: escanéalo si te ayuda a identificar mejor el producto.',
                                            style: textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        const SizedBox(height: 6),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _formatAllocationProduct(
                                                      allocation,
                                                    ),
                                                    style: textTheme.bodyMedium,
                                                  ),
                                                  if ((allocation.productSource
                                                          ?.trim()
                                                          .isNotEmpty ??
                                                      false))
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 4,
                                                          ),
                                                      child: Text(
                                                        allocation
                                                            .productSource!,
                                                        style: textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color:
                                                                  allocation
                                                                      .usesKnownProduct
                                                                  ? Colors
                                                                        .green
                                                                        .shade700
                                                                  : colorScheme
                                                                        .onSurfaceVariant,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if ((allocation.imageUrl
                                                    ?.trim()
                                                    .isNotEmpty ??
                                                false)) ...[
                                              const SizedBox(width: 12),
                                              _buildAllocationImage(allocation),
                                            ],
                                          ],
                                        ),
                                        if (suggestions.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 10,
                                            ),
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: suggestions.map((
                                                match,
                                              ) {
                                                final isActive =
                                                    allocation.barcode ==
                                                    match.barcode;
                                                return ActionChip(
                                                  avatar: Icon(
                                                    isActive
                                                        ? Icons
                                                              .check_circle_outline
                                                        : Icons.history,
                                                    size: 18,
                                                  ),
                                                  label: Text(
                                                    _formatMatchLabel(match),
                                                  ),
                                                  onPressed: () =>
                                                      _assignMatchToAllocation(
                                                        index,
                                                        allocationIndex,
                                                        match,
                                                      ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        const SizedBox(height: 12),
                                        _buildAllocationMetaFields(
                                          allocation: allocation,
                                          lineIndex: index,
                                          allocationIndex: allocationIndex,
                                          textTheme: textTheme,
                                        ),
                                        if (showSplitUi &&
                                            line.allocations.length > 1)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 10,
                                            ),
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                ActionChip(
                                                  onPressed:
                                                      allocation.ubicacionId ==
                                                          null
                                                      ? null
                                                      : () =>
                                                            _copyAllocationLocationToOthers(
                                                              index,
                                                              allocationIndex,
                                                            ),
                                                  avatar: const Icon(
                                                    Icons.content_copy_outlined,
                                                    size: 18,
                                                  ),
                                                  label: const Text(
                                                    'Copiar ubicación',
                                                  ),
                                                ),
                                                ActionChip(
                                                  onPressed:
                                                      allocation
                                                              .fechaCaducidad ==
                                                          null
                                                      ? null
                                                      : () =>
                                                            _copyAllocationExpiryToOthers(
                                                              index,
                                                              allocationIndex,
                                                            ),
                                                  avatar: const Icon(
                                                    Icons.event_repeat_outlined,
                                                    size: 18,
                                                  ),
                                                  label: const Text(
                                                    'Copiar caducidad',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _scanBarcodeForAllocation(
                                                    index,
                                                    allocationIndex,
                                                  ),
                                              icon: const Icon(
                                                Icons.qr_code_scanner,
                                                size: 18,
                                              ),
                                              label: Text(
                                                (allocation.barcode
                                                            ?.trim()
                                                            .isNotEmpty ??
                                                        false)
                                                    ? 'Cambiar EAN'
                                                    : 'Escanear EAN',
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    _eanActionColor,
                                                side: BorderSide(
                                                  color: _eanActionColor
                                                      .withValues(alpha: 0.45),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _editAllocationProduct(
                                                    index,
                                                    allocationIndex,
                                                  ),
                                              icon: const Icon(
                                                Icons.edit_note,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                'Editar producto',
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                            if (allocation.barcode != null)
                                              TextButton.icon(
                                                onPressed: () =>
                                                    _clearBarcodeForAllocation(
                                                      index,
                                                      allocationIndex,
                                                    ),
                                                icon: const Icon(
                                                  Icons.restart_alt,
                                                  size: 18,
                                                ),
                                                label: const Text(
                                                  'Limpiar EAN',
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 14),
                              if (showSplitUi)
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _addAllocation(index),
                                        icon: const Icon(
                                          Icons.call_split,
                                          size: 18,
                                        ),
                                        label: const Text('Dividir línea'),
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _isReadyToPersist(line)
                                            ? 'Lista para persistir en inventario'
                                            : 'Completa reparto, producto, ubicación y caducidad en cada partición. El EAN es opcional.',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: _isReadyToPersist(line)
                                              ? Colors.green.shade700
                                              : colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  _isReadyToPersist(line)
                                      ? 'Lista para persistir en inventario'
                                      : 'Completa producto, ubicación y caducidad. El EAN es opcional.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: _isReadyToPersist(line)
                                        ? Colors.green.shade700
                                        : colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton(
          onPressed: isLoadingContext ? null : _finishMatching,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Guardar y Alimentar Inventario',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _DictionaryEntry {
  final int supermercadoId;
  final String ticketNombre;
  final List<_DictionaryProductMatch> matches;

  const _DictionaryEntry({
    required this.supermercadoId,
    required this.ticketNombre,
    required this.matches,
  });

  factory _DictionaryEntry.fromJson(Map<String, dynamic> json) {
    final rawMatches = json['matches'] as List<dynamic>?;
    final rawEans = json['eans'] as List<dynamic>?;

    final matches = rawMatches != null && rawMatches.isNotEmpty
        ? rawMatches
              .map(
                (entry) => _DictionaryProductMatch.fromJson(
                  Map<String, dynamic>.from(entry as Map),
                ),
              )
              .toList()
        : (rawEans ?? const [])
              .map(
                (ean) => _DictionaryProductMatch(
                  barcode: ean.toString(),
                  productName: null,
                  brand: null,
                  imageUrl: null,
                ),
              )
              .toList();

    return _DictionaryEntry(
      supermercadoId: json['supermercado_id'] as int? ?? 0,
      ticketNombre: json['ticket_nombre'] as String? ?? '',
      matches: matches,
    );
  }
}

class _DictionaryProductMatch {
  final String barcode;
  final String? productName;
  final String? brand;
  final String? imageUrl;

  const _DictionaryProductMatch({
    required this.barcode,
    required this.productName,
    required this.brand,
    required this.imageUrl,
  });

  bool get hasProductData {
    return (productName?.trim().isNotEmpty ?? false) ||
        (brand?.trim().isNotEmpty ?? false) ||
        (imageUrl?.trim().isNotEmpty ?? false);
  }

  factory _DictionaryProductMatch.fromJson(Map<String, dynamic> json) {
    return _DictionaryProductMatch(
      barcode: json['barcode'] as String? ?? '',
      productName: json['product_name'] as String?,
      brand: json['brand'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

class _ResolvedBarcodeProduct {
  final String productName;
  final String? brand;
  final String? imageUrl;
  final bool isLocalCatalogMatch;
  final String sourceLabel;

  const _ResolvedBarcodeProduct({
    required this.productName,
    required this.brand,
    required this.imageUrl,
    required this.isLocalCatalogMatch,
    required this.sourceLabel,
  });
}
