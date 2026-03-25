import 'package:flutter/material.dart';

class QuantitySelectionDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final int maxQuantity;
  final int initialQuantity;
  final bool showShoppingListOption;
  final Function(int quantity, bool addToShoppingList) onConfirm;

  const QuantitySelectionDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.maxQuantity,
    this.initialQuantity = 1,
    this.showShoppingListOption = true,
    required this.onConfirm,
  });

  @override
  State<QuantitySelectionDialog> createState() => _QuantitySelectionDialogState();
}

class _QuantitySelectionDialogState extends State<QuantitySelectionDialog> {
  late TextEditingController _controller;
  bool _addToShoppingList = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuantity.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _increment() {
    final current = int.tryParse(_controller.text) ?? 1;
    if (current < widget.maxQuantity) {
      setState(() => _controller.text = (current + 1).toString());
    }
  }

  void _decrement() {
    final current = int.tryParse(_controller.text) ?? 1;
    if (current > 1) {
      setState(() => _controller.text = (current - 1).toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              16,
          left: 16,
          right: 16,
          top: 8,
        ),
        child: Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.remove_shopping_cart_outlined,
                          color: colorScheme.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cantidad a retirar',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            onPressed: _decrement,
                            icon: const Icon(Icons.remove),
                          ),
                          SizedBox(
                            width: 92,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: TextField(
                                controller: _controller,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onChanged: (val) => setState(() {}),
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: _increment,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.showShoppingListOption) ...[
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: CheckboxListTile(
                      title: const Text('Añadir a la lista de la compra'),
                      subtitle: const Text('Te ayuda a reponerlo mas tarde.'),
                      value: _addToShoppingList,
                      onChanged: (val) =>
                          setState(() => _addToShoppingList = val ?? false),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          final qty = int.tryParse(_controller.text) ?? 1;
                          widget.onConfirm(qty, _addToShoppingList);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Confirmar salida'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.error,
                          foregroundColor: colorScheme.onError,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
