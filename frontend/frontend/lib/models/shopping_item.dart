class ShoppingListItem {
  final int id;
  final int hogarId;
  final String productoNombre;
  final int? fkProducto;
  final int cantidad;
  final bool completado;
  final String addedBy;
  final DateTime createdAt;

  final Map<String, dynamic>? product;

  ShoppingListItem({
    required this.id,
    required this.hogarId,
    required this.productoNombre,
    this.fkProducto,
    required this.cantidad,
    required this.completado,
    required this.addedBy,
    required this.createdAt,
    this.product,
  });

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    return ShoppingListItem(
      id: json['id'],
      hogarId: json['hogar_id'],
      productoNombre: json['producto_nombre'],
      fkProducto: json['fk_producto'],
      cantidad: json['cantidad'],
      completado: json['completado'],
      addedBy: json['added_by'],
      createdAt: DateTime.parse(json['created_at']),
      product: json['producto'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hogar_id': hogarId,
      'producto_nombre': productoNombre,
      'fk_producto': fkProducto,
      'cantidad': cantidad,
      'completado': completado,
      'added_by': addedBy,
      'created_at': createdAt.toIso8601String(),
      'producto': product,
    };
  }
}
