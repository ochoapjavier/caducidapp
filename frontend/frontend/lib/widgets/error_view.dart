import 'package:flutter/material.dart';
import '../services/app_exceptions.dart';

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final bool isCompact;

  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String title = 'Algo salió mal';
    String message = 'Ha ocurrido un error inesperado.';
    IconData icon = Icons.error_outline_rounded;

    if (error is NetworkException) {
      title = 'Sin conexión';
      message = 'Verifica tu conexión a internet e inténtalo de nuevo.';
      icon = Icons.wifi_off_rounded;
    } else if (error is ServerException) {
      title = 'Servidor no disponible';
      message = 'Estamos teniendo problemas para conectar con el servidor.';
      icon = Icons.cloud_off_rounded;
    } else if (error is AuthException) {
      title = 'Sesión expirada';
      message = 'Por favor, inicia sesión nuevamente.';
      icon = Icons.lock_clock_outlined;
    } else if (error is ValidationException) {
      title = 'Datos incorrectos';
      message = error.toString().replaceAll('ValidationException: ', '');
      icon = Icons.warning_amber_rounded;
    } else {
      // Clean up generic exception string and ensure no sensitive info is shown
      String rawMessage = error.toString();
      if (rawMessage.contains('ClientException') || rawMessage.contains('SocketException')) {
         title = 'Error de Conexión';
         message = 'No se pudo conectar con el servidor. Verifica tu conexión.';
         icon = Icons.wifi_off_rounded;
      } else if (rawMessage.contains('http') || rawMessage.contains('uri=')) {
         // Hide URLs and technical details
         title = 'Error Técnico';
         message = 'Ha ocurrido un error interno. Por favor, inténtalo más tarde.';
         icon = Icons.build_circle_outlined;
      } else {
         message = rawMessage.replaceAll('Exception: ', '');
      }
    }

    if (isCompact) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colorScheme.error, size: 32),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
              ),
              if (onRetry != null)
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reintentar'),
                ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
