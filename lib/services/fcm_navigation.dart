import 'package:flutter/material.dart';
import 'package:pedidosapp/core/app_navigator.dart';
import 'package:pedidosapp/data/field_keys.dart';
import 'package:pedidosapp/features/admin/home_admin.dart';
import 'package:pedidosapp/features/client/home_client.dart';
import 'package:pedidosapp/services/fcm_service.dart';

/// Navegación al tocar una notificación push (admin o cliente).
void handleFcmNotificationTap(Map<String, dynamic> data) {
  final nav = navigatorKey.currentState;
  if (nav == null) return;

  final type = data['type'] as String?;
  if (type == FcmNotificationTypes.newOrderForAdmin ||
      type == FcmNotificationTypes.clientMessageForAdmin) {
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeAdminPage()),
      (route) => false,
    );
    return;
  }

  final orderCode = data[FirestoreFields.orderCode] as String?;
  if (orderCode != null && orderCode.isNotEmpty) {
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeClientPage()),
      (route) => false,
    );
  }
}
