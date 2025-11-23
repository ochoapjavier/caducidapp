// frontend/lib/utils/expiry_utils.dart
import 'package:flutter/material.dart';

/// Clase de utilidades para manejar la lógica de caducidad de productos
/// de forma centralizada y consistente en toda la aplicación.
class ExpiryUtils {
  // Umbrales de días para las alertas
  static const int criticalThreshold = 5; // Rojo: 0-5 días
  static const int warningThreshold = 10; // Amarillo: 6-10 días
  
  /// Calcula los días hasta la caducidad desde la fecha actual.
  /// Retorna un número negativo si el producto ya está caducado.
  static int daysUntilExpiry(DateTime expiryDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return expiry.difference(today).inDays;
  }
  
  /// Determina el color apropiado basado en los días hasta la caducidad.
  /// Se adapta automáticamente al modo claro/oscuro del tema.
  /// - Caducado (< 0 días): Morado (ajustado según brillo)
  /// - Crítico (0-5 días): Rojo
  /// - Advertencia (6-10 días): Amarillo/Naranja
  /// - Normal (> 10 días): Transparente (sin alerta)
  static Color getExpiryColor(DateTime expiryDate, ColorScheme colorScheme) {
    final days = daysUntilExpiry(expiryDate);
    final isDark = colorScheme.brightness == Brightness.dark;
    
    if (days < 0) {
      // Caducado: morado adaptado al tema
      // En modo oscuro: morado más claro para buen contraste
      // En modo claro: morado más oscuro
      return isDark 
          ? Colors.deepPurple.shade300  // Morado claro para fondo oscuro
          : Colors.deepPurple.shade700; // Morado oscuro para fondo claro
    } else if (days <= criticalThreshold) {
      // Crítico: rojo del tema (ya se adapta automáticamente)
      return colorScheme.error;
    } else if (days <= warningThreshold) {
      // Advertencia: amarillo/naranja adaptado
      return isDark
          ? Colors.amber.shade400  // Más claro en modo oscuro
          : Colors.amber.shade700; // Más oscuro en modo claro
    } else {
      // Normal: sin color de alerta
      return Colors.transparent;
    }
  }
  
  /// Obtiene la etiqueta de estado según los días hasta la caducidad.
  static String getStatusLabel(DateTime expiryDate) {
    final days = daysUntilExpiry(expiryDate);
    
    if (days < 0) {
      return 'Caducado';
    } else if (days == 0) {
      return 'Hoy';
    } else if (days <= criticalThreshold) {
      return 'Urgente';
    } else if (days <= warningThreshold) {
      return 'Próximo';
    } else {
      return 'Normal';
    }
  }
  
  /// Obtiene un ícono apropiado según el estado de caducidad.
  static IconData getStatusIcon(DateTime expiryDate) {
    final days = daysUntilExpiry(expiryDate);
    
    if (days < 0) {
      return Icons.block_rounded; // Bloqueado/caducado
    } else if (days <= criticalThreshold) {
      return Icons.warning_amber_rounded; // Advertencia urgente
    } else if (days <= warningThreshold) {
      return Icons.info_outline_rounded; // Información
    } else {
      return Icons.check_circle_outline_rounded; // OK
    }
  }
  
  /// Obtiene un mensaje descriptivo sobre el estado del producto.
  static String getExpiryMessage(DateTime expiryDate) {
    final days = daysUntilExpiry(expiryDate);
    
    if (days < 0) {
      final daysExpired = days.abs();
      return 'Caducado hace ${daysExpired} día${daysExpired == 1 ? '' : 's'}';
    } else if (days == 0) {
      return 'Caduca hoy';
    } else if (days == 1) {
      return 'Caduca mañana';
    } else if (days <= criticalThreshold) {
      return 'Caduca en $days días';
    } else if (days <= warningThreshold) {
      return 'Caduca en $days días';
    } else {
      return 'Caduca en $days días';
    }
  }
  
  /// Determina si un producto necesita mostrar alerta visual.
  static bool needsAlert(DateTime expiryDate) {
    final days = daysUntilExpiry(expiryDate);
    return days <= warningThreshold; // Muestra alerta para productos <= 10 días o caducados
  }

  // ============================================================================
  // FUNCIONES PARA ESTADOS DE PRODUCTO (abierto, congelado, cerrado)
  // ============================================================================

  /// Obtiene el color del badge según el estado del producto
  static Color getStateBadgeColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'abierto':
        return Colors.orange.shade700;
      case 'congelado':
        return Colors.blue.shade700;
      case 'cerrado':
      default:
        return Colors.transparent; // No mostrar badge para cerrado
    }
  }

  /// Obtiene el ícono según el estado del producto
  static IconData getStateIcon(String estado) {
    switch (estado.toLowerCase()) {
      case 'abierto':
        return Icons.open_in_new_rounded;
      case 'congelado':
        return Icons.ac_unit_rounded;
      case 'cerrado':
      default:
        return Icons.inventory_2_outlined;
    }
  }

  /// Obtiene la etiqueta de texto para el estado del producto
  static String getStateLabel(String estado) {
    switch (estado.toLowerCase()) {
      case 'abierto':
        return 'ABIERTO';
      case 'congelado':
        return 'CONGELADO';
      case 'cerrado':
      default:
        return 'CERRADO';
    }
  }

  /// Determina si se debe mostrar el badge de estado
  /// Solo se muestra para productos abiertos o congelados
  static bool shouldShowStateBadge(String estado) {
    return estado.toLowerCase() == 'abierto' || 
           estado.toLowerCase() == 'congelado';
  }

  /// Determina qué botones de acción mostrar según el estado
  static Map<String, bool> getAvailableActions(String estado) {
    final estadoLower = estado.toLowerCase();
    
    return {
      'abrir': estadoLower == 'cerrado',
      'congelar': estadoLower != 'congelado',
      'descongelar': estadoLower == 'congelado',
      'reubicar': true, // Siempre disponible
    };
  }
}
