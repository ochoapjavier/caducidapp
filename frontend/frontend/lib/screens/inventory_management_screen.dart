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
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Inventario',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            label: 'Añadir',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.remove_circle_outline),
            label: 'Eliminar',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}