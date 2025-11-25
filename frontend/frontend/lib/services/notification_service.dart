import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'api_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      
      // Get token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        await _registerDevice(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_registerDevice);
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');

        if (message.notification != null) {
          print('Message also contained a notification: ${message.notification!.title}');
          // TODO: Show a dialog or snackbar?
        }
      });
    } else {
      print('User declined or has not accepted permission');
    }
  }

  Future<void> _registerDevice(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final idToken = await user.getIdToken();
      final platform = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();

      final response = await http.post(
        Uri.parse('$apiV1Url/notifications/device'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'fcm_token': token,
          'platform': platform,
        }),
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Device registered successfully');
      } else {
        print('Failed to register device: ${response.body}');
      }
    } catch (e) {
      print('Error registering device: $e');
    }
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
