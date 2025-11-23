// frontend/lib/models/ubicacion.dart

class Ubicacion {
  final int id;
  final String nombre;
  final bool esCongelador;

  Ubicacion({
    required this.id,
    required this.nombre,
    this.esCongelador = false,
  });

  // Constructor para crear desde el JSON de respuesta del backend
  factory Ubicacion.fromJson(Map<String, dynamic> json) {
    return Ubicacion(
      id: json['id_ubicacion'] as int,
      nombre: json['nombre'] as String,
      esCongelador: json['es_congelador'] as bool? ?? false,
    );
  }
}