import 'package:flutter/material.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/screens/inventory_management_screen.dart';
import 'package:frontend/screens/catalog_screen.dart';
import 'package:frontend/screens/shopping_list_screen.dart';
import 'package:frontend/screens/profile_screen.dart';

class HogarShellScreen extends StatefulWidget {
  final int hogarId;

  const HogarShellScreen({Key? key, required this.hogarId}) : super(key: key);

  @override
  State<HogarShellScreen> createState() => _HogarShellScreenState();
}

class _HogarShellScreenState extends State<HogarShellScreen> {
  int _selectedIndex = 0;
  
  // Keys para forzar refresco
  final GlobalKey<dynamic> _homeKey = GlobalKey();
  final GlobalKey<dynamic> _inventoryKey = GlobalKey(); 
  final GlobalKey<dynamic> _catalogKey = GlobalKey();
  final GlobalKey<dynamic> _shoppingListKey = GlobalKey();
  final GlobalKey<dynamic> _profileKey = GlobalKey();

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(key: _homeKey), // Inicio
      InventoryManagementScreen(key: _inventoryKey), // Inventario
      CatalogScreen(key: _catalogKey), // Catálogo Maestro & Ratings
      ShoppingListScreen(key: _shoppingListKey, hogarId: widget.hogarId), // Lista
      ProfileScreen(key: _profileKey, hogarId: widget.hogarId), // Perfil
    ];

  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    // Refrescar la pantalla seleccionada si tiene método refresh
    final key = switch (index) {
      0 => _homeKey,
      1 => _inventoryKey,
      2 => _catalogKey,
      3 => _shoppingListKey,
      4 => _profileKey,
      _ => null,
    };
    if (key != null) {
      final state = key.currentState;
      if (state != null && state is dynamic) {
        try {
          (state as dynamic).refresh();
        } catch (_) {}
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
            if (theme.brightness == Brightness.light)
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
          backgroundColor: theme.brightness == Brightness.dark 
              ? const Color(0xFF0F172A) // Slate 900 matches dark theme surface
              : Colors.white,
          elevation: 0,
          indicatorColor: theme.colorScheme.primary.withOpacity(0.15),
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
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'Catálogo',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined),
              selectedIcon: Icon(Icons.shopping_cart),
              label: 'Lista',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Cuenta',
            ),
          ],
        ),
      ),
    );
  }
}

