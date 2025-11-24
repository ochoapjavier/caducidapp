import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/alerta.dart';
import 'services/api_service.dart';
import 'widgets/ubicacion_manager.dart';
import 'theme/app_theme.dart';
import 'screens/auth_screen.dart'; // Importamos la pantalla de autenticación
import 'screens/inventory_management_screen.dart'; // Importamos la nueva pantalla contenedora
import 'screens/hogar_selector_screen.dart'; // Selector de hogares
import 'screens/hogar_detalle_screen.dart'; // Detalles del hogar
import 'utils/expiry_utils.dart'; // Utilidades centralizadas para lógica de caducidad
import 'services/hogar_service.dart';

late final ValueNotifier<BrandPalette> _brandPaletteNotifier; // se inicializa tras leer prefs
late final ValueNotifier<ThemeMode> _themeModeNotifier;      // system/light/dark

Future<void> _initAppearance() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString('brand_palette');
  final initial = stored != null
      ? BrandPalette.values.firstWhere(
          (p) => p.name == stored,
          orElse: () => BrandPalette.morado,
        )
      : BrandPalette.morado;
  _brandPaletteNotifier = ValueNotifier(initial);

  final modeStr = prefs.getString('theme_mode');
  final ThemeMode mode = switch (modeStr) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  _themeModeNotifier = ValueNotifier(mode);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _initAppearance();
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: snapshot.data!.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = snapshot.data![index];
                // Usando utilidades centralizadas para mantener consistencia
                final statusColor = ExpiryUtils.getExpiryColor(item.fechaCaducidad, colorScheme);
                final statusLabel = ExpiryUtils.getStatusLabel(item.fechaCaducidad);
                final statusIcon = ExpiryUtils.getStatusIcon(item.fechaCaducidad);
                final expiryMessage = ExpiryUtils.getExpiryMessage(item.fechaCaducidad);
                final daysDiff = ExpiryUtils.daysUntilExpiry(item.fechaCaducidad);

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            // Usamos withValues para reducir opacidad sin deprecación
                            // Fallback: until withOpacity migration complete, use alpha via .withAlpha
                            color: statusColor.withAlpha((255 * 0.12).round()),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            statusIcon,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.producto,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ubicación: ${item.ubicacion} · Cantidad: ${item.cantidad}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withAlpha((255 * 0.65).round()),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                expiryMessage,
                                style: textTheme.bodySmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              daysDiff < 0 ? 'Caducado' : 'Caduca',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface.withAlpha((255 * 0.60).round()),
                              ),
                            ),
                            Text(
                              '${item.fechaCaducidad.day}/${item.fechaCaducidad.month}/${item.fechaCaducidad.year}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                decoration: daysDiff < 0 ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha((255 * 0.12).round()),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                statusLabel,
                                style: textTheme.labelSmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          } else {
            // estado vacío
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 80,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '¡Todo en orden!',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No tienes productos próximos a caducar en la siguiente semana. ¡Buen trabajo!',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.65),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

/// Widget que contiene la estructura principal de la app (la que tiene las pestañas).
/// Se mostrará cuando el usuario esté autenticado.
// Notifier global simple para cambiar la paleta en runtime.
// Nombres mostrados en español para cada paleta.
extension BrandPaletteDisplay on BrandPalette {
  String get displayName {
    switch (this) {
      case BrandPalette.enterprise:
        return 'Empresarial';
      case BrandPalette.freshness:
        return 'Fresco';
      case BrandPalette.tech:
        return 'Tecnología';
      case BrandPalette.morado:
        return 'Morado';
      case BrandPalette.rojo:
        return 'Rojo';
    }
  }
}

class MainAppScreen extends StatelessWidget {
  const MainAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: colorScheme.surface,
          title: Text(
            'Gestión de Caducidades',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          actions: [
            // Botón para cambiar de hogar
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Cambiar hogar',
              onPressed: () {
                Navigator.pushNamed(context, '/selector-hogar');
              },
            ),
            // Botón para ver detalles del hogar actual
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Gestionar hogar',
              onPressed: () async {
                final hogarService = HogarService();
                final hogarActivo = await hogarService.getHogarActivo();
                if (hogarActivo != null && context.mounted) {
                  Navigator.pushNamed(
                    context,
                    '/hogar-detalle',
                    arguments: hogarActivo,
                  );
                }
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle),
              onSelected: (value) {
                if (value.startsWith('palette:')) {
                  final key = value.split(':')[1];
                  final selected = BrandPalette.values.firstWhere((p) => p.name == key);
                  _brandPaletteNotifier.value = selected;
                  SharedPreferences.getInstance()
                      .then((prefs) => prefs.setString('brand_palette', selected.name));
                } else if (value.startsWith('theme:')) {
                  final key = value.split(':')[1];
                  final ThemeMode mode = switch (key) {
                    'light' => ThemeMode.light,
                    'dark' => ThemeMode.dark,
                    _ => ThemeMode.system,
                  };
                  _themeModeNotifier.value = mode;
                  SharedPreferences.getInstance()
                      .then((prefs) => prefs.setString('theme_mode', key));
                } else if (value == 'logout') {
                  // Limpiar hogar activo al cerrar sesión
                  HogarService().clearHogarActivo();
                  FirebaseAuth.instance.signOut();
                }
              },
              itemBuilder: (BuildContext context) {
                final user = FirebaseAuth.instance.currentUser;
                return [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.email ?? 'Usuario',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Paleta de marca', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  ...BrandPalette.values.map((p) => PopupMenuItem<String>(
                        value: 'palette:${p.name}',
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.lightThemeFor(p).colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.black.withAlpha(30)),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                p.displayName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                            if (_brandPaletteNotifier.value == p)
                              Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
                          ],
                        ),
                      )),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Text('Apariencia', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                  ),
                  PopupMenuItem<String>(
                    value: 'theme:system',
                    child: Row(
                      children: [
                        const Icon(Icons.brightness_auto, size: 18),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Sistema', style: TextStyle(fontSize: 13))),
                        if (_themeModeNotifier.value == ThemeMode.system)
                          Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'theme:light',
                    child: Row(
                      children: [
                        const Icon(Icons.light_mode, size: 18),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Claro', style: TextStyle(fontSize: 13))),
                        if (_themeModeNotifier.value == ThemeMode.light)
                          Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'theme:dark',
                    child: Row(
                      children: [
                        const Icon(Icons.dark_mode, size: 18),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Oscuro', style: TextStyle(fontSize: 13))),
                        if (_themeModeNotifier.value == ThemeMode.dark)
                          Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Text('Cerrar sesión'),
                  ),
                ];
              },
            ),
          ],
          bottom: TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor:
                colorScheme.onSurface.withOpacity(0.6),
            indicatorColor: colorScheme.primary,
            tabs: const [
              Tab(text: 'Alertas', icon: Icon(Icons.notifications_active_outlined)),
              Tab(text: 'Inventario', icon: Icon(Icons.inventory_2_outlined)),
              Tab(text: 'Ubicaciones', icon: Icon(Icons.location_on_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AlertasDashboard(),
            InventoryManagementScreen(),
            UbicacionManager(),
          ],
        ),
      ),
    );
  }
}

/// Widget que verifica si hay un hogar seleccionado antes de mostrar la pantalla principal
class HogarAwareMainScreen extends StatefulWidget {
  const HogarAwareMainScreen({super.key});

  @override
  State<HogarAwareMainScreen> createState() => _HogarAwareMainScreenState();
}

class _HogarAwareMainScreenState extends State<HogarAwareMainScreen> {
  final HogarService _hogarService = HogarService();
  bool _isChecking = true;
  bool _hasHogar = false;

  @override
  void initState() {
    super.initState();
    _verificarHogar();
  }

  Future<void> _verificarHogar() async {
    final tieneHogar = await _hogarService.tieneHogarActivo();
    if (mounted) {
      setState(() {
        _hasHogar = tieneHogar;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Si no tiene hogar, mostrar el selector directamente
    if (!_hasHogar) {
      return const HogarSelectorScreen();
    }

    return const MainAppScreen();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp permanece estable; solo el Theme interno se reemplaza, evitando rebuild completo
    // que causaba el error de "deactivated widget ancestor" cuando el popup seguía cerrándose.
    return MaterialApp(
      title: 'Gestión de Caducidades',
      theme: AppTheme.lightTheme, // tema base (violeta original como fallback)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
      ],
      locale: const Locale('es', 'ES'),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return ValueListenableBuilder<BrandPalette>(
          valueListenable: _brandPaletteNotifier,
          builder: (context, palette, _) {
            return ValueListenableBuilder<ThemeMode>(
              valueListenable: _themeModeNotifier,
              builder: (context, mode, __) {
                final Brightness effectiveBrightness = switch (mode) {
                  ThemeMode.light => Brightness.light,
                  ThemeMode.dark => Brightness.dark,
                  ThemeMode.system => MediaQuery.of(context).platformBrightness,
                };
                return AnimatedTheme(
                  data: AppTheme.themeFor(palette, effectiveBrightness),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: child ?? const SizedBox.shrink(),
                );
              },
            );
          },
        );
      },
      routes: {
        '/': (context) => StreamBuilder(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (ctx, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (userSnapshot.hasData) {
              return const HogarAwareMainScreen();
            }
            return const AuthScreen();
          },
        ),
        '/selector-hogar': (context) => const HogarSelectorScreen(),
        '/hogar-detalle': (context) {
          final hogarId = ModalRoute.of(context)?.settings.arguments as int?;
          if (hogarId == null) {
            // Si no hay hogarId, redirigir al selector
            Future.microtask(() => Navigator.pushReplacementNamed(context, '/selector-hogar'));
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return HogarDetalleScreen(hogarId: hogarId);
        },
      },
      initialRoute: '/',
    );
  }
}
