const {onCall, HttpsError} = require('firebase-functions/v2/https');
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
