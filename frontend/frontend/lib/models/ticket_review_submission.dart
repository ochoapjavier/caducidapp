import 'ticket_item.dart';

class TicketLineAllocation {
  int cantidad;
  String? barcode;
  int? ubicacionId;
  DateTime? fechaCaducidad;
  String productName;
  String? brand;
  String? imageUrl;
  bool usesKnownProduct;
  String? productSource;

  TicketLineAllocation({
    required this.cantidad,
    required this.productName,
    this.barcode,
    this.ubicacionId,
    this.fechaCaducidad,
    this.brand,
    this.imageUrl,
    this.usesKnownProduct = false,
    this.productSource,
  });

  Map<String, dynamic> toJson() {
    return {
      'cantidad': cantidad,
      'barcode': barcode,
      'ubicacion_id': ubicacionId,
      'fecha_caducidad': fechaCaducidad?.toIso8601String().split('T').first,
      'product_name': productName,
      'brand': brand,
      'image_url': imageUrl,
    };
  }
}

class TicketReviewLine {
  TicketItem item;
  List<TicketLineAllocation> allocations;

  TicketReviewLine({
    required this.item,
    List<TicketLineAllocation>? allocations,
  }) : allocations = allocations ?? [];

  Map<String, dynamic> toJson() {
    return {
      ...item.toJson(),
      'asignaciones': allocations
          .map((allocation) => allocation.toJson())
          .toList(),
      'requiereRevisionCantidad': item.requiereRevisionCantidad,
    };
  }
}

class TicketReviewSubmission {
  final List<TicketReviewLine> lineas;
  final int? supermercadoId;
  final String supermercadoNombre;

  TicketReviewSubmission({
    required this.lineas,
    this.supermercadoId,
    required this.supermercadoNombre,
  });
}
