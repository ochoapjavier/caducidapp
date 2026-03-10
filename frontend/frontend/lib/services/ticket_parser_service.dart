// frontend/lib/services/ticket_parser_service.dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:frontend/models/ticket_item.dart';

class ParsedTicketResult {
  final String supermercado;
  final List<TicketItem> items;
  ParsedTicketResult({required this.supermercado, required this.items});
}

class TicketParserService {
  /// Price: "0,85", "1.49", "-0,50" optionally followed by € + IVA letter (A/B/C)
  static final _priceRegex = RegExp(
    r'(-?\s*\d+[,\.]\d{2})\s*€?\s*(?:[A-Z]\b)?(?:\s|$)',
    caseSensitive: false,
  );

  /// Discount keywords
  static const _discountKw = [
    'DTO',
    'DESCUENTO',
    'PROMOCION',
    'REBAJA',
    'PROMO',
    'OFERTA',
    'LIDL PLUS',
  ];

  /// Patterns that definitively END item parsing (checked per combined row text)
  static final _stopPatterns = [
    RegExp(r'^TOTAL\b', caseSensitive: false),
    RegExp(r'^ENTREGA\b', caseSensitive: false),
    RegExp(r'^SUBTOTAL\b', caseSensitive: false),
    RegExp(r'TOTAL VENTA', caseSensitive: false),
    RegExp(r'IMPORTE TOTAL', caseSensitive: false),
    RegExp(r'\bA PAGAR\b', caseSensitive: false),
    RegExp(r'DESGLOSE DE IVA', caseSensitive: false),
    RegExp(r'^IVA%', caseSensitive: false),
    RegExp(r'IMP\.\s*:', caseSensitive: false),
    RegExp(r'RECIBO PARA EL CLIENTE', caseSensitive: false),
    RegExp(r'VENTA\s+Visa', caseSensitive: false),
    // NOTE: removed '^\d{8,}' - too aggressive, kills parsing on digital LIDL tickets
  ];

  /// Lines to skip silently (don't stop, just ignore)
  static final _skipPatterns = [
    RegExp(r'^NIF\s', caseSensitive: false),
    RegExp(r'^\d{5}\b', caseSensitive: false), // postal codes: 28914
    RegExp(
      r'^\s*EUR\s*$',
      caseSensitive: false,
    ), // standalone EUR column header
    RegExp(r'\bEUR\s*$', caseSensitive: false),
    RegExp(r'^EFECTIVO', caseSensitive: false),
    RegExp(r'^TARJETA', caseSensitive: false),
    RegExp(r'^CAMBIO', caseSensitive: false),
    RegExp(r'^IVA\b', caseSensitive: false),
    RegExp(r'B\.IMP', caseSensitive: false),
    RegExp(r'^Nº\b', caseSensitive: false),
    RegExp(r'\bFECHA\b', caseSensitive: false),
    RegExp(r'^IMPORTE\b', caseSensitive: false),
    RegExp(r'FORMA DE PAGO', caseSensitive: false),
    RegExp(r'DESCRIPCI[ÓO]N', caseSensitive: false),
    RegExp(r'CANTIDAD\s+PRECIO', caseSensitive: false),
    RegExp(r'^\d+%$', caseSensitive: false), // "4%", "21%"
    RegExp(r'^[A-D]\s+\d+%', caseSensitive: false), // "A  4%", "B 10%"
    RegExp(r'^Suma\b', caseSensitive: false),
    RegExp(r'GRACIAS', caseSensitive: false),
    RegExp(r'WWW\.', caseSensitive: false),
    RegExp(
      r'^\d+,\d+\s+\d+,\d+\s+\d+,\d+',
      caseSensitive: false,
    ), // IVA table triple numbers
    RegExp(r'000000', caseSensitive: false), // credit card padding
  ];

  static void _applyDiscountToItem(TicketItem item, double discountAmount) {
    if (discountAmount <= 0) {
      return;
    }

    final quantity = item.cantidad <= 0 ? 1 : item.cantidad;
    final currentLineTotal = item.precioUnitario * quantity;
    final discountedLineTotal = currentLineTotal - discountAmount;

    if (discountedLineTotal <= 0) {
      item.precioUnitario = 0;
      return;
    }

    item.precioUnitario = double.parse(
      (discountedLineTotal / quantity).toStringAsFixed(2),
    );
  }

  static ParsedTicketResult parseTicket(RecognizedText recognizedText) {
    void debug(String message) {
      print('TICKET DEBUG: $message');
    }

    if (recognizedText.blocks.isEmpty) {
      return ParsedTicketResult(supermercado: 'Desconocido', items: []);
    }

    // Flatten all lines
    final List<TextLine> allLines = [];
    for (var block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }
    allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    debug('blocks=${recognizedText.blocks.length} lines=${allLines.length}');
    for (int i = 0; i < allLines.length && i < 40; i++) {
      final line = allLines[i];
      debug(
        'LINE[$i] y=${line.boundingBox.top.round()} x=${line.boundingBox.left.round()} text="${line.text.trim()}"',
      );
    }

    // Detect supermarket using the first lines first, then broader heuristics.
    String detectedSupermercado = 'Desconocido';
    for (int i = 0; i < allLines.length && i < 40; i++) {
      final t = allLines[i].text.toUpperCase();
      if (t.contains('MERCADONA')) {
        detectedSupermercado = 'Mercadona';
        break;
      }
      if (t.contains('LIDL')) {
        detectedSupermercado = 'Lidl';
        break;
      }
      if (t.contains('DIA')) {
        detectedSupermercado = 'Dia';
        break;
      }
      if (t.contains('CARREFOUR')) {
        detectedSupermercado = 'Carrefour';
        break;
      }
      if (t.contains('ALDI')) {
        detectedSupermercado = 'Aldi';
        break;
      }
      if (t.contains('CONSUM')) {
        detectedSupermercado = 'Consum';
        break;
      }
      if (t.contains('EROSKI')) {
        detectedSupermercado = 'Eroski';
        break;
      }
      if (t.contains('ALCAMPO')) {
        detectedSupermercado = 'Alcampo';
        break;
      }
    }

    if (detectedSupermercado == 'Desconocido') {
      int lidlScore = 0;
      int diaScore = 0;
      int mercadonaScore = 0;

      for (final line in allLines) {
        final t = line.text.toUpperCase();
        if (t.contains('LIDL')) lidlScore += 5;
        if (t.contains('PROMO LIDL PLUS')) lidlScore += 4;
        if (t.contains('RECIBO PARA EL CLIENTE')) lidlScore += 1;
        if (t.contains('COMPRA REALIZADA EN')) lidlScore += 1;
        if (t.contains('WWW.LIDL.ES')) lidlScore += 3;

        if (t.contains('PRODUCTOS VENDIDOS POR DIA')) diaScore += 5;
        if (t.contains('DIA')) diaScore += 2;

        if (t.contains('MERCADONA')) mercadonaScore += 5;
      }

      if (lidlScore > diaScore &&
          lidlScore > mercadonaScore &&
          lidlScore >= 3) {
        detectedSupermercado = 'Lidl';
      } else if (diaScore > lidlScore &&
          diaScore > mercadonaScore &&
          diaScore >= 3) {
        detectedSupermercado = 'Dia';
      } else if (mercadonaScore > 0) {
        detectedSupermercado = 'Mercadona';
      }

      debug('scores lidl=$lidlScore dia=$diaScore mercadona=$mercadonaScore');
    }

    debug('detectedSupermercado=$detectedSupermercado');

    final List<TicketItem> items;
    switch (detectedSupermercado) {
      case 'Lidl':
        items = _parseLidl(allLines);
        // If LIDL-specific parser found nothing, fall back to generic
        // (happens with digital/app receipts that have different layout)
        if (items.isEmpty) {
          debug('Lidl parser empty, falling back to generic');
          items.addAll(_parseGeneric(allLines));
        }
        break;
      case 'Dia':
        items = _parseDia(allLines);
        if (items.isEmpty) {
          debug('Dia parser empty, falling back to generic');
          items.addAll(_parseGeneric(allLines));
        }
        break;
      default:
        items = _parseGeneric(allLines);
    }

    debug(
      'rawItems=${items.length} filteredItems=${items.where((i) => i.precioUnitario > 0.0 && i.nombre.length > 2).length}',
    );

    return ParsedTicketResult(
      supermercado: detectedSupermercado,
      items: items
          .where((i) => i.precioUnitario > 0.0 && i.nombre.length > 2)
          .toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIDL PARSER — Column-aware / row-grouping approach
  //
  // LIDL tickets use a two-column layout:
  //   LEFT column:  product name
  //   RIGHT column: price + IVA letter
  //
  // ML Kit often returns these as separate OCR blocks. We:
  // 1. Find the "EUR" column header to know where items start.
  // 2. Group all subsequent TextLines into "rows" by Y-coordinate proximity.
  // 3. Within each row, sort by X: leftmost = name, rightmost with price = price.
  // ─────────────────────────────────────────────────────────────────────────
  static List<TicketItem> _parseLidl(List<TextLine> lines) {
    void debug(String message) {
      print('LIDL DEBUG: $message');
    }

    double? extractLastPriceValue(String text) {
      final matches = _priceRegex.allMatches(text.toUpperCase()).toList();
      if (matches.isEmpty) return null;
      final priceStr = matches.last
          .group(1)!
          .replaceAll(' ', '')
          .replaceAll(',', '.');
      return double.tryParse(priceStr);
    }

    bool isStandaloneEurHeader(String text) {
      final normalized = text.trim().toUpperCase().replaceAll('€', 'EUR');
      return normalized == 'EUR';
    }

    bool isQuantityOnlyText(String text) {
      final normalized = text.trim().toUpperCase();
      return RegExp(r'^\d{1,2}$').hasMatch(normalized) ||
          RegExp(r'^\d+\s*UDS?\b').hasMatch(normalized);
    }

    bool isUnitTimesFragment(String text) {
      return RegExp(r'^\d+[,\.]\d+\s*[Xx]$').hasMatch(text.trim());
    }

    bool isWeightDetailText(String text) {
      final normalized = text.trim().toUpperCase();
      return RegExp(r'^\d+[,\.]\d+\s*KG\b').hasMatch(normalized) ||
          normalized.contains('EUR/KG');
    }

    String fixOcrToken(String token) {
      final hasLetters = RegExp(r'[A-ZÁÉÍÓÚÜÑ]').hasMatch(token);
      final hasDigits = RegExp(r'\d').hasMatch(token);
      if (hasLetters && hasDigits) {
        return token.replaceAll('0', 'O');
      }
      return token;
    }

    String cleanNameFragment(String text) {
      var cleaned = text.toUpperCase().trim();
      cleaned = cleaned.replaceAll(_priceRegex, ' ');
      cleaned = cleaned.replaceAll(
        RegExp(r'\bPROMO\s+LIDL\s+PLUS\b', caseSensitive: false),
        ' ',
      );
      cleaned = cleaned.replaceAll(
        RegExp(r'^PROMO\b', caseSensitive: false),
        ' ',
      );
      cleaned = cleaned.replaceAll(
        RegExp(r'\bDESC\.?\b', caseSensitive: false),
        ' ',
      );
      cleaned = cleaned.replaceAll(
        RegExp(r'\bACC\.\b', caseSensitive: false),
        ' ',
      );
      cleaned = cleaned.replaceAll(
        RegExp(r'\b\d+[,\.]\d+\s*X\s*\d+\b', caseSensitive: false),
        ' ',
      );
      cleaned = cleaned.replaceAll(
        RegExp(r'\bX\s*\d+\b', caseSensitive: false),
        ' ',
      );
      cleaned = cleaned.replaceAll(
        RegExp(r'\b\d+[,\.]\d+\s*EUR\s*/\s*KG\b', caseSensitive: false),
        ' ',
      );
      cleaned = cleaned.replaceAll(
        RegExp(r'\b\d+[,\.]\d+\s*%\b', caseSensitive: false),
        ' ',
      );
      cleaned = cleaned.replaceAll(RegExp(r'\b[A-C]\b\s*$'), ' ');
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
      return cleaned;
    }

    String normalizeName(String text) {
      var normalized = cleanNameFragment(text)
          .split(' ')
          .where((token) => token.isNotEmpty)
          .map(fixOcrToken)
          .join(' ');
      normalized = normalized
          .replaceAll(RegExp(r'\bMOL\s+IDO\b'), 'MOLIDO')
          .replaceAll(RegExp(r'\bA\s+JO\b'), 'AJO')
          .replaceAll(RegExp(r'\bGRANUL\s+ADO\b'), 'GRANULADO')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return normalized;
    }

    int extractQuantityFromRow(List<TextLine> rowLines, String fallbackText) {
      for (final line in rowLines) {
        final normalized = line.text.trim().toUpperCase();
        if (RegExp(r'^\d{1,2}$').hasMatch(normalized)) {
          return int.tryParse(normalized) ?? 1;
        }
        final udsMatch = RegExp(r'^(\d+)\s*UDS?\b').firstMatch(normalized);
        if (udsMatch != null) {
          return int.tryParse(udsMatch.group(1)!) ?? 1;
        }
      }

      final normalizedFallback = fallbackText.toUpperCase();
      final qtyMatch =
          RegExp(
            r'\bX\s*(\d+)\s*(?:UDS?\b|$)',
          ).firstMatch(normalizedFallback) ??
          RegExp(r'\b(\d+)\s*UDS?\b').firstMatch(normalizedFallback);
      return qtyMatch == null ? 1 : (int.tryParse(qtyMatch.group(1)!) ?? 1);
    }

    // Find the EUR header line index (marks start of item list)
    // Search the entire file - digital/app receipts can be very long
    int startIndex = 0;
    bool foundEurHeader = false;
    for (int i = 0; i < lines.length; i++) {
      if (isStandaloneEurHeader(lines[i].text)) {
        startIndex = i + 1;
        foundEurHeader = true;
        break;
      }
    }

    // Fallback para tickets de imagen grandes donde OCR no detecta bien "EUR"
    // pero sí empieza a devolver nombre + precio por separado.
    if (!foundEurHeader) {
      for (int i = 0; i < lines.length; i++) {
        final text = lines[i].text.trim().toUpperCase();
        final parsedPrice = extractLastPriceValue(text);
        if (parsedPrice != null &&
            parsedPrice > 0 &&
            !_skipPatterns.any((p) => p.hasMatch(text)) &&
            !_stopPatterns.any((p) => p.hasMatch(text)) &&
            !isWeightDetailText(text)) {
          startIndex = i > 0 ? i - 1 : 0;
          break;
        }
      }
    }

    debug(
      'foundEurHeader=$foundEurHeader startIndex=$startIndex totalLines=${lines.length}',
    );
    for (int i = startIndex; i < lines.length && i < startIndex + 60; i++) {
      final line = lines[i];
      debug(
        'LINE[$i] y=${line.boundingBox.top.round()} x=${line.boundingBox.left.round()} text="${line.text.trim()}"',
      );
    }

    // Agrupado más fino por proximidad real en Y.
    // Los tickets con promo tienen filas muy juntas; el bucket fijo de 25px podía
    // fusionar una línea de producto con su descuento de "PROMO LIDL PLUS".
    final sortedLines = lines.sublist(startIndex).toList()
      ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    final rowGroups = <List<TextLine>>[];
    const rowThreshold = 12.0;

    for (final line in sortedLines) {
      if (rowGroups.isEmpty) {
        rowGroups.add([line]);
        continue;
      }

      final currentRow = rowGroups.last;
      final currentAverageY =
          currentRow
              .map((l) => l.boundingBox.top.toDouble())
              .reduce((a, b) => a + b) /
          currentRow.length;

      if ((line.boundingBox.top - currentAverageY).abs() <= rowThreshold) {
        currentRow.add(line);
      } else {
        rowGroups.add([line]);
      }
    }

    debug('rowGroups=${rowGroups.length}');
    for (
      int rowIndex = 0;
      rowIndex < rowGroups.length && rowIndex < 80;
      rowIndex++
    ) {
      final row = rowGroups[rowIndex]
        ..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      final rowText = row
          .map(
            (l) =>
                '[x=${l.boundingBox.left.round()} y=${l.boundingBox.top.round()}] ${l.text.trim()}',
          )
          .join(' || ');
      debug('ROW[$rowIndex] $rowText');
    }

    final items = <TicketItem>[];
    bool parsing = true;
    final pendingNameParts = <String>[];

    for (final rowLines in rowGroups) {
      if (!parsing) break;

      // Sort by X within the row (left → right)
      rowLines.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

      // Build combined row text for stop/skip checking
      final combined = rowLines.map((l) => l.text.trim()).join(' ');
      final combinedUpper = combined.toUpperCase();

      if (_stopPatterns.any((p) => p.hasMatch(combinedUpper))) {
        debug('STOP row="$combinedUpper"');
        parsing = false;
        break;
      }
      if (_skipPatterns.any((p) => p.hasMatch(combinedUpper))) continue;
      if (combined.trim().length < 2) continue;

      final priceBearingLines = rowLines
          .where((l) => extractLastPriceValue(l.text.trim()) != null)
          .toList();

      final parsedRowPrice = extractLastPriceValue(combinedUpper);
      final isDiscount =
          _discountKw.any((kw) => combinedUpper.contains(kw)) ||
          (parsedRowPrice != null && parsedRowPrice < 0);

      if (isDiscount) {
        if (items.isNotEmpty && parsedRowPrice != null) {
          debug(
            'DISCOUNT row="$combinedUpper" parsedPrice=$parsedRowPrice applyingTo="${items.last.nombre}"',
          );
          _applyDiscountToItem(items.last, parsedRowPrice.abs());
        }
        continue;
      }

      // Si NO hay precio, lo tratamos como continuación del nombre del siguiente producto.
      if (priceBearingLines.isEmpty) {
        if (rowLines.every((line) => isWeightDetailText(line.text))) {
          continue;
        }
        final fragment = normalizeName(combinedUpper);
        if (fragment.isNotEmpty &&
            !_skipPatterns.any((p) => p.hasMatch(fragment)) &&
            !isQuantityOnlyText(fragment) &&
            !isUnitTimesFragment(fragment)) {
          pendingNameParts.add(fragment);
          debug('PENDING += "$fragment" from row="$combinedUpper"');
        }
        continue;
      }

      // Identify the PRICE part: the rightmost TextLine that contains a price
      String priceRaw = '';
      String nameRaw = '';

      if (priceBearingLines.isNotEmpty) {
        final sortedPriceLines = [...priceBearingLines]
          ..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
        final priceLine = sortedPriceLines.last;
        priceRaw = priceLine.text.trim();

        final nameFragments = rowLines
            .where((l) => !identical(l, priceLine))
            .map((l) => l.text.trim())
            .where((text) {
              final upper = text.toUpperCase();
              if (upper.isEmpty) return false;
              if (isQuantityOnlyText(upper)) return false;
              if (isUnitTimesFragment(upper)) return false;
              if (isWeightDetailText(upper)) return false;
              if (_discountKw.any((kw) => upper.contains(kw))) return false;
              if (upper == 'PROMO' || upper == 'DESC.' || upper == 'DESC')
                return false;
              return true;
            })
            .toList();
        nameRaw = nameFragments.join(' ');
      }

      // If we couldn't isolate a price block, treat the whole combined line
      if (priceRaw.isEmpty) {
        final allMatches = _priceRegex.allMatches(combinedUpper).toList();
        if (allMatches.isEmpty) continue;
        priceRaw = combinedUpper;
        nameRaw = combinedUpper.replaceAll(_priceRegex, '').trim();
      }

      // Parse price value
      final parsedPrice = extractLastPriceValue(priceRaw) ?? 0.0;

      // Clean name
      String name = normalizeName(nameRaw);
      // Remove kg sublines: "0,830KG X"
      if (RegExp(r'^\d+[,\.]\d+\s*KG\s*X', caseSensitive: false).hasMatch(name))
        continue;
      if (name == 'EUR/KG') continue;
      if (_skipPatterns.any((p) => p.hasMatch(name))) continue;

      if (parsedPrice <= 0) continue;

      if (pendingNameParts.isNotEmpty) {
        final mergedNameParts = <String>[];
        mergedNameParts.addAll(pendingNameParts);
        if (name.isNotEmpty) mergedNameParts.add(name);
        name = mergedNameParts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      }

      final quantity = extractQuantityFromRow(
        rowLines,
        '$nameRaw $combinedUpper',
      );

      if (name.isEmpty) {
        // Price-only row: pair with the pending name from the previous row
        if (pendingNameParts.isNotEmpty) {
          final pendingName = pendingNameParts
              .join(' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          debug(
            'ITEM price-only name="$pendingName" qty=$quantity total=$parsedPrice',
          );
          items.add(
            TicketItem(
              nombre: pendingName,
              precioUnitario: parsedPrice / quantity,
              cantidad: quantity,
            ),
          );
          pendingNameParts.clear();
        }
      } else {
        debug(
          'ITEM name="$name" qty=$quantity total=$parsedPrice pending=${pendingNameParts.length}',
        );
        items.add(
          TicketItem(
            nombre: name,
            precioUnitario: parsedPrice / quantity,
            cantidad: quantity,
          ),
        );
        pendingNameParts.clear();
      }
    }

    debug('itemsDetected=${items.length}');
    for (int i = 0; i < items.length && i < 50; i++) {
      final item = items[i];
      debug(
        'FINAL[$i] ${item.nombre} | qty=${item.cantidad} | unit=${item.precioUnitario}',
      );
    }

    return items;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DIA PARSER
  //
  // DIA digital PDF — tabla de 4 columnas:
  //   Col1: Nombre (1-2 líneas)  Col2: "N ud"  Col3: precio/ud  Col4: total+IVA
  //
  // Estructura real de coordenadas Y por producto (del OCR):
  //   Y≈2499  "LVQR LIGHT 16"   ← nombre línea 1
  //   Y≈2560  "1 ud"            ← trigger qty   ─┐ misma fila lógica
  //   Y≈2562  "2,99 €"          ← precio/ud      │ (Δ ≤ 60px entre sí)
  //   Y≈2562  "2,99 €"          ← total          ─┘
  //   Y≈2606  "250 G"           ← peso (ruido)
  //   Y≈2804  "GUANCIALE"       ← nombre siguiente producto
  //
  // Estrategia:
  //   Para cada línea trigger ("N ud"), el nombre del producto son las líneas
  //   cuya Y está dentro de ±MAX_NAME_DIST px del trigger Y,
  //   pero que NO son precio puro, peso, ni qty.
  //   MAX_NAME_DIST = 120px cubre nombre_línea_1 (Δ≈60) y nombre_línea_2 (Δ≈30)
  //   sin alcanzar el nombre del producto SIGUIENTE (Δ≥200px).
  //
  // Fallback a _parseGeneric para tickets físicos DIA (sin cabecera DESCRIPCIÓN).
  // ─────────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────
  // DIA PARSER
  //
  // El PDF digital de DIA tiene una tabla con 4 columnas. ML Kit las devuelve
  // como TextLines individuales. Según los datos reales del OCR, las columnas
  // se distinguen por su coordenada X:
  //
  //   X <  500  → Col1: Nombre del producto (1-3 líneas consecutivas)
  //   X ≈ 1050  → Col2: Cantidad  "N ud"          ← TRIGGER de cada producto
  //   X ≈ 1400  → Col3: Precio unitario
  //   X ≈ 1770  → Col4: Total (precio × cantidad) + letra IVA
  //
  // Estrategia:
  //   1. Delimitar la zona entre "Productos vendidos por Dia" y "Total venta Dia"
  //   2. Separar líneas de nombre (X < 500) de líneas de datos (X ≥ 500)
  //   3. Identificar triggers: líneas de datos que coinciden con "N ud"
  //   4. Para cada trigger:
  //      a. Precio total = línea con X > 1700 cuya Y esté a ±20px del trigger
  //      b. Nombre = líneas de nombre (X < 500) cuya Y es menor que la del
  //         trigger Y mayor que la del trigger anterior (o el inicio)
  //      c. Filtrar líneas de nombre que sean solo peso ("250 G", etc.)
  //
  // Fallback a _parseGeneric si no se encuentra la sección o no hay triggers.
  // ─────────────────────────────────────────────────────────────────────────
  static List<TicketItem> _parseDia(List<TextLine> lines) {
    final hasProductsSection = lines.any(
      (l) => RegExp(
        r'productos\s+vendidos\s+por\s+dia',
        caseSensitive: false,
      ).hasMatch(l.text),
    );

    if (!hasProductsSection) return _parseGeneric(lines);

    // ── 1. Delimitar zona de productos ────────────────────────────────────
    int startIndex = -1;
    int endIndex = lines.length;
    for (int i = 0; i < lines.length; i++) {
      final u = lines[i].text.trim().toUpperCase();
      if (startIndex == -1 &&
          RegExp(
            r'PRODUCTOS\s+VENDIDOS\s+POR\s+DIA',
            caseSensitive: false,
          ).hasMatch(u)) {
        startIndex = i + 1;
      }
      if (startIndex != -1 &&
          RegExp(r'TOTAL\s+VENTA\s+DIA', caseSensitive: false).hasMatch(u)) {
        endIndex = i;
        break;
      }
    }
    if (startIndex == -1) return _parseGeneric(lines);

    final zone = lines.sublist(startIndex, endIndex);

    // ── 2. Separar columna de nombre (X < 500) del resto ─────────────────
    // Umbral X calibrado con los datos reales: nombres en X≈85-100, datos en X≈1050+
    const int nameColMaxX = 500;
    const int quantityColMinX = 900;
    const int quantityColMaxX = 1250;

    final nameLines = zone
        .where((l) => l.boundingBox.left < nameColMaxX)
        .toList();
    final dataLines = zone
        .where((l) => l.boundingBox.left >= nameColMaxX)
        .toList();

    // ── 3. Identificar triggers de la columna cantidad ────────────────────
    final qtyRegex = RegExp(r'^(\d+)\s*uds?$', caseSensitive: false);
    final weightQtyRegex = RegExp(
      r'^\d+[,\.]\d+\s*(KG|KGS|G|GR|GRS|L|ML)\b',
      caseSensitive: false,
    );
    final triggers = dataLines.where((l) {
      final text = l.text.trim();
      final inQuantityColumn =
          l.boundingBox.left >= quantityColMinX &&
          l.boundingBox.left <= quantityColMaxX;
      return inQuantityColumn &&
          (qtyRegex.hasMatch(text) || weightQtyRegex.hasMatch(text));
    }).toList();

    if (triggers.isEmpty) return _parseGeneric(lines);

    bool shouldSkipDiaNameLine(String text) {
      final upper = text.trim().toUpperCase();
      if (upper.isEmpty) return true;
      if (RegExp(r'^DESCRIPCI[ÓO]N$', caseSensitive: false).hasMatch(upper))
        return true;
      if (RegExp(
        r'^PRODUCTOS\s+VENDIDOS\s+POR\s+DIA$',
        caseSensitive: false,
      ).hasMatch(upper)) {
        return true;
      }
      return false;
    }

    // Precomputar las Y de todos los triggers
    final triggerYs = triggers
        .map((t) => t.boundingBox.top.toDouble())
        .toList();

    final items = <TicketItem>[];

    for (int t = 0; t < triggers.length; t++) {
      final trig = triggers[t];
      final trigY = triggerYs[t];
      final triggerText = trig.text.trim().toUpperCase();
      final qtyMatch = qtyRegex.firstMatch(triggerText);
      final qty = qtyMatch == null
          ? 1
          : (int.tryParse(qtyMatch.group(1)!) ?? 1);
      final requiresQuantityReview = weightQtyRegex.hasMatch(triggerText);

      // ── Precio total: línea de datos con X > 1700 y Y a ±25px del trigger
      final totalLine = dataLines
          .where(
            (l) =>
                l.boundingBox.left > 1700 &&
                (l.boundingBox.top - trigY).abs() <= 25,
          )
          .toList();

      if (totalLine.isEmpty) continue;

      final totalText = totalLine.last.text.trim().toUpperCase();
      final priceMatches = _priceRegex.allMatches(totalText).toList();
      if (priceMatches.isEmpty) continue;
      final priceStr = priceMatches.last
          .group(1)!
          .replaceAll(' ', '')
          .replaceAll(',', '.');
      final parsedPrice = double.tryParse(priceStr) ?? 0.0;
      if (parsedPrice <= 0) continue;

      // ── Nombre: líneas de nombre (X < 500) asignadas a ESTE trigger.
      //
      // Cada producto ocupa la banda vertical comprendida entre el punto medio
      // con el trigger anterior y el punto medio con el trigger siguiente.
      // Así evitamos solapes como:
      //   GUANCIALE / SELECCIÓN  -> trigger en Y=2852
      //   HUMMUS RECETA / LIBANE -> trigger en Y=3144
      // donde "SELECCIÓN" (Y=2882) debe pertenecer solo al producto 2.
      //
      // Banda del producto t:
      //   lower = midpoint(prevTrigger, currentTrigger)
      //   upper = midpoint(currentTrigger, nextTrigger)
      //
      // Para el primero y el último usamos extremos abiertos.

      final double nameLowerBound;
      if (t == 0) {
        nameLowerBound = double.negativeInfinity;
      } else {
        final prevTrigY = triggerYs[t - 1];
        nameLowerBound = prevTrigY + (trigY - prevTrigY) / 2;
      }

      final double nameUpperBound;
      if (t == triggers.length - 1) {
        nameUpperBound = double.maxFinite;
      } else {
        final nextTrigY = triggerYs[t + 1];
        nameUpperBound = trigY + (nextTrigY - trigY) / 2;
      }

      final nameParts =
          nameLines
              .where((l) {
                final y = l.boundingBox.top.toDouble();
                return y >= nameLowerBound && y < nameUpperBound;
              })
              .where((l) => !shouldSkipDiaNameLine(l.text))
              .toList()
            ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

      final productName = nameParts
          .map((l) => l.text.trim().toUpperCase())
          .join(' ')
          .trim();

      if (productName.isNotEmpty && parsedPrice > 0) {
        items.add(
          TicketItem(
            nombre: productName,
            precioUnitario: parsedPrice / qty,
            cantidad: qty,
            requiereRevisionCantidad: requiresQuantityReview,
          ),
        );
      }
    }

    if (items.isNotEmpty) return items;
    return _parseGeneric(lines);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GENERIC PARSER (Mercadona, Carrefour, etc.)
  // ─────────────────────────────────────────────────────────────────────────
  static List<TicketItem> _parseGeneric(List<TextLine> lines) {
    final items = <TicketItem>[];
    bool parsing = true;

    for (int i = 0; i < lines.length; i++) {
      if (!parsing) break;
      final line = lines[i].text.trim().toUpperCase();

      if (_stopPatterns.any((p) => p.hasMatch(line))) {
        parsing = false;
        break;
      }
      if (_skipPatterns.any((p) => p.hasMatch(line))) continue;
      if (line.length < 2) continue;

      final matches = _priceRegex.allMatches(line).toList();
      if (matches.isEmpty) continue;

      final priceStr = matches.last
          .group(1)!
          .replaceAll(' ', '')
          .replaceAll(',', '.');
      final parsedPrice = double.tryParse(priceStr) ?? 0.0;

      final isDiscount =
          _discountKw.any((kw) => line.contains(kw)) || parsedPrice < 0;
      if (isDiscount && items.isNotEmpty) {
        _applyDiscountToItem(items.last, parsedPrice.abs());
        continue;
      }

      String nameOnly = line.replaceAll(_priceRegex, '').trim();
      if (RegExp(
        r'^\d+[,\.]\d+\s*KG\s*X',
        caseSensitive: false,
      ).hasMatch(nameOnly))
        continue;

      int qty = 1;
      final qtyMatch = RegExp(
        r'(?:^|\b)(\d+)\s*(?:ud|uds|x)\b',
        caseSensitive: false,
      ).firstMatch(nameOnly);
      if (qtyMatch != null) {
        qty = int.tryParse(qtyMatch.group(1)!) ?? 1;
        nameOnly = nameOnly.replaceAll(qtyMatch.group(0)!, '').trim();
      }

      final isJustWeight =
          nameOnly.isEmpty ||
          (RegExp(
                r'^\d+[,\.]?\d*\s*(G|KG|ML|L)?\s*$',
                caseSensitive: false,
              ).hasMatch(nameOnly) &&
              nameOnly.length < 8);

      if (!isJustWeight && !_skipPatterns.any((p) => p.hasMatch(nameOnly))) {
        items.add(
          TicketItem(
            nombre: nameOnly,
            precioUnitario: parsedPrice,
            cantidad: qty,
          ),
        );
      } else if (i > 0) {
        final prevLine = lines[i - 1].text.trim().toUpperCase();
        String fullName = prevLine;
        if (i > 1) {
          final pp = lines[i - 2].text.trim().toUpperCase();
          if (!_stopPatterns.any((p) => p.hasMatch(pp)) &&
              !_priceRegex.hasMatch(pp)) {
            fullName = '$pp $prevLine';
          }
        }
        if (!_skipPatterns.any((p) => p.hasMatch(fullName))) {
          items.add(
            TicketItem(
              nombre: fullName,
              precioUnitario: parsedPrice,
              cantidad: qty,
            ),
          );
        }
      }
    }
    return items;
  }
}
