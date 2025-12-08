import 'package:flutter/material.dart';
import '../services/app_exceptions.dart';

class ErrorHandler {
  static void showError(BuildContext context, Object error) {
    String message = "Ha ocurrido un error inesperado";
    Color backgroundColor = Colors.red;
    IconData icon = Icons.error_outline;

    if (error is NetworkException) {
      message = error.message;
      icon = Icons.wifi_off;
      backgroundColor = Colors.orange.shade800;
    } else if (error is AuthException) {
      message = error.message;
      icon = Icons.lock_outline;
      // Optionally redirect to login here
    } else if (error is ValidationException) {
      message = error.message;
      icon = Icons.warning_amber_rounded;
      backgroundColor = Colors.orange;
    } else if (error is ServerException) {
      message = "El servidor tiene problemas. Inténtalo más tarde.";
      icon = Icons.cloud_off;
    } else if (error is AppException) {
      message = error.message;
    } else {
      // Generic error
      message = error.toString();
      // Strip "Exception: " prefix if present
      if (message.startsWith("Exception: ")) {
        message = message.substring(11);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
