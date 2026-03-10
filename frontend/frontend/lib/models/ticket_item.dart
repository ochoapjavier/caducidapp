// frontend/lib/models/ticket_item.dart

class TicketItem {
  String nombre;
  double precioUnitario;
  int cantidad;
  bool requiereRevisionCantidad;
  
  // Lista de códigos EAN asignados a esta línea de ticket
  List<String> eansAsignados;

  TicketItem({
    required this.nombre,
    required this.precioUnitario,
    this.cantidad = 1,
    this.requiereRevisionCantidad = false,
    List<String>? eansAsignados,
  }) : eansAsignados = eansAsignados ?? [];

  // Precio total de la línea (precioUnitario * cantidad)
  double get precioTotal => precioUnitario * cantidad;

  // Precio dividido si hay múltiples productos agrupados
  // Ej: 4 batidos de vainilla + 4 de chocolate = 8 items totales.
  // El precio unitario "real" de cada artículo físico será total / eansAsignados.length
  double get precioUnitarioReal {
    if (eansAsignados.isEmpty) return precioUnitario;
    return precioTotal / eansAsignados.length;
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'precioUnitario': precioUnitario,
      'cantidad': cantidad,
      'eansAsignados': eansAsignados,
    };
  }

  factory TicketItem.fromJson(Map<String, dynamic> json) {
    return TicketItem(
      nombre: json['nombre'],
      precioUnitario: json['precioUnitario'].toDouble(),
      cantidad: json['cantidad'] ?? 1,
      requiereRevisionCantidad: json['requiereRevisionCantidad'] ?? false,
      eansAsignados: List<String>.from(json['eansAsignados'] ?? []),
    );
  }
}
