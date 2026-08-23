// frontend/lib/models/catalog_product.dart

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
  });

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
    );
  }
}
