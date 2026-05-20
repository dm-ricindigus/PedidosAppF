import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pedidosapp/data/field_keys.dart';
import 'package:pedidosapp/data/firestore_collections.dart';

/// Valores de `RemoteMessage.data['type']` enviados desde Cloud Functions.
abstract final class FcmNotificationTypes {
  static const String newOrderForAdmin = 'new_order_admin';
}

/// Servicio para gestionar notificaciones push (FCM).
/// Guarda el token en Firestore para que las Cloud Functions envíen avisos
/// al cliente (cambio de estado) y al admin (nuevo pedido con su código).
class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Inicializa FCM: solicita permisos, obtiene token y lo guarda en Firestore.
  /// Debe llamarse cuando el usuario entra al home (cliente o admin).
  static Future<void> initAndSaveToken(String uid) async {
    try {
      // Solicitar permiso (necesario en iOS; Android 13+ lo pide en runtime)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Permisos denegados por el usuario');
        return;
      }

      // Obtener el token FCM
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] No se pudo obtener el token');
        return;
      }

      debugPrint('[FCM] Token obtenido (${token.length} chars)');

      // Guardar en Firestore: fcmTokens/{uid}
      await _firestore.collection(FirestoreCollections.fcmTokens).doc(uid).set({
        FirestoreFields.token: token,
        FirestoreFields.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[FCM] Token guardado en Firestore para uid: $uid');

      // Escuchar cambios del token (se regenera periódicamente)
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
  /// Así el dispositivo deja de recibir notificaciones dirigidas a ese usuario.
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

  /// Configura el manejador para notificaciones en primer plano.
  /// Debe llamarse una sola vez al inicio de la app (main).
  static void setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Notificación recibida con la app en primer plano
      // Puedes mostrar un SnackBar o dialog si lo deseas
      if (message.notification != null) {
        // message.notification?.title, message.notification?.body
      }
    });
  }

  /// Configura el manejador para cuando el usuario toca una notificación.
  /// Debe llamarse una sola vez al inicio de la app (main).
  /// Los valores relevantes incluyen [FirestoreFields.orderCode] y
  /// `type` ([FcmNotificationTypes]).
  static void setupNotificationTapHandler(
    void Function(Map<String, dynamic> data) onTap,
  ) {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      onTap(Map<String, dynamic>.from(message.data));
    });
  }
}
