// frontend/lib/models/supermercado.dart
class Supermercado {
  final int id;
  final String nombre;
  final String? logoUrl;
  final String? colorHex;

  Supermercado({
    required this.id,
    required this.nombre,
    this.logoUrl,
    this.colorHex,
  });

  factory Supermercado.fromJson(Map<String, dynamic> json) {
    return Supermercado(
      id: json['id_supermercado'] ?? 0,
      nombre: json['nombre'] ?? '',
      logoUrl: json['logo_url'],
      colorHex: json['color_hex'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_supermercado': id,
      'nombre': nombre,
      'logo_url': logoUrl,
      'color_hex': colorHex,
    };
  }
}
