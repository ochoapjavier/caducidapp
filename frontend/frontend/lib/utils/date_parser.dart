// frontend/lib/utils/date_parser.dart

/// Intenta convertir una cadena de texto en un objeto DateTime.
/// Robusto contra errores de OCR, prefijos comunes y diferentes formatos.
/// Versión mejorada con mejor manejo de formatos y validaciones.
DateTime? parseExpirationDate(String text) {
  // 1. Normalizar y limpiar texto no relevante
  var normalizedText = text.toUpperCase()
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'\s+'), ' ') // Unifica espacios
      .trim();

  // Eliminar prefijos comunes ANTES de procesar
  normalizedText = normalizedText.replaceAll(
      RegExp(r'\b(CAD|CADUCA|CADUCIDAD|EXP|EXPIRA|EXPIRES|VTO|VENCE|BB|BEST BEFORE|MFG|PROD|PRODUCTION|LOTE|LOT|USE BY|CONSUMIR ANTES|CONSUME BEFORE)[:\s]*', caseSensitive: false), '');
  
  // Reemplazo de separadores NO ESTÁNDAR a uno estándar (/)
  // Maneja: "11 01 26" -> "11/01/26" Y "09.04.2028" -> "09/04/2028"
  normalizedText = normalizedText
      .replaceAll(RegExp(r'[-.]'), '/') // Guiones y puntos a /
      .replaceAll(RegExp(r'\s+'), '/'); // Espacios a /
  
  // 2. Patrón DD/MM/YYYY o DD/MM/YY (formato más común en productos)
  final pattern1 = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2,4})');
  var match = pattern1.firstMatch(normalizedText);

  if (match != null) {
    try {
      final p1 = int.parse(match.group(1)!);
      final p2 = int.parse(match.group(2)!);
      var year = int.parse(match.group(3)!);

      // Ajustar año si es de 2 dígitos
      if (year < 100) {
        // Asumimos que años < 50 son 20xx, años >= 50 son 19xx
        year += (year < 50) ? 2000 : 1900;
      }
      
      // Validar que el año sea razonable (no más de 10 años en el futuro)
      final currentYear = DateTime.now().year;
      if (year < currentYear || year > currentYear + 10) {
        // Año fuera de rango razonable, continuar con siguiente patrón
      } else {
        // Intentamos DD/MM/YYYY primero (más común en español)
        if (p1 >= 1 && p1 <= 31 && p2 >= 1 && p2 <= 12) {
          try {
            return DateTime(year, p2, p1); // Crear fecha y validar
          } catch (e) {
            // Fecha inválida (ej: 31/02/2025), intentar formato inverso
          }
        }
        
        // Intentamos MM/DD/YYYY como fallback
        if (p1 >= 1 && p1 <= 12 && p2 >= 1 && p2 <= 31) {
          try {
            return DateTime(year, p1, p2);
          } catch (e) {
            // Tampoco es válida, continuar
          }
        }
      }
    } catch (e) { 
      // Error al parsear números, continuar
    }
  }

  // 3. Patrón MM/YYYY o MM/YY (Solo Mes y Año - común en algunos productos)
  final pattern2 = RegExp(r'^(\d{1,2})/(\d{2,4})$');
  match = pattern2.firstMatch(normalizedText);
  if (match != null) {
    try {
      final month = int.parse(match.group(1)!);
      var year = int.parse(match.group(2)!);

      if (year < 100) {
        year += (year < 50) ? 2000 : 1900;
      }

      final currentYear = DateTime.now().year;
      if (month >= 1 && month <= 12 && year >= currentYear && year <= currentYear + 10) {
        // Devuelve el último día del mes
        return DateTime(year, month + 1, 0); 
      }
    } catch (e) { 
      // Ignorar error
    }
  }

  // 4. Patrón de 8 dígitos sin separadores (YYYYMMDD o DDMMYYYY)
  final pattern3 = RegExp(r'(\d{8})');
  match = pattern3.firstMatch(normalizedText);
  if (match != null) {
    final dateStr = match.group(1)!;
    
    // Intentar YYYYMMDD
    try {
      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(4, 6));
      final day = int.parse(dateStr.substring(6, 8));
      
      final currentYear = DateTime.now().year;
      if (year >= currentYear && year <= currentYear + 10 && 
          month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    } catch (e) { 
      // Formato inválido
    }
    
    // Intentar DDMMYYYY
    try {
      final day = int.parse(dateStr.substring(0, 2));
      final month = int.parse(dateStr.substring(2, 4));
      final year = int.parse(dateStr.substring(4, 8));
      
      final currentYear = DateTime.now().year;
      if (year >= currentYear && year <= currentYear + 10 && 
          month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    } catch (e) { 
      // Formato inválido
    }
  }
  
  // 5. Patrón de 6 dígitos sin separadores (DDMMYY o YYMMDD)
  final pattern4 = RegExp(r'(\d{6})');
  match = pattern4.firstMatch(normalizedText);
  if (match != null) {
    final dateStr = match.group(1)!;
    
    // Intentar DDMMYY (más común en Europa)
    try {
      final day = int.parse(dateStr.substring(0, 2));
      final month = int.parse(dateStr.substring(2, 4));
      var year = int.parse(dateStr.substring(4, 6));
      year += (year < 50) ? 2000 : 1900;
      
      final currentYear = DateTime.now().year;
      if (year >= currentYear && year <= currentYear + 10 && 
          month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    } catch (e) { 
      // Formato inválido
    }
    
    // Intentar YYMMDD como fallback
    try {
      var year = int.parse(dateStr.substring(0, 2));
      year += (year < 50) ? 2000 : 1900;
      final month = int.parse(dateStr.substring(2, 4));
      final day = int.parse(dateStr.substring(4, 6));
      
      final currentYear = DateTime.now().year;
      if (year >= currentYear && year <= currentYear + 10 && 
          month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    } catch (e) { 
      // Formato inválido
    }
  }

  return null;
}