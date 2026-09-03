import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:pedidosapp/data/field_keys.dart';
import 'package:pedidosapp/data/firestore_collections.dart';
import 'package:pedidosapp/shared/demo_users.dart';
import 'package:pedidosapp/shared/order_states.dart';

/// Lecturas/escrituras de pedidos, mensajes y códigos de pedido.
class OrdersRepository {
  OrdersRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection(FirestoreCollections.orders);
  CollectionReference<Map<String, dynamic>> get _messages =>
      _db.collection(FirestoreCollections.messages);
  CollectionReference<Map<String, dynamic>> get _orderCodes =>
      _db.collection(FirestoreCollections.orderCodes);

  String newOrderId() => _orders.doc().id;

  String newMessageId() => _messages.doc().id;

  DocumentReference<Map<String, dynamic>> orderRef(String id) =>
      _orders.doc(id);

  DocumentReference<Map<String, dynamic>> messageRef(String id) =>
      _messages.doc(id);

  Future<DocumentSnapshot<Map<String, dynamic>>> getOrderCodeDoc(String code) =>
      _orderCodes.doc(code).get();

  Future<QuerySnapshot<Map<String, dynamic>>> ordersByCodeAndClient({
    required String orderCode,
    required String clientId,
  }) => _orders
      .where(FirestoreFields.orderCode, isEqualTo: orderCode)
      .where(FirestoreFields.clientId, isEqualTo: clientId)
      .limit(1)
      .get();

  Future<DocumentSnapshot<Map<String, dynamic>>> getOrder(String orderId) =>
      orderRef(orderId).get();

  Future<QuerySnapshot<Map<String, dynamic>>> ordersByCode(String orderCode) =>
      _orders
          .where(FirestoreFields.orderCode, isEqualTo: orderCode)
          .limit(1)
          .get();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchClientOrders(
    String clientId,
  ) => _orders.where(FirestoreFields.clientId, isEqualTo: clientId).snapshots();

  /// Todos los pedidos, más recientes primero (cualquier admin).
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllOrdersCreatedAtDesc() =>
      _orders.orderBy(FirestoreFields.createdAt, descending: true).snapshots();

  /// Pedidos visibles según si el admin es demo o de producción.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAdminOrdersCreatedAtDesc({
    required bool adminIsDemo,
    required String adminId,
  }) {
    if (adminIsDemo) {
      return _orders
          .where(FirestoreFields.isDemo, isEqualTo: true)
          .where(FirestoreFields.adminId, isEqualTo: adminId)
          .orderBy(FirestoreFields.createdAt, descending: true)
          .snapshots();
    }
    return watchAllOrdersCreatedAtDesc();
  }

  /// Códigos no usados de todos los admins, más recientes primero.
  Stream<QuerySnapshot<Map<String, dynamic>>>
  watchAllUnusedOrderCodesCreatedAtDesc() => _orderCodes
      .where(FirestoreFields.used, isEqualTo: false)
      .orderBy(FirestoreFields.createdAt, descending: true)
      .snapshots();

  /// IDs pendientes según si el admin es demo o de producción.
  Stream<QuerySnapshot<Map<String, dynamic>>>
  watchAdminUnusedOrderCodesCreatedAtDesc({
    required bool adminIsDemo,
    required String adminId,
  }) {
    if (adminIsDemo) {
      return _orderCodes
          .where(FirestoreFields.isDemo, isEqualTo: true)
          .where(FirestoreFields.adminId, isEqualTo: adminId)
          .orderBy(FirestoreFields.createdAt, descending: true)
          .snapshots();
    }
    return watchAllUnusedOrderCodesCreatedAtDesc();
  }

  /// Oculta pedidos/códigos demo en listados de admins de producción.
  static List<QueryDocumentSnapshot<Map<String, dynamic>>>
  hideDemoDocumentsForProductionAdmin<
    T extends QueryDocumentSnapshot<Map<String, dynamic>>
  >({required bool adminIsDemo, required List<T> documents}) {
    if (adminIsDemo) return List.from(documents);
    return documents
        .where((doc) => !DemoUsers.documentIsDemo(doc.data()))
        .toList();
  }

  /// Admin demo: la consulta no filtra `used`; se aplica en la UI.
  static List<QueryDocumentSnapshot<Map<String, dynamic>>>
  filterUnusedOrderCodes(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .where((doc) => doc.data()[FirestoreFields.used] != true)
        .toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessagesForOrder(
    String orderId,
  ) => _messages
      .where(FirestoreFields.orderId, isEqualTo: orderId)
      .orderBy(FirestoreFields.createdAt, descending: true)
      .snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMessage(
    String messageId,
  ) => _messages.doc(messageId).snapshots();

  Future<void> markOrderCodeUsed({
    required String orderCode,
    required String usedByUid,
  }) => _orderCodes.doc(orderCode).update({
    FirestoreFields.used: true,
    FirestoreFields.usedAt: FieldValue.serverTimestamp(),
    FirestoreFields.usedBy: usedByUid,
  });

  Future<void> updateOrderState({
    required String orderId,
    required int state,
  }) => _orders.doc(orderId).update({FirestoreFields.state: state});

  Future<void> cancelOrder({
    required String orderId,
    required String reason,
    required String cancelledByUid,
  }) => _orders.doc(orderId).update({
    FirestoreFields.state: kOrderStateCancelado,
    FirestoreFields.cancellationReason: reason.trim(),
    FirestoreFields.cancelledAt: FieldValue.serverTimestamp(),
    FirestoreFields.cancelledBy: cancelledByUid,
  });

  /// Marca un mensaje como leído por el admin y decrementa el contador del pedido.
  Future<void> markMessageReadByAdmin({
    required String messageId,
    required String orderId,
  }) async {
    final msgDocRef = messageRef(messageId);
    final msgSnap = await msgDocRef.get();
    if (!msgSnap.exists) return;

    final msgData = msgSnap.data()!;

    // Solo mensajes nuevos con readByAdmin == false. Legacy sin campo = ya leídos.
    if (msgData[FirestoreFields.readByAdmin] != false) return;

    await msgDocRef.update({
      FirestoreFields.readByAdmin: true,
      FirestoreFields.readByAdminAt: FieldValue.serverTimestamp(),
    });

    final orderDocRef = orderRef(orderId);
    final orderSnap = await orderDocRef.get();
    if (!orderSnap.exists) return;

    final raw = orderSnap.data()?[FirestoreFields.adminUnreadMessageCount];
    final current = raw is num ? raw.toInt() : 0;
    if (current <= 0) return;

    await orderDocRef.update({
      FirestoreFields.adminUnreadMessageCount: current - 1,
    });
  }

  /// Elimina un pedido cancelado (mensajes, Storage y documento) vía Cloud Function.
  Future<void> deleteCancelledOrder({required String orderId}) async {
    final functions = FirebaseFunctions.instanceFor(
      app: _db.app,
      region: 'us-central1',
    );
    await functions.httpsCallable('deleteCancelledOrder').call({
      CloudCallableKeys.orderId: orderId,
    });
  }

  /// Elimina un ID de pedido no usado (pendiente de ingreso) vía Cloud Function.
  Future<void> deleteUnusedOrderCode({required String orderCode}) async {
    final functions = FirebaseFunctions.instanceFor(
      app: _db.app,
      region: 'us-central1',
    );
    await functions.httpsCallable('deleteUnusedOrderCode').call({
      CloudCallableKeys.code: orderCode.trim(),
    });
  }
}
