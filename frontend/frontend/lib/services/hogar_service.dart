// frontend/lib/services/hogar_service.dart

import 'package:shared_preferences/shared_preferences.dart';

class HogarService {
  static const String _hogarActivoKey = 'hogar_activo_id';
  
  /// Guardar el hogar activo en el almacenamiento local
  Future<void> setHogarActivo(int hogarId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hogarActivoKey, hogarId);
  }
  
  /// Obtener el hogar activo (null si no hay ninguno seleccionado)
  Future<int?> getHogarActivo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_hogarActivoKey);
  }
  
  /// Limpiar el hogar activo (útil al cerrar sesión)
  Future<void> clearHogarActivo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hogarActivoKey);
  }
  
  /// Verificar si hay un hogar activo seleccionado
  Future<bool> tieneHogarActivo() async {
    final hogarId = await getHogarActivo();
    return hogarId != null;
  }
}
