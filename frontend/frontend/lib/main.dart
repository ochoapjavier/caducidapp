
import 'package:flutter/material.dart';
import 'models/alerta.dart';
import 'services/api_service.dart';
import 'widgets/ubicacion_manager.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestión de Caducidades',
      theme: AppTheme.lightTheme,
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Gestión de Caducidades'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Alertas', icon: Icon(Icons.notifications_active_outlined)),
                Tab(text: 'Ubicaciones', icon: Icon(Icons.location_on_outlined)),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              AlertasDashboard(),
              UbicacionManager(),
            ],
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
