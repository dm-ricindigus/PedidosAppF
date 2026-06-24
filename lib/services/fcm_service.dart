import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pedidosapp/data/field_keys.dart';
import 'package:pedidosapp/data/firestore_collections.dart';

/// Valores de `RemoteMessage.data['type']` enviados desde Cloud Functions.
abstract final class FcmNotificationTypes {
  static const String newOrderForAdmin = 'new_order_admin';
  /// Cliente añadió mensaje al pedido (editar pedido).
  static const String clientMessageForAdmin = 'client_message_admin';
}

/// Servicio para gestionar notificaciones push (FCM).
/// Guarda el token en Firestore para que las Cloud Functions envíen avisos
/// al cliente (cambio de estado) y al admin (nuevo pedido / mensaje del cliente).
class FcmService {
  FcmService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static void Function(Map<String, dynamic> data)? _onNotificationTap;

  /// Mismo canal que Cloud Functions (`pedidos_high`) y AndroidManifest.
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'pedidos_high',
    'TSM Clothing',
    description: 'Avisos de pedidos y mensajes',
    importance: Importance.high,
  );

  /// Configura FCM, notificaciones en primer plano y taps.
  /// Llamar una vez en [main] / [main_dev] antes de [runApp].
  static Future<void> initialize({
    required void Function(Map<String, dynamic> data) onNotificationTap,
  }) async {
    _onNotificationTap = onNotificationTap;

    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_pedidos');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }

    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => onNotificationTap(Map<String, dynamic>.from(message.data)),
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      onNotificationTap(Map<String, dynamic>.from(initialMessage.data));
    }
  }

  static void _onLocalNotificationTapped(NotificationResponse response) {
    _handleNotificationPayload(response.payload);
  }

  static void _handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      _onNotificationTap?.call(Map<String, dynamic>.from(decoded));
    } catch (e, st) {
      debugPrint('[FCM] Payload de notificación inválido: $e');
      debugPrint('[FCM] StackTrace: $st');
    }
  }

  /// Android: banner local en primer plano. iOS: banner nativo vía FCM.
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    if (Platform.isIOS) {
      // setForegroundNotificationPresentationOptions muestra el banner del sistema.
      return;
    }

    if (!Platform.isAndroid) return;

    final title = notification.title ?? 'TSM Clothing';
    final body = notification.body ?? '';

    await _localNotifications.show(
      id: notification.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_stat_pedidos',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Inicializa FCM: solicita permisos, obtiene token y lo guarda en Firestore.
  /// Debe llamarse cuando el usuario entra al home (cliente o admin).
  static Future<void> initAndSaveToken(String uid) async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Permisos denegados por el usuario');
        return;
      }

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] No se pudo obtener el token');
        return;
      }

      debugPrint('[FCM] Token obtenido (${token.length} chars)');

      await _firestore.collection(FirestoreCollections.fcmTokens).doc(uid).set({
        FirestoreFields.token: token,
        FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[FCM] Token guardado en Firestore para uid: $uid');

      _messaging.onTokenRefresh.listen((newToken) async {
        if (newToken.isNotEmpty) {
          await _firestore
              .collection(FirestoreCollections.fcmTokens)
              .doc(uid)
              .set({
                FirestoreFields.token: newToken,
                FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        }
      });
    } catch (e, st) {
      debugPrint('[FCM] Error: $e');
      debugPrint('[FCM] StackTrace: $st');
    }
  }

  /// Elimina el token de Firestore al cerrar sesión.
  static Future<void> removeToken(String uid) async {
    try {
      await _firestore
          .collection(FirestoreCollections.fcmTokens)
          .doc(uid)
          .delete();
      debugPrint('[FCM] Token eliminado para uid: $uid');
    } catch (e, st) {
      debugPrint('[FCM] Error al eliminar token: $e');
      debugPrint('[FCM] StackTrace: $st');
    }
  }
}
