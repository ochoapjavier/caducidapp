// frontend/lib/services/ticket_parser_service.dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:frontend/models/ticket_item.dart';

class ParsedTicketResult {
  final String supermercado;
  final List<TicketItem> items;
  ParsedTicketResult({required this.supermercado, required this.items});
}

class _DiaTrigger {
  final TextLine line;
  final int priority;
  const _DiaTrigger(this.line, this.priority);
}

class TicketParserService {
  /// Price: "0,85", "1.49", "-0,50" optionally followed by € + IVA letter (A/B/C)
  /// Allows optional space after comma/period to handle OCR artifacts like "2, 10"
  static final _priceRegex = RegExp(
    r'(-?\s*\d+[,\.]\s?\d{2})\s*€?\s*(?:[A-Z]\b)?(?:\s|$)',
    caseSensitive: false,
  );
  static const bool _debugGeneric = true;

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
    RegExp(r'^TUTAL\b', caseSensitive: false),
    // OCR misreads: I0TAL, T0TAL, 1OTAL, TOAL, TO7AL, etc.
    RegExp(r'^[IT1]?[O0][T7]?AL\b', caseSensitive: false),
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
    RegExp(r'I\.?V\.?A\.?', caseSensitive: false),
    RegExp(r'B\.IMP', caseSensitive: false),
    RegExp(r'BASE\s+IMPONIBLE', caseSensitive: false),
    RegExp(r'CUOTA\s+IVA', caseSensitive: false),
    RegExp(r'^Nº\b', caseSensitive: false),
    RegExp(r'\bFECHA\b', caseSensitive: false),
    RegExp(r'^IMPORTE\b', caseSensitive: false),
    RegExp(r'FORMA DE PAGO', caseSensitive: false),
    RegExp(r'D\s*E\s*S\s*C\s*R\s*I\s*P\s*C\s*I\s*[Ã“O]\s*N', caseSensitive: false),
    RegExp(r'CANTIDAD\s+PRECIO', caseSensitive: false),
    RegExp(r'P\.?\s*UNIT', caseSensitive: false),
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
    final maxLines = _debugGeneric ? allLines.length : 40;
    for (int i = 0; i < allLines.length && i < maxLines; i++) {
      final line = allLines[i];
      debug(
        'LINE[$i] y=${line.boundingBox.top.round()} x=${line.boundingBox.left.round()} text="${line.text.trim()}"',
      );
    }

    // Detect supermarket using the first lines first, then broader heuristics.
    String detectedSupermercado = 'Desconocido';
    for (int i = 0; i < allLines.length && i < maxLines; i++) {
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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // LIDL PARSER â€” Column-aware / row-grouping approach
  //
  // LIDL tickets use a two-column layout:
  //   LEFT column:  product name
  //   RIGHT column: price + IVA letter
  //
  // ML Kit often returns these as separate OCR blocks. We:
  // 1. Find the "EUR" column header to know where items start.
  // 2. Group all subsequent TextLines into "rows" by Y-coordinate proximity.
  // 3. Within each row, sort by X: leftmost = name, rightmost with price = price.
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
      final hasLetters = RegExp(r'[A-ZÁÃ‰ÍÃ“ÃšÃœÃ‘]').hasMatch(token);
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
          .replaceAll(RegExp(r'\bGRIEGOO\b'), 'GRIEGO')
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

      // Sort by X within the row (left â†’ right)
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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // DIA PARSER
  //
  // DIA digital PDF â€” tabla de 4 columnas:
  //   Col1: Nombre (1-2 líneas)  Col2: "N ud"  Col3: precio/ud  Col4: total+IVA
  //
  // Estructura real de coordenadas Y por producto (del OCR):
  //   Yâ‰ˆ2499  "LVQR LIGHT 16"   â† nombre línea 1
  //   Yâ‰ˆ2560  "1 ud"            â† trigger qty   â”€â” misma fila lógica
  //   Yâ‰ˆ2562  "2,99 €"          â† precio/ud      â”‚ (Î” â‰¤ 60px entre sí)
  //   Yâ‰ˆ2562  "2,99 €"          â† total          â”€â”˜
  //   Yâ‰ˆ2606  "250 G"           â† peso (ruido)
  //   Yâ‰ˆ2804  "GUANCIALE"       â† nombre siguiente producto
  //
  // Estrategia:
  //   Para cada línea trigger ("N ud"), el nombre del producto son las líneas
  //   cuya Y está dentro de Â±MAX_NAME_DIST px del trigger Y,
  //   pero que NO son precio puro, peso, ni qty.
  //   MAX_NAME_DIST = 120px cubre nombre_línea_1 (Î”â‰ˆ60) y nombre_línea_2 (Î”â‰ˆ30)
  //   sin alcanzar el nombre del producto SIGUIENTE (Î”â‰¥200px).
  //
  // Fallback a _parseGeneric para tickets físicos DIA (sin cabecera DESCRIPCIÃ“N).
  // El PDF digital de DIA tiene una tabla con 4 columnas. ML Kit las devuelve
  // como TextLines individuales. Según los datos reales del OCR, las columnas
  // se distinguen por su coordenada X:
  //
  //   X <  500  â†’ Col1: Nombre del producto (1-3 líneas consecutivas)
  //   X â‰ˆ 1050  â†’ Col2: Cantidad  "N ud"          â†  TRIGGER de cada producto
  //   X â‰ˆ 1400  â†’ Col3: Precio unitario
  //   X â‰ˆ 1770  â†’ Col4: Total (precio Ã— cantidad) + letra IVA
  //
  // Estrategia:
  //   1. Delimitar la zona entre "Productos vendidos por Dia" y "Total venta Dia"
  //   2. Separar líneas de nombre (X < 500) de líneas de datos (X â‰¥ 500)
  //   3. Identificar triggers: líneas de datos que coinciden con "N ud"
  //   4. Para cada trigger:
  //      a. Precio total = línea de datos con X > 1700 cuya Y esté a Â±20px del trigger
  //      b. Nombre = líneas de nombre (X < 500) cuya Y es menor que la del
  //         trigger Y mayor que la del trigger anterior (o el inicio)
  //      c. Filtrar líneas de nombre que sean solo peso ("250 G", etc.)
  //
  // Fallback a _parseGeneric si no se encuentra la sección o no hay triggers.
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static List<TicketItem> _parseDia(List<TextLine> lines) {
    void debugDia(String message) {
      if (_debugGeneric) {
        print('DIA DEBUG: $message');
      }
    }

    double estimateNameColumnMaxX(List<TextLine> zone) {
      final xs = zone.map((l) => l.boundingBox.left.toDouble()).toList()
        ..sort();
      if (xs.length < 6) return 600;
      double largestGap = 0;
      double cutoff = 600;
      for (var i = 1; i < xs.length; i++) {
        final gap = xs[i] - xs[i - 1];
        if (gap > largestGap) {
          largestGap = gap;
          cutoff = xs[i - 1] + gap / 2;
        }
      }
      if (largestGap < 180) {
        return 600;
      }
      return cutoff;
    }

    final diaProductsSectionRegex = RegExp(
      r'PRODUCTOS\s+VENDIDOS\s+POR\s+D[1IÍL]A',
      caseSensitive: false,
    );
    final diaSectionEndRegexes = [
      RegExp(r'TOTAL\s+VENTA\s+D[1IÍL]A', caseSensitive: false),
      RegExp(r'DESGLOSE\s+DE\s+IVA', caseSensitive: false),
      RegExp(r'FORMA\s+DE\s+PAGO', caseSensitive: false),
      RegExp(r'IVA\s+INCLUIDO', caseSensitive: false),
      RegExp(r'DATOS\s+DE\s+LA\s+OPERACI[Ã“O]N', caseSensitive: false),
      RegExp(r'OPERACI[Ã“O]N\s+CONTACTLESS', caseSensitive: false),
      RegExp(r'COMERCIAL\s+POSIPAR', caseSensitive: false),
      // Linea de puntos de total DIA: "...... 39,55 euro"
      RegExp(r'^\.{3,}', caseSensitive: false),
    ];

    final hasProductsSection = lines.any(
      (l) => diaProductsSectionRegex.hasMatch(l.text),
    );

    if (!hasProductsSection) return _parseGeneric(lines);

    // â”€â”€ 1. Delimitar zona de productos â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    int startIndex = -1;
    int endIndex = lines.length;
    for (int i = 0; i < lines.length; i++) {
      final u = lines[i].text.trim().toUpperCase();
      if (startIndex == -1 && diaProductsSectionRegex.hasMatch(u)) {
        startIndex = i + 1;
      }
      if (startIndex != -1 &&
          diaSectionEndRegexes.any((pattern) => pattern.hasMatch(u))) {
        endIndex = i;
        break;
      }
    }
    if (startIndex == -1) return _parseGeneric(lines);

    final zone = lines.sublist(startIndex, endIndex);

    // â”€â”€ 2. Separar columna de nombre del resto con umbral adaptativo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final nameColMaxX = estimateNameColumnMaxX(zone);

    final nameLines = zone
      .where((l) => l.boundingBox.left < nameColMaxX)
      .toList();
    final dataLines = zone
      .where((l) => l.boundingBox.left >= nameColMaxX)
      .toList();
    final zoneBottomY = zone.isEmpty
        ? double.maxFinite
        : zone
              .map((l) => l.boundingBox.bottom.toDouble())
              .reduce((a, b) => a > b ? a : b);

    // â”€â”€ 3. Identificar triggers de la columna cantidad â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final qtyRegex = RegExp(r'^(\d+)\s*uds?$', caseSensitive: false);
    final qtyTokenRegex = RegExp(
      r'(?:^|\b)(\d+)\s*U?D(?:S)?\b',
      caseSensitive: false,
    );
    final qtyOnlyRegex = RegExp(r'^\s*U?D(?:S)?\s*$', caseSensitive: false);
    final weightQtyRegex = RegExp(
      r'^\d+[,\.]\d+\s*(KG|KGS|G|GR|GRS|L|ML)\b',
      caseSensitive: false,
    );

    double? parsePriceValue(String text) {
      final matches = _priceRegex.allMatches(text.toUpperCase()).toList();
      if (matches.isEmpty) return null;
      final priceStr = matches.last
          .group(1)!
          .replaceAll(' ', '')
          .replaceAll(',', '.');
      return double.tryParse(priceStr);
    }

    final triggerCandidates = <_DiaTrigger>[];
    for (final line in zone) {
      final text = line.text.trim();
      final upper = text.toUpperCase();
      final isQty = qtyRegex.hasMatch(text) ||
          qtyTokenRegex.hasMatch(text) ||
          qtyOnlyRegex.hasMatch(text) ||
          weightQtyRegex.hasMatch(text);
      if (isQty) {
        triggerCandidates.add(_DiaTrigger(line, 2));
        continue;
      }

      final priceValue = parsePriceValue(upper);
      if (priceValue != null && priceValue > 0) {
        final isDiscount = _discountKw.any((kw) => upper.contains(kw));
        final hasPercent = upper.contains('%');
        if (!isDiscount && !hasPercent) {
          triggerCandidates.add(_DiaTrigger(line, 1));
        }
      }
    }

    triggerCandidates.sort(
      (a, b) => a.line.boundingBox.top.compareTo(b.line.boundingBox.top),
    );

    final triggers = <TextLine>[];
    const triggerMergeThreshold = 35.0;
    for (final candidate in triggerCandidates) {
      if (triggers.isEmpty) {
        triggers.add(candidate.line);
        continue;
      }
      final last = triggers.last;
      final yDelta =
          (candidate.line.boundingBox.top - last.boundingBox.top).abs();
      if (yDelta <= triggerMergeThreshold) {
        final lastIsQty = qtyRegex.hasMatch(last.text.trim()) ||
            qtyTokenRegex.hasMatch(last.text.trim()) ||
            qtyOnlyRegex.hasMatch(last.text.trim()) ||
            weightQtyRegex.hasMatch(last.text.trim());
        if (!lastIsQty && candidate.priority > 1) {
          triggers[triggers.length - 1] = candidate.line;
        }
        continue;
      }
      triggers.add(candidate.line);
    }

    debugDia(
      'zoneLines=${zone.length} nameColMaxX=${nameColMaxX.round()} triggers=${triggers.length}',
    );

    if (triggers.isEmpty) return _parseGeneric(lines);

    bool shouldSkipDiaNameLine(String text) {
      final upper = text.trim().toUpperCase();
      if (upper.isEmpty) return true;
      if (RegExp(r'^DESCRIPCI[Ã“O]N$', caseSensitive: false).hasMatch(upper))
        return true;
      // Solo filtra líneas de descuento DIA ("20% PATE NUESTRA ALACENA", etc.).
      // Requiere ≥3 letras tras el % para no filtrar sufijos de nombre como "92% B".
      if (RegExp(r'^\d{1,2}%\s+[A-ZÁÉÍÓÚÜÑ]{3,}').hasMatch(upper)) return true;
      if (_discountKw.any((kw) => upper.contains(kw))) return true;
      if (RegExp(r'-\s*\d+[,\.]\d{2}').hasMatch(upper)) return true;
      if (RegExp(
        r'^PRODUCTOS\s+VENDIDOS\s+POR\s+DIA$',
        caseSensitive: false,
      ).hasMatch(upper)) {
        return true;
      }
      if (RegExp(
        r'^\d+[,\.]?\d*\s*(KG|KGS|G|GR|GRS|L|ML)\b',
        caseSensitive: false,
      ).hasMatch(upper)) {
        return true;
      }
      if (diaSectionEndRegexes.any((pattern) => pattern.hasMatch(upper))) {
        return true;
      }
      return false;
    }

    String normalizeDiaName(String raw) {
      var normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
      normalized = normalized
          .replaceAll(RegExp(r'\bCABAL\s+IA\b'), 'CABALLA');
      return normalized;
    }

    // Precomputar las Y de todos los triggers
    final triggerYs = triggers
        .map((t) => t.boundingBox.top.toDouble())
        .toList();

    final items = <TicketItem>[];
    const maxNameDistanceAboveTrigger = 180.0;
    const maxNameDistanceBelowTrigger = 150.0;

    for (int t = 0; t < triggers.length; t++) {
      final trig = triggers[t];
      final trigY = triggerYs[t];
      final triggerText = trig.text.trim().toUpperCase();
        final qtyMatch =
          qtyRegex.firstMatch(triggerText) ?? qtyTokenRegex.firstMatch(triggerText);
        final qty = qtyMatch == null
          ? 1
          : (int.tryParse(qtyMatch.group(1)!) ?? 1);
      final requiresQuantityReview = weightQtyRegex.hasMatch(triggerText);

      // â”€â”€ Precio total: línea con precio más a la derecha y Y cercana al trigger
      final priceCandidates = dataLines
          .where((l) {
            final text = l.text.trim().toUpperCase();
            if (!_priceRegex.hasMatch(text)) return false;
            return (l.boundingBox.top - trigY).abs() <= 40;
          })
          .toList()
        ..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

      if (priceCandidates.isEmpty) {
        debugDia(
          'TRIGGER y=${trigY.round()} text="${trig.text.trim()}" -> no price candidate',
        );
        continue;
      }

      final totalText = priceCandidates.last.text.trim().toUpperCase();
      final priceMatches = _priceRegex.allMatches(totalText).toList();
      if (priceMatches.isEmpty) {
        debugDia(
          'TRIGGER y=${trigY.round()} text="${trig.text.trim()}" -> price parse failed',
        );
        continue;
      }
      final priceStr = priceMatches.last
          .group(1)!
          .replaceAll(' ', '')
          .replaceAll(',', '.');
      final parsedPrice = double.tryParse(priceStr) ?? 0.0;
      if (parsedPrice <= 0) {
        debugDia(
          'TRIGGER y=${trigY.round()} text="${trig.text.trim()}" -> parsedPrice=$parsedPrice',
        );
        continue;
      }

      // â”€â”€ Nombre: líneas de nombre (X < 500) asignadas a ESTE trigger.
      //
      // Cada producto ocupa la banda vertical comprendida entre el punto medio
      // con el trigger anterior y el punto medio con el trigger siguiente.
      // Así evitamos solapes como:
      //   GUANCIALE / SELECCIÃ“N  -> trigger en Y=2852
      //   HUMMUS RECETA / LIBANE -> trigger en Y=3144
      // donde "SELECCIÃ“N" (Y=2882) debe pertenecer solo al producto 2.
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
        nameUpperBound = zoneBottomY;
      } else {
        final nextTrigY = triggerYs[t + 1];
        nameUpperBound = trigY + (nextTrigY - trigY) / 2;
      }

      final nameParts =
          nameLines
              .where((l) {
                final y = l.boundingBox.top.toDouble();
                return y >= nameLowerBound &&
                    y < nameUpperBound &&
                    y >= trigY - maxNameDistanceAboveTrigger &&
                    y <= trigY + maxNameDistanceBelowTrigger;
              })
              .where((l) => !shouldSkipDiaNameLine(l.text))
              .toList()
            ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

      if (nameParts.isEmpty) {
        final fallbackNameParts = zone
            .where((l) {
              final y = l.boundingBox.top.toDouble();
              if (y < nameLowerBound || y >= nameUpperBound) return false;
              if (y < trigY - maxNameDistanceAboveTrigger) return false;
              if (y > trigY + maxNameDistanceBelowTrigger) return false;
              final text = l.text.trim().toUpperCase();
              if (text.isEmpty) return false;
              if (shouldSkipDiaNameLine(text)) return false;
              if (qtyRegex.hasMatch(text) || weightQtyRegex.hasMatch(text)) {
                return false;
              }
              if (_priceRegex.hasMatch(text)) return false;
              return RegExp(r'[A-ZÁÉÍÓÚÜÑ]').hasMatch(text);
            })
            .toList()
          ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

        if (fallbackNameParts.isNotEmpty) {
          nameParts
            ..clear()
            ..addAll(fallbackNameParts);
        }
      }

      final productName = normalizeDiaName(
        nameParts
            .map((l) => l.text.trim().toUpperCase())
            .join(' ')
            .trim(),
      );

      if (productName.isEmpty) {
        debugDia(
          'TRIGGER y=${trigY.round()} text="${trig.text.trim()}" -> empty name',
        );
      }

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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // GENERIC PARSER (Mercadona, Carrefour, etc.)
  //
  // Column-matching approach:
  //   1. Find product zone (between header row and TOTAL row)
  //   2. Classify each TextLine as "description" (has letters) or
  //      "price-only" (just digits/comma/dot, no letters)
  //   3. Match each description to its closest price(s) by Y-proximity
  //   4. Among matched prices, rightmost (by X) = line total
  //
  // This approach is immune to OCR returning description and price in
  // any Y-order, because we match by proximity rather than sequence.
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static List<TicketItem> _parseGeneric(List<TextLine> lines) {
    final items = <TicketItem>[];

    void debug(String message) {
      if (_debugGeneric) {
        print('GENERIC DEBUG: $message');
      }
    }

    // â”€â”€ Helper: extract ALL prices from a text string â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    List<double> extractAllPrices(String text) {
      final matches = _priceRegex.allMatches(text.toUpperCase()).toList();
      final prices = <double>[];
      for (final m in matches) {
        final priceStr = m.group(1)!.replaceAll(' ', '').replaceAll(',', '.');
        final p = double.tryParse(priceStr);
        if (p != null && p > 0) prices.add(p);
      }
      return prices;
    }

    Match? leadingQtyMatch(String text) {
      return RegExp(r'^(\d{1,2})\s+(?=[A-ZÁÃ‰ÍÃ“ÃšÃœÃ‘])').firstMatch(text);
    }

    Match? inlineQtyMatch(String text) {
      return RegExp(
        r'(?:^|\b)(\d+)\s*(?:ud|uds|x)\b',
        caseSensitive: false,
      ).firstMatch(text);
    }

    String normalizeName(String text) {
      var normalized = text
          .replaceAll(RegExp(r'\bOK\b'), '0%')
          .replaceAll(RegExp(r'\bO%\b'), '0%')
          .replaceFirst(RegExp(r'^1\s*\+\s*'), '+ ')
          .trim();

      final tokens = normalized
          .split(' ')
          .where((token) => token.isNotEmpty)
          .map((token) {
        final hasLetters = RegExp(r'[A-ZÁÃ‰ÍÃ“ÃšÃœÃ‘]').hasMatch(token);
        final hasDigits = RegExp(r'\d').hasMatch(token);
        if (hasLetters && hasDigits) {
          return token.replaceAll('0', 'O');
        }
        return token;
      }).toList();

      normalized = tokens.join(' ');
      normalized = normalized
          .replaceAll(RegExp(r'\bLASANA\b'), 'LASAÑA')
          .replaceAll(RegExp(r'\bMADRILENA\b'), 'MADRILEÑA')
          .replaceAll(RegExp(r'\bESPINADAS\b'), 'ESPINACAS')
          .replaceAll(RegExp(r'\bGRIEGOO\b'), 'GRIEGO')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      return normalized;
    }

    bool isLikelyProductName(String text) {
      final upper = text.trim().toUpperCase();
      if (upper.length < 2) return false;
      if (_skipPatterns.any((p) => p.hasMatch(upper))) return false;
      if (_stopPatterns.any((p) => p.hasMatch(upper))) return false;
      if (!RegExp(r'[A-ZÁÃ‰ÍÃ“ÃšÃœÃ‘]').hasMatch(upper)) return false;
      if (RegExp(r'^\d+[\s\d,\.]*$').hasMatch(upper)) return false;
      if (RegExp(r'\b(IVA|IMPONIBLE|CUOTA|TOTAL|SUBTOTAL|PAGO|CAMBIO)\b')
          .hasMatch(upper)) {
        return false;
      }
      return true;
    }

    bool isHeaderLine(String upper) {
      return upper.contains('DESCRIP') ||
          upper.contains('P. UNIT') ||
          upper.contains('P UNIT') ||
          RegExp(r'IMP\.\s*\(\s*[E€]\s*\)').hasMatch(upper);
    }

    // â”€â”€ Step 1: Find product zone â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // Zone starts after the "Descripción / P. Unit" header or the first
    // line that looks like a product. Zone ends at TOTAL.
    int zoneStart = 0;
    int zoneEnd = lines.length;
    bool foundHeader = false;

    for (int i = 0; i < lines.length; i++) {
      final text = lines[i].text.trim().toUpperCase();
      // Check for header markers (Descripción, P. Unit)
      if (!foundHeader && isHeaderLine(text)) {
        zoneStart = i + 1;
        foundHeader = true;
        continue;
      } else if (!foundHeader && _skipPatterns.any((p) => p.hasMatch(text))) {
        zoneStart = i + 1; // start AFTER this line
      }
      // Check for TOTAL (end of products)
      if (_stopPatterns.any((p) => p.hasMatch(text))) {
        zoneEnd = i;
        debug('STOP at line[$i] "$text"');
        break;
      }
    }

    if (zoneStart >= zoneEnd) zoneStart = 0;
    debug('productZone: [$zoneStart, $zoneEnd) of ${lines.length} lines');

    // â”€â”€ Step 2: Classify lines in product zone â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // Description lines: contain letters (product names)
    // Price-only lines: only digits, comma, dot, spaces (prices)
    final descLines = <TextLine>[];
    final priceLines = <TextLine>[];

    for (int i = zoneStart; i < zoneEnd; i++) {
      final l = lines[i];
      final text = l.text.trim();
      final upper = text.toUpperCase();

      // Skip/stop check
      if (isHeaderLine(upper)) continue;
      if (_skipPatterns.any((p) => p.hasMatch(upper))) continue;

      final nameAfterPrice = upper.replaceAll(_priceRegex, '').trim();
      final hasLetters = RegExp(r'[A-ZÁÃ‰ÍÃ“ÃšÃœÃ‘]').hasMatch(nameAfterPrice);
      final hasPrice = _priceRegex.hasMatch(upper);

      if (hasLetters) {
        // Description line (may also contain inline prices)
        descLines.add(l);
      } else if (hasPrice) {
        // Price-only line
        priceLines.add(l);
      }
    }

    debug('descLines=${descLines.length} priceLines=${priceLines.length}');

    // â”€â”€ Step 3: Match prices to descriptions by Y-proximity â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // For each price line, find the closest description line.
    // This ensures each price is paired with exactly one description.
    // Max Y-distance tolerance: 70px handles OCR jitter while avoiding
    // cross-product matches (adjacent products are ~80-100px apart).
    const maxYDistance = 70.0;

    // Map: description index â†’ list of matched price values
    final descPriceMap = <int, List<double>>{};
    // Track which price lines are claimed
    final claimedPrices = <int>{};

    // Sort price lines by distance to their closest desc for greedy matching
    // Process closest matches first to avoid conflicts
    final priceDescPairs = <({int priceIdx, int descIdx, double dist})>[];
    for (int p = 0; p < priceLines.length; p++) {
      final priceY = priceLines[p].boundingBox.top;
      for (int d = 0; d < descLines.length; d++) {
        final descY = descLines[d].boundingBox.top;
        final dist = (priceY - descY).abs();
        if (dist <= maxYDistance) {
          priceDescPairs.add((priceIdx: p, descIdx: d, dist: dist));
        }
      }
    }
    // Sort by distance (closest first)
    priceDescPairs.sort((a, b) => a.dist.compareTo(b.dist));

    // Greedy assignment: each price goes to its closest unclaimed desc
    for (final pair in priceDescPairs) {
      if (claimedPrices.contains(pair.priceIdx)) continue;
      claimedPrices.add(pair.priceIdx);
      final prices = extractAllPrices(priceLines[pair.priceIdx].text.trim());
      descPriceMap.putIfAbsent(pair.descIdx, () => []).addAll(prices);
    }

    // Also extract inline prices from description lines themselves
    for (int d = 0; d < descLines.length; d++) {
      final text = descLines[d].text.trim().toUpperCase();
      final inlinePrices = extractAllPrices(text);
      if (inlinePrices.isNotEmpty) {
        descPriceMap.putIfAbsent(d, () => []).addAll(inlinePrices);
      }
    }

    // â”€â”€ Step 4: Build items from matched descriptions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // Process descriptions in Y-order
    final sortedDescIndices = List.generate(descLines.length, (i) => i);
    sortedDescIndices.sort(
      (a, b) => descLines[a].boundingBox.top.compareTo(
        descLines[b].boundingBox.top,
      ),
    );

    for (final d in sortedDescIndices) {
      final desc = descLines[d];
      final text = desc.text.trim().toUpperCase();
      final prices = descPriceMap[d] ?? [];

      // Skip descriptions with no matched prices
      if (prices.isEmpty) {
        debug('SKIP (no price) "$text"');
        continue;
      }

      // Extract name: remove any inline price patterns
      String nameRaw = text.replaceAll(_priceRegex, '').trim();

      // Discount handling
      final isDiscount =
          _discountKw.any((kw) => nameRaw.contains(kw)) ||
          prices.any((p) => p < 0);
      if (isDiscount && items.isNotEmpty) {
        final discountAmount = prices.where((p) => p > 0).fold(0.0, (a, b) => a + b);
        if (discountAmount > 0) {
          _applyDiscountToItem(items.last, discountAmount);
        }
        continue;
      }

      // Skip weight-detail lines
      if (RegExp(r'^\d+[,\.]\d+\s*KG\s*X', caseSensitive: false)
          .hasMatch(nameRaw)) {
        continue;
      }

      // Skip non-product names
      if (!isLikelyProductName(nameRaw)) {
        debug('SKIP (not product) "$nameRaw"');
        continue;
      }

      // Extract quantity from name
      int qty = 1;
      bool qtyFromLeading = false;
      String nameForQty = nameRaw
          .replaceFirst(RegExp(r'^I\s+'), '1 ')
          .replaceFirst(RegExp(r'^I\b'), '1');
      final leadingMatch = leadingQtyMatch(nameForQty);
      if (leadingMatch != null) {
        qty = int.tryParse(leadingMatch.group(1)!) ?? 1;
        nameRaw = nameForQty.replaceFirst(leadingMatch.group(0)!, '').trim();
        nameForQty = nameRaw;
        qtyFromLeading = qty > 1;
      }
      final inlineMatch = inlineQtyMatch(nameForQty);
      if (inlineMatch != null) {
        qty = int.tryParse(inlineMatch.group(1)!) ?? 1;
        nameRaw = nameForQty.replaceAll(inlineMatch.group(0)!, '').trim();
        qtyFromLeading = false;
      }

      nameRaw = normalizeName(nameRaw);

      if (nameRaw.isEmpty) continue;

      final lineTotal = prices.reduce((a, b) => a > b ? a : b);
      final minPrice = prices.reduce((a, b) => a < b ? a : b);

      if (qty == 1 && prices.length >= 2 && minPrice > 0) {
        final inferred = lineTotal / minPrice;
        final inferredInt = inferred.round();
        if (inferredInt > 1 && (inferred - inferredInt).abs() <= 0.05) {
          qty = inferredInt;
        }
      }

      // Compute unit price
      double unitPrice = lineTotal;
      if (qty > 1 && prices.length >= 2) {
        if ((minPrice * qty - lineTotal).abs() <= 0.05) {
          unitPrice = minPrice;
        } else {
          unitPrice = double.parse((lineTotal / qty).toStringAsFixed(2));
        }
      } else if (qty > 1 && qtyFromLeading) {
        // Leading qty "1 CORTES 8L" with single price = unit price
        unitPrice = lineTotal;
      }

      // Skip weight-only fragments
      final isJustWeight =
          nameRaw.isEmpty ||
          (RegExp(r'^\d+[,\.]?\d*\s*(G|KG|ML|L)?\s*$', caseSensitive: false)
                  .hasMatch(nameRaw) &&
              nameRaw.length < 8);

      if (!isJustWeight &&
          !_skipPatterns.any((p) => p.hasMatch(nameRaw))) {
        items.add(
          TicketItem(
            nombre: nameRaw,
            precioUnitario: unitPrice,
            cantidad: qty,
          ),
        );
        debug('ITEM name="$nameRaw" qty=$qty unit=$unitPrice prices=$prices');
      }
    }

    return items;
  }
}

