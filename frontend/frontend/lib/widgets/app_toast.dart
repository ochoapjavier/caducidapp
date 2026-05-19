import 'dart:async';

import 'package:flutter/material.dart';

enum AppToastType {
  info,
  success,
  error,
}

class AppToast {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    hide();

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        final topInset = MediaQuery.of(context).padding.top;
        return Positioned(
          left: 16,
          right: 16,
          top: 12 + topInset,
          child: _AppToastCard(
            message: message,
            type: type,
            actionLabel: actionLabel,
            onAction: onAction == null
                ? null
                : () {
                    hide();
                    onAction();
                  },
          ),
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);

    if (duration > Duration.zero) {
      _timer = Timer(duration, hide);
    }
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _AppToastCard extends StatelessWidget {
  const _AppToastCard({
    required this.message,
    required this.type,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AppToastType type;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Material(
        elevation: 10,
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(_iconForType(type),
                  color: _colorForType(type, colorScheme), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    textStyle: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return Icons.check_circle_rounded;
      case AppToastType.error:
        return Icons.error_outline_rounded;
      case AppToastType.info:
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _colorForType(AppToastType type, ColorScheme colorScheme) {
    switch (type) {
      case AppToastType.success:
        return colorScheme.tertiary;
      case AppToastType.error:
        return colorScheme.error;
      case AppToastType.info:
      default:
        return colorScheme.primary;
    }
  }
}
