import 'dart:convert';

class NutriScanResult {
  final String barcode;
  final String nombre;
  final String? marca;
  final String? imageUrl;
  final int? novaGroup;
  final String? nutriscoreGrade;
  final List<String> alergenosList;
  final int aditivosCount;
  final Map<String, dynamic>? semaforoMap;
  final Map<String, dynamic>? nutrientesMap;

  NutriScanResult({
    required this.barcode,
    required this.nombre,
    this.marca,
    this.imageUrl,
    this.novaGroup,
    this.nutriscoreGrade,
    required this.alergenosList,
    required this.aditivosCount,
    this.semaforoMap,
    this.nutrientesMap,
  });

  factory NutriScanResult.fromJson(Map<String, dynamic> json) {
    // Parser de alérgenos
    List<String> parsedAlergenos = [];
    if (json['alergenos'] != null) {
      if (json['alergenos'] is String) {
        try {
          final List<dynamic> decoded = jsonDecode(json['alergenos']);
          parsedAlergenos = decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      } else if (json['alergenos'] is List) {
        parsedAlergenos = (json['alergenos'] as List).map((e) => e.toString()).toList();
      }
    }

    // Parser de semáforo nutricional
    Map<String, dynamic>? parsedSemaforo;
    if (json['semaforo_nutricional'] != null) {
      if (json['semaforo_nutricional'] is String) {
        try {
          parsedSemaforo = jsonDecode(json['semaforo_nutricional']);
        } catch (_) {}
      } else if (json['semaforo_nutricional'] is Map) {
        parsedSemaforo = Map<String, dynamic>.from(json['semaforo_nutricional']);
      }
    }

    // Parser de nutrientes 100g
    Map<String, dynamic>? parsedNutrientes;
    if (json['nutrientes_100g'] != null) {
      if (json['nutrientes_100g'] is String) {
        try {
          parsedNutrientes = jsonDecode(json['nutrientes_100g']);
        } catch (_) {}
      } else if (json['nutrientes_100g'] is Map) {
        parsedNutrientes = Map<String, dynamic>.from(json['nutrientes_100g']);
      }
    }

    return NutriScanResult(
      barcode: json['barcode'] as String? ?? '',
      nombre: json['nombre'] as String? ?? 'Producto',
      marca: json['marca'] as String?,
      imageUrl: json['image_url'] as String?,
      novaGroup: json['nova_group'] as int?,
      nutriscoreGrade: json['nutriscore_grade'] as String?,
      alergenosList: parsedAlergenos,
      aditivosCount: json['aditivos_count'] as int? ?? 0,
      semaforoMap: parsedSemaforo,
      nutrientesMap: parsedNutrientes,
    );
  }
}
