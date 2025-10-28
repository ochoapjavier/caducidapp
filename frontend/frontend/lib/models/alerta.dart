// frontend/lib/models/alerta.dart

class AlertaItem {
  // Las propiedades son finales (inmutables) para buena práctica
  final String producto;
  final int cantidad;
  final DateTime fechaCaducidad; // Dart usa DateTime para fechas
  final String ubicacion;

  AlertaItem({
    required this.producto,
    required this.cantidad,
    required this.fechaCaducidad,
    required this.ubicacion,
  });

  // Constructor de Fábrica: Convierte el JSON que viene de tu API a un objeto Dart
  factory AlertaItem.fromJson(Map<String, dynamic> json) {
    // Extraemos los objetos anidados para mayor claridad y seguridad.
    final productoObj = json['producto_obj'] as Map<String, dynamic>;
    final ubicacionObj = json['ubicacion_obj'] as Map<String, dynamic>;

    return AlertaItem(
      // Accedemos a la propiedad 'nombre' dentro de cada objeto anidado.
      producto: productoObj['nombre'] as String,
      ubicacion: ubicacionObj['nombre'] as String,

      // Las propiedades de nivel superior se mantienen igual.
      cantidad: json['cantidad_actual'] as int,
      // Parsear el string ISO 8601 que envía FastAPI (ej. "2025-10-14")
      fechaCaducidad: DateTime.parse(json['fecha_caducidad'] as String), 
    );
  }
}