// frontend/lib/utils/date_parser.dart

/// Intenta convertir una cadena de texto en un objeto DateTime.
/// Robusto contra errores de OCR, prefijos comunes y diferentes formatos.
DateTime? parseExpirationDate(String text) {
  if (text.isEmpty) return null;

  // 1. Limpieza inicial y normalización
  var normalizedText = text.toUpperCase()
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'\s+'), ' ') // Unifica espacios
      .trim();

  // Eliminar prefijos comunes (Español e Inglés)
  final prefixes = [
    'CAD', 'CADUCA', 'CADUCIDAD', 'EXP', 'EXPIRA', 'EXPIRES', 'VTO', 'VENCE', 
    'BB', 'BEST BEFORE', 'MFG', 'PROD', 'PRODUCTION', 'LOTE', 'LOT', 'USE BY', 
    'CONSUMIR ANTES', 'CONSUME BEFORE', 'VAL'
  ];
  final prefixPattern = RegExp(r'\b(' + prefixes.join('|') + r')[:\s]*', caseSensitive: false);
  normalizedText = normalizedText.replaceAll(prefixPattern, '');

  // 2. Corrección de errores comunes de OCR (Solo si parece un dígito)
  // Reemplazamos caracteres que parecen números pero no lo son
  normalizedText = _fixCommonOCRErrors(normalizedText);

  // 3. Normalización de separadores
  // Reemplazo de separadores NO ESTÁNDAR a uno estándar (/)
  // Maneja: "11 01 26" -> "11/01/26", "09.04.2028" -> "09/04/2028", "12-12-24" -> "12/12/24"
  normalizedText = normalizedText
      .replaceAll(RegExp(r'[-.]'), '/') // Guiones y puntos a /
      .replaceAll(RegExp(r'\s+'), '/'); // Espacios a /

  // --- ESTRATEGIAS DE PARSEO ---

  // A. Formato con Mes en Texto (ej. "12 ENE 24", "15 OCT 2025")
  // Este formato es muy robusto y debe priorizarse si se detecta
  final textMonthDate = _parseTextMonthDate(text); // Usamos el texto original para detectar meses
  if (textMonthDate != null) return textMonthDate;

  // B. Patrones Numéricos Estándar
  
  // B1. DD/MM/YYYY o DD/MM/YY (Prioridad 1)
  final pattern1 = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2,4})');
  var match = pattern1.firstMatch(normalizedText);

  if (match != null) {
    var d = int.tryParse(match.group(1)!);
    var m = int.tryParse(match.group(2)!);
    var y = int.tryParse(match.group(3)!);

    if (d != null && m != null && y != null) {
      y = _normalizeYear(y);
      
      // Validar DD/MM/YYYY (Formato Europeo - Prioritario)
      if (_isValidDate(d, m, y)) return DateTime(y, m, d);
      
      // Validar MM/DD/YYYY (Formato Americano - Fallback)
      if (_isValidDate(m, d, y)) return DateTime(y, d, m);
    }
  }

  // B2. MM/YYYY o MM/YY (Solo Mes y Año)
  final pattern2 = RegExp(r'^(\d{1,2})/(\d{2,4})$');
  match = pattern2.firstMatch(normalizedText);
  if (match != null) {
    var m = int.tryParse(match.group(1)!);
    var y = int.tryParse(match.group(2)!);

    if (m != null && y != null) {
      y = _normalizeYear(y);
      if (m >= 1 && m <= 12 && _isYearReasonable(y)) {
        // Devuelve el último día del mes
        return DateTime(y, m + 1, 0); 
      }
    }
  }

  // B3. Formatos compactos (YYYYMMDD, DDMMYYYY, DDMMYY)
  // Estos son peligrosos porque pueden confundirse con códigos de lote.
  // Solo los aceptamos si tienen longitud exacta y pasan validaciones estrictas.
  
  // YYYYMMDD (8 dígitos)
  final pattern3 = RegExp(r'(\d{8})');
  match = pattern3.firstMatch(normalizedText);
  if (match != null) {
    final s = match.group(1)!;
    // YYYYMMDD
    var y = int.parse(s.substring(0, 4));
    var m = int.parse(s.substring(4, 6));
    var d = int.parse(s.substring(6, 8));
    if (_isValidDate(d, m, y)) return DateTime(y, m, d);

    // DDMMYYYY
    d = int.parse(s.substring(0, 2));
    m = int.parse(s.substring(2, 4));
    y = int.parse(s.substring(4, 8));
    if (_isValidDate(d, m, y)) return DateTime(y, m, d);
  }

  // DDMMYY (6 dígitos)
  final pattern4 = RegExp(r'(\d{6})');
  match = pattern4.firstMatch(normalizedText);
  if (match != null) {
    final s = match.group(1)!;
    // DDMMYY
    var d = int.parse(s.substring(0, 2));
    var m = int.parse(s.substring(2, 4));
    var y = int.parse(s.substring(4, 6));
    y = _normalizeYear(y);
    if (_isValidDate(d, m, y)) return DateTime(y, m, d);
    
    // YYMMDD
    y = int.parse(s.substring(0, 2));
    y = _normalizeYear(y);
    m = int.parse(s.substring(2, 4));
    d = int.parse(s.substring(4, 6));
    if (_isValidDate(d, m, y)) return DateTime(y, m, d);
  }

  return null;
}

// --- UTILIDADES PRIVADAS ---

String _fixCommonOCRErrors(String text) {
  // Solo aplicamos correcciones si el caracter está rodeado de dígitos o separadores
  // Para evitar cambiar palabras reales (ej. "LOTE" -> "10TE")
  // Pero para simplificar, corregimos caracteres específicos que suelen ser números en fechas
  return text
      .replaceAll('O', '0')
      .replaceAll('D', '0')
      .replaceAll('I', '1')
      .replaceAll('L', '1')
      .replaceAll('Z', '2')
      .replaceAll('S', '5')
      .replaceAll('B', '8')
      .replaceAll('G', '6');
}

int _normalizeYear(int year) {
  if (year < 100) {
    // Pivot year: 50. < 50 -> 20xx, >= 50 -> 19xx
    return year + (year < 50 ? 2000 : 1900);
  }
  return year;
}

bool _isYearReasonable(int year) {
  final currentYear = DateTime.now().year;
  // Aceptamos desde 2 años atrás hasta 10 años en el futuro
  return year >= (currentYear - 2) && year <= (currentYear + 10);
}

bool _isValidDate(int day, int month, int year) {
  if (!_isYearReasonable(year)) return false;
  if (month < 1 || month > 12) return false;
  
  // Días por mes
  final daysInMonth = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  // Bisiesto
  if (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) {
    daysInMonth[2] = 29;
  }
  
  return day >= 1 && day <= daysInMonth[month];
}

DateTime? _parseTextMonthDate(String text) {
  // Busca patrones como "12 ENE 24" o "15 OCT"
  final months = {
    'ENE': 1, 'JAN': 1, 'FEB': 2, 'MAR': 3, 'ABR': 4, 'APR': 4, 'MAY': 5, 
    'JUN': 6, 'JUL': 7, 'AGO': 8, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DIC': 12, 'DEC': 12
  };
  
  final normalized = text.toUpperCase().replaceAll('.', ' ').replaceAll(',', ' ');
  
  for (var entry in months.entries) {
    if (normalized.contains(entry.key)) {
      // Encontramos un mes. Busquemos día y año alrededor.
      // Regex: (Dia)? MES (Año)?
      final pattern = RegExp(r'(\d{1,2})?\s*' + entry.key + r'\s*(\d{2,4})?');
      final match = pattern.firstMatch(normalized);
      
      if (match != null) {
        var d = match.group(1) != null ? int.tryParse(match.group(1)!) : null;
        var y = match.group(2) != null ? int.tryParse(match.group(2)!) : null;
        
        // Si falta el día, asumimos fin de mes? No, mejor requerir día o año.
        // Si tenemos "OCT 24", es Octubre 2024.
        // Si tenemos "12 OCT", es 12 Octubre del año actual (o próximo).
        
        int year = y != null ? _normalizeYear(y) : DateTime.now().year;
        int day = d ?? 1; // Si falta día, asumimos 1 (o fin de mes si es solo mes/año)
        
        if (d == null && y != null) {
          // Caso "OCT 24" -> Fin de mes
          return DateTime(year, entry.value + 1, 0);
        }
        
        if (_isValidDate(day, entry.value, year)) {
          return DateTime(year, entry.value, day);
        }
      }
    }
  }
  return null;
}