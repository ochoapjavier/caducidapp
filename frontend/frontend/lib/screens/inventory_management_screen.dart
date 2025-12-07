import 'package:flutter/material.dart';
import 'package:frontend/widgets/add_item_view.dart';
import 'package:frontend/widgets/inventory_view.dart';
import 'package:frontend/widgets/remove_item_view.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  final GlobalKey<InventoryViewState> _inventoryViewKey = GlobalKey<InventoryViewState>();

  Future<void> refresh() async {
    await _inventoryViewKey.currentState?.refreshInventory();
  }

  void _showAddItemModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const AddItemView(), 
          ),
        ),
      ),
    ).then((_) => _inventoryViewKey.currentState?.refreshInventory());
  }

  void _showRemoveItemModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const RemoveItemView(),
          ),
        ),
      ),
    ).then((_) => _inventoryViewKey.currentState?.refreshInventory());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
      ),
      body: InventoryView(
        key: _inventoryViewKey,
        onAddItem: _showAddItemModal,
        onRemoveItem: _showRemoveItemModal,
      ),
    );
  }
}