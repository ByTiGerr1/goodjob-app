import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String uid;

  NotificationService({required this.uid});

  Future<void> init() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _initLocalNotifications();
    }
    await _requestPermissions();
    await _saveToken();
    _listenForegroundMessages();
    _listenOpenedApp();
  }

  Future<String> _getInstallationId() async {
    final prefs = await SharedPreferences.getInstance();
    String? installationId = prefs.getString('installation_id');
    if (installationId == null) {
      installationId = const Uuid().v4();
      await prefs.setString('installation_id', installationId);
    }
    return installationId;
  }

  Future<void> _initLocalNotifications() async {
    if (Platform.isAndroid || Platform.isIOS) {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      final iosSettings = DarwinInitializationSettings();
      final settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

      await _localNotifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _onSelectNotification(response.payload);
        },
      );
    }
  }
/// Solicita permisos para notificaciones (iOS y Android 13+)
  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      await FirebaseMessaging.instance.requestPermission();
    }
  }

  /// Guarda el token de FCM en Firestore bajo el usuario autenticado
  /// y escucha cambios en el token para actualizarlo.
  Future<void> _saveToken() async {
    final installationId = await _getInstallationId();
    
    // Obtener el token de FCM
    String? token = await _messaging.getToken();
    if (token == null) return;

    final docRef = _firestore
        .collection('usuarios')
        .doc(uid)
        .collection('fcm_tokens')
        .doc(installationId);
   // Guardar token y lastSeen (crea o actualiza)
    await docRef.set({
      'token': token, 
      'lastSeen': FieldValue.serverTimestamp(),
      'device': Platform.operatingSystem,
    }, SetOptions(merge: true));
    // Escuchar actualizaciones del token y actualizar Firestore automáticamente
    _messaging.onTokenRefresh.listen((newToken) async {
      await docRef.set({
        'token': newToken, 
        'lastSeen': FieldValue.serverTimestamp()}, 
        SetOptions(merge: true)
        );
    });
  }

  void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((message) {
      if (Platform.isAndroid || Platform.isIOS) {
        if (message.notification != null) {
          _localNotifications.show(
            0,
            message.notification!.title,
            message.notification!.body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'default_channel',
                'Notificaciones',
                importance: Importance.max,
              ),
            ),
            payload: message.data.toString(),
          );
        }
      }
    });
  }

  void _listenOpenedApp() async {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationOpen(message.data);
    });
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage.data);
    }
  }

  Future<void> _onSelectNotification(String? payload) async {
    if (payload != null) _handleNotificationOpen({'payload': payload});
  }

  void _handleNotificationOpen(Map<String, dynamic> data) {
    print('Notificación abierta: $data');
    // Aquí decides a qué pantalla ir
  }
}