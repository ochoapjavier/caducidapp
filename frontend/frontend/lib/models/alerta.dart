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
  // Busca: {"producto": "Leche", "cantidad": 1, "fecha_caducidad": "2025-10-14"}
  factory AlertaItem.fromJson(Map<String, dynamic> json) {
    return AlertaItem(
      producto: json['producto'] as String,
      cantidad: json['cantidad'] as int,
      // Parsear el string ISO 8601 que envía FastAPI (ej. "2025-10-14")
      fechaCaducidad: DateTime.parse(json['fecha_caducidad'] as String), 
      ubicacion: json['ubicacion'] as String,
    );
  }
}