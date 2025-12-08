import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'models/alerta.dart';
import 'services/api_service.dart';
import 'widgets/ubicacion_manager.dart';
import 'theme/app_theme.dart';
import 'screens/auth_screen.dart';
import 'screens/inventory_management_screen.dart';
import 'screens/hogar_selector_screen.dart';
import 'screens/hogar_detalle_screen.dart';
import 'screens/hogar_shell_screen.dart';
import 'utils/expiry_utils.dart';
import 'services/notification_service.dart';
import 'screens/settings_screen.dart';
import 'services/hogar_service.dart';
import 'widgets/quantity_selection_dialog.dart';
import 'services/shopping_service.dart';
import 'services/theme_service.dart';
import 'widgets/error_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await ThemeService().loadSettings();
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
    futureAlertas = _loadAlertas();
  }

  Future<List<AlertaItem>> _loadAlertas() async {
    try {
      return await fetchAlertas();
    } catch (e) {
      debugPrint('Error loading alerts: $e');
      // Manejo de error 403: Hogar inválido
      if (e.toString().contains('403') || e.toString().contains('Forbidden')) {
        debugPrint('Detectado error 403. Limpiando hogar activo inválido...');
        await HogarService().clearHogarActivo();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tu sesión de hogar ha caducado. Por favor selecciona un hogar.'),
              backgroundColor: Colors.orange,
            ),
          );
          // Redirigir al inicio para forzar la re-verificación del hogar
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
      rethrow;
    }
  }

  void _showRemoveFromAlertsDialog(int stockId, int currentQuantity, String productName, int productId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => QuantitySelectionDialog(
        title: 'Eliminar "$productName"',
        subtitle: 'Disponibles: $currentQuantity',
        maxQuantity: currentQuantity,
        onConfirm: (quantity, addToShoppingList) async {
          try {
            // 1. Eliminar del stock
            await removeStockItems(stockId: stockId, cantidad: quantity);

            // 2. Añadir a lista de compra si se solicitó
            if (addToShoppingList) {
              try {
                final hogarId = await HogarService().getHogarActivo();
                if (hogarId != null) {
                  await ShoppingService().addItem(hogarId, productName, fkProducto: productId);
                }
              } catch (e) {
                debugPrint('Error adding to shopping list: $e');
              }
            }

            // 3. Refrescar alertas
            setState(() {
              futureAlertas = _loadAlertas();
            });

            // 4. Notificar
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(addToShoppingList 
                    ? 'Eliminado y añadido a la lista de compra.' 
                    : 'Producto eliminado.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            futureAlertas = _loadAlertas();
          });
          await futureAlertas;
        },
        child: FutureBuilder<List<AlertaItem>>(
          future: futureAlertas,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return ErrorView(
                error: snapshot.error!,
                onRetry: () {
                  setState(() {
                    futureAlertas = _loadAlertas();
                  });
                },
              );
            } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: snapshot.data!.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = snapshot.data![index];
                  final statusColor = ExpiryUtils.getExpiryColor(item.fechaCaducidad, colorScheme);
                  final statusLabel = ExpiryUtils.getStatusLabel(item.fechaCaducidad);
                  final statusIcon = ExpiryUtils.getStatusIcon(item.fechaCaducidad);
                  final expiryMessage = ExpiryUtils.getExpiryMessage(item.fechaCaducidad);
                  final daysDiff = ExpiryUtils.daysUntilExpiry(item.fechaCaducidad);
                  
                  final estadoProducto = item.estadoProducto;
                  final showStateBadge = ExpiryUtils.shouldShowStateBadge(estadoProducto);
                  final stateBadgeColor = ExpiryUtils.getStateBadgeColor(estadoProducto);
                  final stateLabel = ExpiryUtils.getStateLabel(estadoProducto);
                  final stateIcon = ExpiryUtils.getStateIcon(estadoProducto);

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
                                  'Ubicación: ${item.ubicacion}',
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
                                if (showStateBadge) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        stateIcon,
                                        size: 14,
                                        color: stateBadgeColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        stateLabel,
                                        style: textTheme.labelSmall?.copyWith(
                                          color: stateBadgeColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${item.fechaCaducidad.day}/${item.fechaCaducidad.month}/${item.fechaCaducidad.year}',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                  decoration: daysDiff < 0 ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Badge de Estado (Urgente, Próximo...)
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
                                  const SizedBox(width: 6),
                                  // Badge de Cantidad
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor, // Fondo sólido con el color de urgencia
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'x${item.cantidad}',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: Colors.white, // Texto blanco para contraste
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              IconButton(
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: const EdgeInsets.all(6),
                                tooltip: 'Eliminar',
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () => _showRemoveFromAlertsDialog(
                                  item.id,
                                  item.cantidad,
                                  item.producto,
                                  item.productoId,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.errorContainer,
                                  foregroundColor: colorScheme.onErrorContainer,
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
      ),
    );
  }
}

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

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const HogarAwareMainScreen();
        }
        return const AuthScreen();
      },
    );
  }
}

class HogarAwareMainScreen extends StatefulWidget {
  const HogarAwareMainScreen({super.key});

  @override
  State<HogarAwareMainScreen> createState() => _HogarAwareMainScreenState();
}

class _HogarAwareMainScreenState extends State<HogarAwareMainScreen> {
  final HogarService _hogarService = HogarService();
  bool _isChecking = true;
  int? _hogarId;

  @override
  void initState() {
    super.initState();
    _verificarHogar();
  }

  Future<void> _verificarHogar() async {
    final hogarId = await _hogarService.getHogarActivo();
    if (mounted) {
      setState(() {
        _hogarId = hogarId;
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

    if (_hogarId != null) {
      return HogarShellScreen(hogarId: _hogarId!);
    } else {
      return const HogarSelectorScreen();
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xpiry',
      theme: AppTheme.lightTheme,
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
        return ListenableBuilder(
          listenable: ThemeService(),
          builder: (context, _) {
            final themeService = ThemeService();
            final mode = themeService.themeMode;
            final palette = themeService.palette;

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
      routes: {
        '/': (context) => StreamBuilder(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (ctx, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (userSnapshot.hasData) {
              final user = userSnapshot.data!;
              if (!user.emailVerified) {
                FirebaseAuth.instance.signOut();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ Por favor, verifica tu email antes de continuar. Revisa tu bandeja (y spam).'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 5),
                      ),
                    );
                  }
                });
                return const AuthScreen();
              }
              return const HogarAwareMainScreen();
            }
            return const AuthScreen();
          },
        ),
        '/selector-hogar': (context) => const HogarSelectorScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/hogar-detalle': (context) {
          final hogarId = ModalRoute.of(context)?.settings.arguments as int?;
          if (hogarId == null) {
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
