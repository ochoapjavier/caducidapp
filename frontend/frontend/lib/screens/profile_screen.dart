import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../services/hogar_service.dart';
import 'hogar_selector_screen.dart';
import 'hogar_detalle_screen.dart';
import 'settings_screen.dart'; // Para reutilizar lógica o migrarla
import 'locations_management_screen.dart';
import '../services/theme_service.dart';

class ProfileScreen extends StatefulWidget {
  final int hogarId;

  const ProfileScreen({super.key, required this.hogarId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  String _appVersion = '';
  
  // Settings state
  bool _notificationsEnabled = true;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadSettings();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'v${info.version} (${info.buildNumber})';
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await NotificationService().getPreferences();
      if (mounted) {
        setState(() {
          _notificationsEnabled = prefs['notifications_enabled'];
          final timeParts = (prefs['notification_time'] as String).split(':');
          _notificationTime = TimeOfDay(
            hour: int.parse(timeParts[0]),
            minute: int.parse(timeParts[1]),
          );
          _isLoadingSettings = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSettings = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset.inMinutes;
      final timeStr = '${_notificationTime.hour.toString().padLeft(2, '0')}:${_notificationTime.minute.toString().padLeft(2, '0')}:00';
      
      await NotificationService().updatePreferences(
        _notificationsEnabled,
        timeStr,
        -offset,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar ajustes: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    // La navegación se maneja en el AuthWrapper
  }

  void _changeHogar() {
    // Navegar al selector de hogar, eliminando la pila actual
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HogarSelectorScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil y Ajustes'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cabecera de Usuario
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Usuario',
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          user?.email ?? '',
                          style: textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sección Ajustes (Configuración) - AHORA PRIMERO
          Text('Configuración', style: textTheme.titleSmall?.copyWith(color: colorScheme.primary)),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Tema
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Apariencia'),
                  subtitle: const Text('Personalizar colores y tema'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showAppearanceModal(context),
                ),
                const Divider(height: 1),
                // Notificaciones
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Notificaciones'),
                  value: _notificationsEnabled,
                  onChanged: _isLoadingSettings ? null : (val) {
                    setState(() => _notificationsEnabled = val);
                    _saveSettings();
                  },
                ),
                if (_notificationsEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Hora de aviso'),
                    trailing: Text(_notificationTime.format(context)),
                    onTap: _isLoadingSettings ? null : () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _notificationTime,
                      );
                      if (picked != null) {
                        setState(() => _notificationTime = picked);
                        _saveSettings();
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sección General - AHORA SEGUNDO
          Text('General', style: textTheme.titleSmall?.copyWith(color: colorScheme.primary)),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Mis Ubicaciones'),
                  subtitle: const Text('Gestionar despensas, neveras...'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocationsManagementScreen(hogarId: widget.hogarId),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_applications_outlined),
                  title: const Text('Gestionar Hogar'),
                  subtitle: const Text('Ver miembros, código de invitación...'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HogarDetalleScreen(hogarId: widget.hogarId),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.home_work_outlined),
                  title: const Text('Cambiar de Hogar'),
                  subtitle: const Text('Seleccionar otro hogar o crear uno nuevo'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changeHogar,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Versión de la App'),
                  trailing: Text(_appVersion),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Cerrar Sesión
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar Sesión'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error),
              padding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  void _showAppearanceModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AppearanceSettingsModal(),
    );
  }
}

class AppearanceSettingsModal extends StatelessWidget {
  const AppearanceSettingsModal({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ListenableBuilder(
          listenable: themeService,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Apariencia', style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  Text('Modo', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Claro')),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Oscuro')),
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('Auto')),
                    ],
                    selected: {themeService.themeMode},
                    onSelectionChanged: (Set<ThemeMode> newSelection) {
                      themeService.setThemeMode(newSelection.first);
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  Text('Color de énfasis', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: BrandPalette.values.map((palette) {
                      final isSelected = themeService.palette == palette;
                      return InkWell(
                        onTap: () => themeService.setPalette(palette),
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.lightThemeFor(palette).primaryColor,
                            shape: BoxShape.circle,
                            border: isSelected 
                                ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                                : null,
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                            ],
                          ),
                          child: isSelected 
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
