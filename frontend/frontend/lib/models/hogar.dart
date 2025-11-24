// frontend/lib/models/hogar.dart

class Hogar {
  final int idHogar;
  final String nombre;
  final String icono;
  final int totalMiembros;
  final String rol; // 'admin', 'miembro', 'invitado'
  
  Hogar({
    required this.idHogar,
    required this.nombre,
    required this.icono,
    required this.totalMiembros,
    required this.rol,
  });
  
  factory Hogar.fromJson(Map<String, dynamic> json) {
    return Hogar(
      idHogar: json['id_hogar'],
      nombre: json['nombre'],
      icono: json['icono'] ?? 'home',
      totalMiembros: json['total_miembros'] ?? 0,
      rol: json['rol'] ?? 'miembro',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id_hogar': idHogar,
      'nombre': nombre,
      'icono': icono,
      'total_miembros': totalMiembros,
      'rol': rol,
    };
  }
}

class HogarDetalle {
  final int idHogar;
  final String nombre;
  final String icono;
  final String codigoInvitacion;
  final List<Miembro> miembros;
  
  HogarDetalle({
    required this.idHogar,
    required this.nombre,
    required this.icono,
    required this.codigoInvitacion,
    required this.miembros,
  });
  
  factory HogarDetalle.fromJson(Map<String, dynamic> json) {
    return HogarDetalle(
      idHogar: json['id_hogar'],
      nombre: json['nombre'],
      icono: json['icono'] ?? 'home',
      codigoInvitacion: json['codigo_invitacion'],
      miembros: (json['miembros'] as List)
          .map((m) => Miembro.fromJson(m))
          .toList(),
    );
  }
}

class Miembro {
  final String userId;
  final String apodo;
  final String rol;
  final String fechaUnion;
  
  Miembro({
    required this.userId,
    required this.apodo,
    required this.rol,
    required this.fechaUnion,
  });
  
  factory Miembro.fromJson(Map<String, dynamic> json) {
    return Miembro(
      userId: json['user_id'],
      apodo: json['apodo'] ?? 'Usuario',
      rol: json['rol'],
      fechaUnion: json['fecha_union'],
    );
  }
}
