import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pedidosapp/data/field_keys.dart';
import 'package:pedidosapp/data/firestore_collections.dart';

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

  Future<QuerySnapshot<Map<String, dynamic>>> ordersByCode(String orderCode) =>
      _orders
          .where(FirestoreFields.orderCode, isEqualTo: orderCode)
          .limit(1)
          .get();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchClientOrders(
    String clientId,
  ) => _orders.where(FirestoreFields.clientId, isEqualTo: clientId).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllOrdersByCreatedAtDesc() =>
      _orders.orderBy(FirestoreFields.createdAt, descending: true).snapshots();

  /// Códigos de pedido aún no usados por el cliente (admin: filtro pendiente de ingreso).
  Stream<QuerySnapshot<Map<String, dynamic>>>
      watchUnusedOrderCodesByCreatedAtDesc() => _orderCodes
          .where(FirestoreFields.used, isEqualTo: false)
          .orderBy(FirestoreFields.createdAt, descending: true)
          .snapshots();

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
}
