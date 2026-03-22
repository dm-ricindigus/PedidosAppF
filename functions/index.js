const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentUpdated} = require('firebase-functions/v2/firestore');
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

// Mapeo de códigos de estado a texto
const ESTADOS = {
  1: 'Ingresado',
  2: 'Impresión y Transferencia',
  3: 'Confección',
  4: 'Acabados',
  5: 'Empacado',
  6: 'Entregado',
};

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
