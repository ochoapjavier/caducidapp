// frontend/lib/utils/date_parser.dart

/// Intenta convertir una cadena de texto en un objeto DateTime.
/// Robusto contra errores de OCR, prefijos comunes y diferentes formatos.
DateTime? parseExpirationDate(String text) {
  // 1. Normalizar y limpiar texto no relevante
  var normalizedText = text.toUpperCase()
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'\s+'), ' '); // Unifica espacios

  // Reemplazo de separadores NO ESTÁNDAR a uno estándar (/)
  // Esto maneja: 11 01 26 -> 11/01/26 Y 09.04.2028 -> 09/04/2028
  normalizedText = normalizedText
      .replaceAll(RegExp(r'\s+'), '/') // Reemplaza espacios por /
      .replaceAll('.', '/');          // Reemplaza puntos por /
  
  // Eliminar prefijos comunes (EXP, CAD, MFG, etc.) para aislar la fecha.
  normalizedText = normalizedText.replaceAll(
      RegExp(r'\b(CAD|EXP|VTO|BB|MFG|PROD|LOTE|LOT|USE BY)\b[^\d/]*'), ' ');
  
  // 2. Patrón DD/MM/YYYY (o variantes)
  // Busca 1 o 2 dígitos, separador, 1 o 2 dígitos, separador, 2 o 4 dígitos.
  final pattern1 = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})');
  var match = pattern1.firstMatch(normalizedText);

  if (match != null) {
    try {
      final p1 = int.parse(match.group(1)!);
      final p2 = int.parse(match.group(2)!);
      var year = int.parse(match.group(3)!);

      if (year < 100) {
        year += 2000;
      }
      
      // Intentamos DD/MM/YYYY (Día primero - más común en español)
      if (p1 > 0 && p1 <= 31 && p2 > 0 && p2 <= 12 && year >= DateTime.now().year) {
        return DateTime(year, p2, p1);
      }
      // Intentamos MM/DD/YYYY (Mes primero)
      if (p2 > 0 && p2 <= 31 && p1 > 0 && p1 <= 12 && year >= DateTime.now().year) {
         return DateTime(year, p1, p2);
      }
    } catch (e) { /* Fallo en parsing, continuar con el siguiente patrón */ }
  }

  // 3. Patrón MM/YY o MM/YYYY (Solo Mes y Año)
  // Maneja el caso: 06/2024. Asumimos el último día de ese mes.
  final pattern2 = RegExp(r'(\d{1,2})[/-](\d{2,4})');
  match = pattern2.firstMatch(normalizedText);
  if (match != null) {
    try {
      final month = int.parse(match.group(1)!);
      var year = int.parse(match.group(2)!);

      if (year < 100) {
        year += 2000;
      }

      if (month > 0 && month <= 12 && year >= DateTime.now().year) {
        // Devuelve el último día del mes: DateTime(año, mes + 1, día 0 = último día del mes anterior)
        return DateTime(year, month + 1, 0); 
      }
    } catch (e) { /* ignore */ }
  }

  // 4. Patrón de 8 dígitos sin separadores (YYYYMMDD o DDMMYYYY)
  final pattern3 = RegExp(r'(\d{8})');
  match = pattern3.firstMatch(normalizedText);
  if (match != null) {
    final dateStr = match.group(1)!;
    try {
      // Intentamos formato YYYYMMDD
      return DateTime.parse('${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}');
    } catch (e) {
      try {
        // Intentamos formato DDMMYYYY
        return DateTime.parse('${dateStr.substring(4, 8)}-${dateStr.substring(2, 4)}-${dateStr.substring(0, 2)}');
      } catch (e) { /* ignore */ }
    }
  }

  return null;
}