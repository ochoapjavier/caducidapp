// frontend/lib/models/ubicacion.dart

class Ubicacion {
  final int id;
  final String nombre;

  Ubicacion({
    required this.id,
    required this.nombre,
  });

  // Constructor para crear desde el JSON de respuesta del backend
  factory Ubicacion.fromJson(Map<String, dynamic> json) {
    return Ubicacion(
      id: json['id_ubicacion'] as int,
      nombre: json['nombre'] as String,
    );
  }
}