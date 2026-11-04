import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _initializedUserId;
  static const _installationIdKey = 'notification_installation_id';

  Future<void> initialize() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) return;
    if (_initializedUserId == user.uid) return;

    // Request permission
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Permiso de notificaciones concedido.');

      // Get token
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _registerDevice(token);
      }

      // Listen for token refresh
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = _firebaseMessaging.onTokenRefresh.listen(
        _registerDevice,
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM notification received in foreground: ${message.data}');
      });
      _initializedUserId = user.uid;
    } else {
      debugPrint('Notification permission was not granted.');
    }
  }

  Future<void> _registerDevice(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final idToken = await user.getIdToken();
      final platform = kIsWeb
          ? 'web'
          : defaultTargetPlatform.name.toLowerCase();

      final preferences = await SharedPreferences.getInstance();
      final installationId = await _getInstallationId(preferences);
      final response = await http.post(
        Uri.parse('$apiV1Url/notifications/device'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'fcm_token': token,
          'platform': platform,
          'installation_id': installationId,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('Dispositivo registrado para notificaciones.');
      } else {
        debugPrint(
          'No se pudo registrar el dispositivo: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error registrando dispositivo: $e');
    }
  }

  Future<String> _getInstallationId(SharedPreferences preferences) async {
    final existing = preferences.getString(_installationIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random();
    final value =
        '${DateTime.now().microsecondsSinceEpoch}-'
        '${List.generate(12, (_) => random.nextInt(16).toRadixString(16)).join()}';
    await preferences.setString(_installationIdKey, value);
    return value;
  }

  Future<void> updatePreferences(bool enabled, String time, int offset) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse('$apiV1Url/notifications/preferences'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'notifications_enabled': enabled,
        'notification_time': time,
        'timezone_offset': offset,
        'timezone': 'Europe/Madrid',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update preferences');
    }
  }

  Future<Map<String, dynamic>> getPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final idToken = await user.getIdToken();
    final response = await http.get(
      Uri.parse('$apiV1Url/notifications/preferences'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get preferences');
    }
  }
}
