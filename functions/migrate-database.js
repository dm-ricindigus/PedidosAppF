/**
 * Script para migrar datos de bdpedidos4 a la base de datos default
 * Ejecutar con: node migrate-database.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // Necesitarás descargar esto

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const sourceDb = admin.firestore().database('bdpedidos4');
const targetDb = admin.firestore(); // default

async function migrateCollection(collectionName) {
  console.log(`Migrando colección: ${collectionName}`);
  
  const snapshot = await sourceDb.collection(collectionName).get();
  const batch = targetDb.batch();
  let count = 0;

  snapshot.forEach((doc) => {
    batch.set(targetDb.collection(collectionName).doc(doc.id), doc.data());
    count++;
  });

  if (count > 0) {
    await batch.commit();
    console.log(`✅ Migrados ${count} documentos de ${collectionName}`);
  } else {
    console.log(`⚠️  No hay documentos en ${collectionName}`);
  }
}

async function migrateAll() {
  try {
    // Lista de colecciones a migrar
    const collections = ['users', 'orderCodes', 'orders']; // Ajusta según tus colecciones
    
    for (const collection of collections) {
      await migrateCollection(collection);
    }
    
    console.log('✅ Migración completada');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error en migración:', error);
    process.exit(1);
  }
}

migrateAll();
