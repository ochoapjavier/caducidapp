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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: _decrement,
                icon: const Icon(Icons.remove),
              ),
              Container(
                width: 80,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
              ),
              IconButton.filledTonal(
                onPressed: _increment,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (widget.showShoppingListOption) ...[
            const SizedBox(height: 24),
            CheckboxListTile(
              title: const Text('Añadir a la lista de la compra'),
              value: _addToShoppingList,
              onChanged: (val) => setState(() => _addToShoppingList = val ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              final qty = int.tryParse(_controller.text) ?? 1;
              widget.onConfirm(qty, _addToShoppingList);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_forever),
            label: const Text('Confirmar Salida'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
