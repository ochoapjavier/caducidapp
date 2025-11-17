import 'package:flutter/material.dart';
import 'package:frontend/widgets/add_item_view.dart';
import 'package:frontend/widgets/inventory_view.dart';
import 'package:frontend/widgets/remove_item_view.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  int _selectedIndex = 0;

  // Clave global para poder llamar al método de refresco de InventoryView desde aquí.
  final GlobalKey<InventoryViewState> _inventoryViewKey = GlobalKey<InventoryViewState>();

  // Lista de widgets que se mostrarán en el cuerpo de la pantalla.
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      // Pasamos la clave a InventoryView
      InventoryView(key: _inventoryViewKey),
      const AddItemView(),
      const RemoveItemView(),
    ];
  }

  void _onItemTapped(int index) {
    // Si el usuario vuelve a la pestaña de inventario (índice 0), refrescamos la lista.
    if (index == 0) {
      _inventoryViewKey.currentState?.refreshInventory();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        indicatorColor: colorScheme.primary.withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Inventario',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: 'Añadir',
          ),
          NavigationDestination(
            icon: Icon(Icons.remove_circle_outline),
            selectedIcon: Icon(Icons.remove_circle),
            label: 'Eliminar',
          ),
        ],
      ),
    );
  }
}