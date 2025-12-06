// frontend/lib/models/alerta.dart

class AlertaItem {
  final int id;
  final String producto;
  final String ubicacion;
  final int cantidad;
  final DateTime fechaCaducidad;
  final int productoId;
  final String estadoProducto;

  AlertaItem({
    required this.id,
    required this.producto,
    required this.ubicacion,
    required this.cantidad,
    required this.fechaCaducidad,
    this.estadoProducto = 'cerrado',
    required this.productoId,
  });

  factory AlertaItem.fromJson(Map<String, dynamic> json) {
    return AlertaItem(
      id: json['id_stock'],
      producto: json['producto_maestro']['nombre'],
      ubicacion: json['ubicacion']['nombre'],
      cantidad: json['cantidad_actual'],
      fechaCaducidad: DateTime.parse(json['fecha_caducidad']),
      estadoProducto: json['estado_producto'] ?? 'cerrado',
      productoId: json['producto_maestro']['id_producto'],
    );
  }
}
