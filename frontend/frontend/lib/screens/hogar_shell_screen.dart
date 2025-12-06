import 'package:flutter/material.dart';
import 'package:frontend/screens/inventory_management_screen.dart';
import 'package:frontend/screens/shopping_list_screen.dart';
import 'package:frontend/screens/profile_screen.dart'; // Importar ProfileScreen
import 'package:frontend/main.dart'; // Para AlertasDashboard

class HogarShellScreen extends StatefulWidget {
  final int hogarId;

  const HogarShellScreen({Key? key, required this.hogarId}) : super(key: key);

  @override
  State<HogarShellScreen> createState() => _HogarShellScreenState();
}

class _HogarShellScreenState extends State<HogarShellScreen> {
  int _selectedIndex = 0;
  
  // Keys para forzar refresco
  final GlobalKey<dynamic> _inventoryKey = GlobalKey(); 
  final GlobalKey<dynamic> _shoppingListKey = GlobalKey();

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const AlertasDashboard(), // Inicio (Alertas)
      InventoryManagementScreen(key: _inventoryKey), // Inventario
      ShoppingListScreen(key: _shoppingListKey, hogarId: widget.hogarId), // Lista
      ProfileScreen(hogarId: widget.hogarId), // Perfil (Reemplaza a Hogar)
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    // Refrescar la pantalla seleccionada si tiene método refresh
    if (index == 1) { // Inventario
      final state = _inventoryKey.currentState;
      if (state != null) {
        // Usamos dynamic o cast si definimos una interfaz, pero dynamic funciona si el método existe
        (state as dynamic).refresh();
      }
    } else if (index == 2) { // Lista
      final state = _shoppingListKey.currentState;
      if (state != null) {
        (state as dynamic).refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: theme.colorScheme.primary.withOpacity(0.1),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Inventario',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined),
              selectedIcon: Icon(Icons.shopping_cart),
              label: 'Lista',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
