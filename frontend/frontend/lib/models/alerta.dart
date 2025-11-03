// frontend/lib/models/alerta.dart

class AlertaItem {
  final int id;
  final String producto;
  final String ubicacion;
  final int cantidad;
  final DateTime fechaCaducidad;

  AlertaItem({
    required this.id,
    required this.producto,
    required this.ubicacion,
    required this.cantidad,
    required this.fechaCaducidad,
  });

  // Constructor factory para crear una instancia desde un JSON
  factory AlertaItem.fromJson(Map<String, dynamic> json) {
    return AlertaItem(
      id: json['id_stock'],
      // Extraemos el nombre del objeto anidado 'producto_maestro'
      producto: json['producto_maestro']['nombre'],
      // Extraemos el nombre del objeto anidado 'ubicacion'
      ubicacion: json['ubicacion']['nombre'],
      // El nombre del campo ahora es 'cantidad_actual'
      cantidad: json['cantidad_actual'],
      fechaCaducidad: DateTime.parse(json['fecha_caducidad']),
    );
  }
}
