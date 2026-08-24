import 'dart:convert';

class CatalogProduct {
  final int idProducto;
  final String? barcode;
  final String nombre;
  final String? marca;
  final String? imageUrl;
  final int? diasConsumoAbierto;
  final int hogarId;
  final int stockActual;
  final double? ratingPromedio;
  final int totalValoraciones;
  final double? miPuntuacion;
  final bool esFavorito;
  final String? miNota;
  final String? misTags;

  // Campos Nutricionales (MyRealFood / OpenFoodFacts / NutriScore)
  final int? novaGroup;
  final String? nutriscoreGrade;
  final String? alergenos;
  final int aditivosCount;
  final String? semaforoNutricional;
  final String? nutrientes100g;

  CatalogProduct({
    required this.idProducto,
    this.barcode,
    required this.nombre,
    this.marca,
    this.imageUrl,
    this.diasConsumoAbierto,
    required this.hogarId,
    required this.stockActual,
    this.ratingPromedio,
    required this.totalValoraciones,
    this.miPuntuacion,
    required this.esFavorito,
    this.miNota,
    this.misTags,
    this.novaGroup,
    this.nutriscoreGrade,
    this.alergenos,
    this.aditivosCount = 0,
    this.semaforoNutricional,
    this.nutrientes100g,
  });

  Map<String, dynamic>? get nutrientesMap {
    if (nutrientes100g == null || nutrientes100g!.isEmpty) return null;
    try {
      return jsonDecode(nutrientes100g!);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? get semaforoMap {
    if (semaforoNutricional == null || semaforoNutricional!.isEmpty) return null;
    try {
      return jsonDecode(semaforoNutricional!);
    } catch (_) {
      return null;
    }
  }

  List<String> get alergenosList {
    if (alergenos == null || alergenos!.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(alergenos!);
      return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    return CatalogProduct(
      idProducto: json['id_producto'] as int,
      barcode: json['barcode'] as String?,
      nombre: json['nombre'] as String? ?? 'Sin Nombre',
      marca: json['marca'] as String?,
      imageUrl: json['image_url'] as String?,
      diasConsumoAbierto: json['dias_consumo_abierto'] as int?,
      hogarId: json['hogar_id'] as int,
      stockActual: json['stock_actual'] as int? ?? 0,
      ratingPromedio: (json['rating_promedio'] as num?)?.toDouble(),
      totalValoraciones: json['total_valoraciones'] as int? ?? 0,
      miPuntuacion: (json['mi_puntuacion'] as num?)?.toDouble(),
      esFavorito: json['es_favorito'] as bool? ?? false,
      miNota: json['mi_nota'] as String?,
      misTags: json['mis_tags'] as String?,
      novaGroup: json['nova_group'] as int?,
      nutriscoreGrade: json['nutriscore_grade'] as String?,
      alergenos: json['alergenos'] as String?,
      aditivosCount: json['aditivos_count'] as int? ?? 0,
      semaforoNutricional: json['semaforo_nutricional'] as String?,
      nutrientes100g: json['nutrientes_100g'] as String?,
    );
  }

  CatalogProduct copyWith({
    int? idProducto,
    String? barcode,
    String? nombre,
    String? marca,
    String? imageUrl,
    int? diasConsumoAbierto,
    int? hogarId,
    int? stockActual,
    double? ratingPromedio,
    int? totalValoraciones,
    double? miPuntuacion,
    bool? esFavorito,
    String? miNota,
    String? misTags,
    int? novaGroup,
    String? nutriscoreGrade,
    String? alergenos,
    int? aditivosCount,
    String? semaforoNutricional,
    String? nutrientes100g,
  }) {
    return CatalogProduct(
      idProducto: idProducto ?? this.idProducto,
      barcode: barcode ?? this.barcode,
      nombre: nombre ?? this.nombre,
      marca: marca ?? this.marca,
      imageUrl: imageUrl ?? this.imageUrl,
      diasConsumoAbierto: diasConsumoAbierto ?? this.diasConsumoAbierto,
      hogarId: hogarId ?? this.hogarId,
      stockActual: stockActual ?? this.stockActual,
      ratingPromedio: ratingPromedio ?? this.ratingPromedio,
      totalValoraciones: totalValoraciones ?? this.totalValoraciones,
      miPuntuacion: miPuntuacion ?? this.miPuntuacion,
      esFavorito: esFavorito ?? this.esFavorito,
      miNota: miNota ?? this.miNota,
      misTags: misTags ?? this.misTags,
      novaGroup: novaGroup ?? this.novaGroup,
      nutriscoreGrade: nutriscoreGrade ?? this.nutriscoreGrade,
      alergenos: alergenos ?? this.alergenos,
      aditivosCount: aditivosCount ?? this.aditivosCount,
      semaforoNutricional: semaforoNutricional ?? this.semaforoNutricional,
      nutrientes100g: nutrientes100g ?? this.nutrientes100g,
    );
  }
}

