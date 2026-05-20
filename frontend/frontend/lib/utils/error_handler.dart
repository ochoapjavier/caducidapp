import 'package:flutter/material.dart';
import '../services/app_exceptions.dart';
import '../widgets/app_toast.dart';

class ErrorHandler {
  static void showError(BuildContext context, Object error) {
    String message = "Ha ocurrido un error inesperado";
    AppToastType toastType = AppToastType.error;

    if (error is NetworkException) {
      message = error.message;
      toastType = AppToastType.error;
    } else if (error is AuthException) {
      message = error.message;
      // Optionally redirect to login here
    } else if (error is ValidationException) {
      message = error.message;
      toastType = AppToastType.error;
    } else if (error is ServerException) {
      message = "El servidor tiene problemas. Inténtalo más tarde.";
      toastType = AppToastType.error;
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

    AppToast.show(
      context,
      message: message,
      type: toastType,
    );
  }
}
