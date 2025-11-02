
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Importar
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // Archivo generado por FlutterFire CLI

import 'models/alerta.dart';
import 'services/api_service.dart';
import 'widgets/ubicacion_manager.dart';
import 'theme/app_theme.dart';
import 'widgets/inventory_view.dart'; // Importamos la nueva vista de inventario
import 'widgets/add_item_view.dart'; // Importamos el nuevo widget
import 'screens/auth_screen.dart'; // Importamos la pantalla de autenticación
import 'screens/inventory_management_screen.dart'; // Importamos la nueva pantalla contenedora

void main() async {
  // Es necesario para que la inicialización de Firebase funcione antes de runApp
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializamos Firebase usando el archivo de configuración autogenerado
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

/// Widget que contiene el dashboard principal de la aplicación,
/// una vez que el usuario ha iniciado sesión.
/// Se extrae para mantener el código limpio.
class AlertasDashboard extends StatefulWidget {
  const AlertasDashboard({super.key});

  @override
  State<AlertasDashboard> createState() => _AlertasDashboardState();
}

class _AlertasDashboardState extends State<AlertasDashboard> {
  late Future<List<AlertaItem>> futureAlertas;

  @override
  void initState() {
    super.initState();
    futureAlertas = fetchAlertas();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          futureAlertas = fetchAlertas();
        });
      },
      child: FutureBuilder<List<AlertaItem>>(
        future: futureAlertas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error al conectar: ${snapshot.error}.\n(Verifica Docker y CORS)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            );
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final item = snapshot.data![index];
                final isCritical = item.fechaCaducidad.difference(DateTime.now()).inDays <= 3;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                    title: Text(item.producto, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Ubicación: ${item.ubicacion} | Cantidad: ${item.cantidad}'),
                    trailing: Text(
                      'Caduca: ${item.fechaCaducidad.day}/${item.fechaCaducidad.month}',
                      style: TextStyle(
                        color: isCritical ? Colors.redAccent : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            );
          } else {
            return const Center(child: Text('¡Inventario limpio! No hay productos próximos a caducar.'));
          }
        },
      ),
    );
  }
}

/// Widget que contiene la estructura principal de la app (la que tiene las pestañas).
/// Se mostrará cuando el usuario esté autenticado.
class MainAppScreen extends StatelessWidget {
  const MainAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Cambiamos a 3 pestañas
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestión de Caducidades'),
          actions: [ // Usaremos un PopupMenuButton para un menú de usuario más elegante
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle), // Icono de perfil
              onSelected: (value) {
                if (value == 'logout') {
                  FirebaseAuth.instance.signOut();
                }
              },
              itemBuilder: (BuildContext context) {
                // Obtenemos el usuario actual de forma síncrona
                final user = FirebaseAuth.instance.currentUser;
                return [
                  // Opción 1: Muestra el email (no es clickeable)
                  PopupMenuItem<String>(
                    enabled: false, // Para que no parezca un botón
                    child: Text(
                      user?.email ?? 'Usuario', // Muestra el email o 'Usuario' si es nulo
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const PopupMenuDivider(),
                  // Opción 2: El botón para cerrar sesión
                  const PopupMenuItem<String>(value: 'logout', child: Text('Cerrar Sesión')),
                ];
              },
            )
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Alertas', icon: Icon(Icons.notifications_active_outlined)),
              Tab(text: 'Inventario', icon: Icon(Icons.inventory_2_outlined)),
              Tab(text: 'Ubicaciones', icon: Icon(Icons.location_on_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AlertasDashboard(),
            InventoryManagementScreen(), // Usamos la nueva pantalla contenedora
            UbicacionManager(),
          ],
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Gestión de Caducidades',
        theme: AppTheme.lightTheme,
        // --- INICIO DE CAMBIOS PARA LOCALIZACIÓN ---
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'ES'), // Español, España
        ],
        locale: const Locale('es', 'ES'), // Forzar el locale a español
        // --- FIN DE CAMBIOS PARA LOCALIZACIÓN ---
        debugShowCheckedModeBanner: false,
        home: StreamBuilder(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (ctx, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                // Mientras se verifica el estado, muestra un spinner
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (userSnapshot.hasData) {
                // Si el snapshot tiene datos, significa que hay un usuario logueado
                return const MainAppScreen();
              }
              // Si no hay datos, el usuario no está logueado
              return const AuthScreen();
            }));
  }
}
