import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
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
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading preferences: $e');
      // If error (e.g. first time), keep defaults
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset.inMinutes; 
      // Backend logic expects: UTC = Local + Offset (stored in DB).
      // Dart offset is positive for East (e.g. +60).
      // UTC = Local - Offset.
      // So to make "Local + StoredOffset = UTC", StoredOffset must be -Offset.
      
      final timeStr = '${_notificationTime.hour.toString().padLeft(2, '0')}:${_notificationTime.minute.toString().padLeft(2, '0')}:00';
      
      await NotificationService().updatePreferences(
        _notificationsEnabled,
        timeStr,
        -offset, 
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferencias guardadas'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Notificaciones Push'),
                  subtitle: const Text('Recibir avisos de caducidad'),
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                    _savePreferences();
                  },
                ),
                ListTile(
                  title: const Text('Hora de aviso'),
                  subtitle: Text(_notificationTime.format(context)),
                  enabled: _notificationsEnabled,
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _notificationTime,
                    );
                    if (picked != null) {
                      setState(() => _notificationTime = picked);
                      _savePreferences();
                    }
                  },
                ),
              ],
            ),
    );
  }
}
