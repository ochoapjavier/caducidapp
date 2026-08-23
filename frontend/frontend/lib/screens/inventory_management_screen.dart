import 'package:flutter/material.dart';
import 'package:frontend/widgets/add_item_view.dart';
import 'package:frontend/widgets/inventory_view.dart';
import 'package:frontend/widgets/remove_item_view.dart';
import 'package:frontend/screens/ticket_scanner_screen.dart';
import 'package:frontend/screens/matchmaker_screen.dart';
import 'package:frontend/screens/catalog_screen.dart';
import 'package:frontend/models/ticket_review_submission.dart';
import 'package:frontend/services/ticket_parser_service.dart';
import 'package:frontend/services/api_service.dart' as api;
import 'package:frontend/widgets/app_toast.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  final GlobalKey<InventoryViewState> _inventoryViewKey =
      GlobalKey<InventoryViewState>();

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

  void _startSmartReceiptFlow() async {
    final navigator = Navigator.of(context);
    final hadKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    FocusManager.instance.primaryFocus?.unfocus();
    if (hadKeyboardVisible) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
    }

    // 1. Abrimos el escáner
    final ParsedTicketResult? parsedResult = await navigator.push(
      MaterialPageRoute(builder: (context) => const TicketScannerScreen()),
    );

    if (parsedResult != null && parsedResult.items.isNotEmpty) {
      if (!mounted) return;
      // 2. Abrimos el Matchmaker para confirmar
      final TicketReviewSubmission? matchedResult = await navigator.push(
        MaterialPageRoute(
          builder: (context) => MatchmakerScreen(
            initialItems: parsedResult.items,
            guessedSupermercado: parsedResult.supermercado,
          ),
        ),
      );

      if (matchedResult != null && matchedResult.lineas.isNotEmpty) {
        try {
          AppToast.show(
            context,
            message: 'Guardando ticket e inventario...',
            type: AppToastType.info,
          );

          await api.saveTicketMatches(matchedResult);
          await _inventoryViewKey.currentState?.refreshInventory();

          if (!mounted) return;
          AppToast.show(
            context,
            message: '¡Ticket guardado y stock actualizado con éxito!',
            type: AppToastType.success,
          );
        } catch (e) {
          if (!mounted) return;
          AppToast.show(
            context,
            message: 'Error guardando ticket: $e',
            type: AppToastType.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_rounded),
            tooltip: 'Catálogo de Productos',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CatalogScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: InventoryView(
          key: _inventoryViewKey,
          onTicketAction: _startSmartReceiptFlow,
          onAddItem: _showAddItemModal,
          onRemoveItem: _showRemoveItemModal,
        ),
      ),
    );
  }
}

