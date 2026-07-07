const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require('firebase-functions/v2/firestore');
const {setGlobalOptions} = require('firebase-functions/v2');
const admin = require('firebase-admin');

admin.initializeApp();

// Usar la base de datos "default"
const db = admin.firestore();

// Configurar opciones globales para Gen 2
setGlobalOptions({
  region: 'us-central1',
});

// Función para generar un código único de 8 dígitos
function generarCodigoUnico() {
  return Math.floor(10000000 + Math.random() * 90000000).toString();
}

// Cloud Function para crear código de pedido
exports.createOrderCode = onCall(async (request) => {
  try {
    const data = request.data;
    
    // Validar autenticación
    let adminId;
    if (request.auth) {
      adminId = request.auth.uid;
    } else if (data && data._authToken) {
      try {
        const decodedToken = await admin.auth().verifyIdToken(data._authToken);
        adminId = decodedToken.uid;
      } catch (error) {
        throw new HttpsError(
          'unauthenticated',
          'Token inválido o expirado: ' + error.message
        );
      }
    } else {
      throw new HttpsError(
        'unauthenticated',
        'Debes estar autenticado para crear códigos de pedido'
      );
    }

    // Validar que el usuario sea admin
    const userDoc = await db.collection('users').doc(adminId).get();
    if (!userDoc.exists) {
      throw new HttpsError(
        'permission-denied',
        'Usuario no encontrado'
      );
    }

    const userData = userDoc.data();
    if (userData.role !== 'admin') {
      throw new HttpsError(
        'permission-denied',
        'Solo los administradores pueden crear códigos de pedido'
      );
    }

    let createdByEmail = '';
    try {
      const authUser = await admin.auth().getUser(adminId);
      createdByEmail = (authUser.email || '').trim().toLowerCase();
    } catch (e) {
      console.warn('[createOrderCode] No se pudo obtener email de Auth:', e.message);
    }
    if (!createdByEmail && userData.email) {
      createdByEmail = String(userData.email).trim().toLowerCase();
    }

    // Validar datos de entrada
    const clientEmail = data.clientEmail;
    if (!clientEmail || typeof clientEmail !== 'string' || !clientEmail.includes('@')) {
      throw new HttpsError(
        'invalid-argument',
        'Debes proporcionar un email válido del cliente'
      );
    }

    // Generar código único (intentar hasta encontrar uno disponible)
    let codigo;
    let intentos = 0;
    const maxIntentos = 10;

    while (intentos < maxIntentos) {
      codigo = generarCodigoUnico();
      
      // Verificar si el código ya existe
      const codigoDoc = await db.collection('orderCodes').doc(codigo).get();
      
      if (!codigoDoc.exists) {
        // Código único encontrado, guardarlo
        await db.collection('orderCodes').doc(codigo).set({
          code: codigo,
          clientEmail: clientEmail.trim().toLowerCase(),
          adminId: adminId,
          createdByUid: adminId,
          createdByEmail: createdByEmail || null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          used: false,
        });

        return {
          success: true,
          code: codigo,
          clientEmail: clientEmail.trim().toLowerCase(),
        };
      }
      
      intentos++;
    }

    // Si llegamos aquí, no se pudo generar un código único después de varios intentos
    throw new HttpsError(
      'internal',
      'No se pudo generar un código único. Intenta nuevamente.'
    );
  } catch (error) {
    // Si ya es un HttpsError, relanzarlo
    if (error instanceof HttpsError) {
      throw error;
    }
    // Si es otro tipo de error, convertirlo a HttpsError
    throw new HttpsError(
      'internal',
      'Error interno: ' + (error.message || String(error))
    );
  }
});

// Elimina cuenta de cliente (Auth + perfil + FCM). Conserva orders y messages.
exports.deleteClientAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'Debes iniciar sesión para eliminar tu cuenta',
    );
  }

  const uid = request.auth.uid;

  const userDoc = await db.collection('users').doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError('not-found', 'Usuario no encontrado');
  }

  const role = userDoc.data()?.role;
  if (role !== 'client') {
    throw new HttpsError(
      'permission-denied',
      'Solo los clientes pueden eliminar su cuenta desde la app',
    );
  }

  const fcmRef = db.collection('fcmTokens').doc(uid);
  const fcmSnap = await fcmRef.get();
  if (fcmSnap.exists) {
    await fcmRef.delete();
  }

  await db.collection('users').doc(uid).delete();
  await admin.auth().deleteUser(uid);

  console.log('[deleteClientAccount] Cuenta eliminada:', uid);
  return {success: true};
});

// Mapeo de códigos de estado a texto
const ESTADOS = {
  1: 'Ingresado',
  2: 'Impresión y Transferencia',
  3: 'Confección',
  4: 'Acabados',
  5: 'Empacado',
  6: 'Entregado',
};

/** Payload `data.type` para routing en la app (debe coincidir con [FcmNotificationTypes]). */
const FCM_TYPE_NEW_ORDER_ADMIN = 'new_order_admin';
/** Cliente añadió mensaje en un pedido existente (editar pedido). */
const FCM_TYPE_CLIENT_MESSAGE_ADMIN = 'client_message_admin';

// Notifica al admin que generó el código cuando el cliente crea el pedido.
exports.onOrderCreatedNotifyAdmin = onDocumentCreated(
  'orders/{orderId}',
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('[onOrderCreatedNotifyAdmin] No snapshot');
      return;
    }

    const order = snap.data();
    const adminId = order.adminId;
    if (!adminId || typeof adminId !== 'string') {
      console.log(
        '[onOrderCreatedNotifyAdmin] Sin adminId en el pedido, se omite notificación',
      );
      return;
    }

    const orderCode = order.orderCode != null ? String(order.orderCode) : '';
    const titulo =
      order.title != null && String(order.title).trim()
        ? String(order.title).trim()
        : 'Pedido';

    const tokenDoc = await db.collection('fcmTokens').doc(adminId).get();
    if (!tokenDoc.exists) {
      console.log(
        '[onOrderCreatedNotifyAdmin] Sin token FCM para admin:',
        adminId,
      );
      return;
    }

    const token = tokenDoc.data()?.token;
    if (!token) {
      console.log(
        '[onOrderCreatedNotifyAdmin] Token vacío para admin:',
        adminId,
      );
      return;
    }

    const body =
      orderCode.length > 0
        ? `Código ${orderCode}: ${titulo}`
        : `Nuevo pedido: ${titulo}`;

    const message = {
      notification: {
        title: 'Nuevo pedido',
        body: body.length > 200 ? body.slice(0, 197) + '...' : body,
      },
      data: {
        type: FCM_TYPE_NEW_ORDER_ADMIN,
        orderCode: orderCode,
        orderId: event.params.orderId,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'pedidos_high',
          priority: 'high',
        },
      },
      token: token,
    };

    try {
      await admin.messaging().send(message);
      console.log(
        '[onOrderCreatedNotifyAdmin] Notificación enviada al admin:',
        adminId,
      );
    } catch (sendError) {
      console.error(
        '[onOrderCreatedNotifyAdmin] Error al enviar:',
        sendError.message,
      );
      throw sendError;
    }
  },
);

// Cliente envía un mensaje nuevo al editar el pedido: notificar al admin del código.
// Se omite el primer mensaje del pedido (el flujo de creación ya dispara onOrderCreatedNotifyAdmin).
exports.onClientMessageNotifyAdmin = onDocumentCreated(
  'messages/{messageId}',
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('[onClientMessageNotifyAdmin] No snapshot');
      return;
    }

    const msg = snap.data();
    const orderId =
      msg.orderId != null && msg.orderId !== ''
        ? String(msg.orderId)
        : null;
    const senderId =
      msg.userId != null && msg.userId !== '' ? String(msg.userId) : null;

    if (!orderId || !senderId) {
      console.log('[onClientMessageNotifyAdmin] Falta orderId o userId');
      return;
    }

    const orderRef = db.collection('orders').doc(orderId);
    const orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
      console.log('[onClientMessageNotifyAdmin] Pedido no existe:', orderId);
      return;
    }

    const order = orderSnap.data();
    const clientId =
      order.clientId != null ? String(order.clientId) : null;
    if (!clientId || clientId !== senderId) {
      console.log(
        '[onClientMessageNotifyAdmin] Mensaje no es del cliente del pedido, omitiendo',
      );
      return;
    }

    const countSnap = await db
      .collection('messages')
      .where('orderId', '==', orderId)
      .limit(2)
      .get();

    if (countSnap.size <= 1) {
      console.log(
        '[onClientMessageNotifyAdmin] Primer mensaje del pedido (ya notifica creación), omitiendo',
      );
      return;
    }

    const adminId = order.adminId;
    if (!adminId || typeof adminId !== 'string') {
      console.log(
        '[onClientMessageNotifyAdmin] Sin adminId en el pedido, se omite notificación',
      );
      return;
    }

    const orderCode =
      order.orderCode != null ? String(order.orderCode) : '';
    const titulo =
      order.title != null && String(order.title).trim()
        ? String(order.title).trim()
        : 'Pedido';

    const text =
      msg.message != null && String(msg.message).trim()
        ? String(msg.message).trim()
        : '';

    const preview =
      text.length > 120 ? text.slice(0, 117) + '...' : text;

    const tokenDoc = await db.collection('fcmTokens').doc(adminId).get();
    if (!tokenDoc.exists) {
      console.log(
        '[onClientMessageNotifyAdmin] Sin token FCM para admin:',
        adminId,
      );
      return;
    }

    const token = tokenDoc.data()?.token;
    if (!token) {
      console.log(
        '[onClientMessageNotifyAdmin] Token vacío para admin:',
        adminId,
      );
      return;
    }

    const bodyParts = [];
    if (orderCode.length > 0) bodyParts.push(`Código ${orderCode}`);
    bodyParts.push(titulo);
    if (preview.length > 0) bodyParts.push(preview);
    let body = bodyParts.join(' · ');
    if (body.length > 200) body = body.slice(0, 197) + '...';

    const fcmMessage = {
      notification: {
        title: 'Nuevo mensaje del cliente',
        body,
      },
      data: {
        type: FCM_TYPE_CLIENT_MESSAGE_ADMIN,
        orderCode: orderCode,
        orderId: orderId,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'pedidos_high',
          priority: 'high',
        },
      },
      token: token,
    };

    try {
      await admin.messaging().send(fcmMessage);
      console.log(
        '[onClientMessageNotifyAdmin] Notificación enviada al admin:',
        adminId,
      );
    } catch (sendError) {
      console.error(
        '[onClientMessageNotifyAdmin] Error al enviar:',
        sendError.message,
      );
      throw sendError;
    }
  },
);

// Envía notificación al cliente cuando el admin cambia el estado del pedido
exports.onOrderStateChange = onDocumentUpdated(
  'orders/{orderId}',
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      console.log('[onOrderStateChange] No before/after data');
      return;
    }

    const oldState = before.state;
    const newState = after.state;
    if (oldState === newState) {
      console.log('[onOrderStateChange] State unchanged, skipping');
      return;
    }

    const clientId = after.clientId;
    const orderCode = after.orderCode || '';
    const estadoTexto = ESTADOS[newState] || 'nuevo estado';

    console.log('[onOrderStateChange] State changed:', {
      orderCode,
      clientId,
      oldState,
      newState,
      estadoTexto,
    });

    if (!clientId) {
      console.log('[onOrderStateChange] No clientId, skipping');
      return;
    }

    const tokenDoc = await db.collection('fcmTokens').doc(clientId).get();
    if (!tokenDoc.exists) {
      console.log('[onOrderStateChange] No FCM token for clientId:', clientId);
      return;
    }

    const token = tokenDoc.data()?.token;
    if (!token) {
      console.log('[onOrderStateChange] Empty token for clientId:', clientId);
      return;
    }

    const message = {
      notification: {
        title: 'Actualización de pedido',
        body: `Tu pedido ${orderCode} pasó a ${estadoTexto}`,
      },
      data: {
        orderCode: String(orderCode),
        state: String(newState),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'pedidos_high',
          priority: 'high',
        },
      },
      token: token,
    };

    try {
      await admin.messaging().send(message);
      console.log('[onOrderStateChange] Notification sent to clientId:', clientId);
    } catch (sendError) {
      console.error('[onOrderStateChange] Error sending:', sendError.message);
      throw sendError;
    }
  }
);
