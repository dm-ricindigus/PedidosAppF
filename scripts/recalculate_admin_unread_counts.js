#!/usr/bin/env node
/**
 * Recalcula orders.adminUnreadMessageCount según mensajes con readByAdmin == false.
 *
 * Fase 1 (dry-run, default): solo muestra qué cambiaría.
 * Fase 2 (--apply): escribe en Firestore.
 *
 * Uso:
 *   cd functions && node ../scripts/recalculate_admin_unread_counts.js --project pedidos-alkoto-prod
 *   cd functions && node ../scripts/recalculate_admin_unread_counts.js --project pedidos-alkoto-prod --apply
 *
 * Credenciales (una de estas):
 *   - gcloud auth application-default login
 *   - export GOOGLE_APPLICATION_CREDENTIALS="/ruta/serviceAccount.json"
 */

const path = require('path');
const admin = require(path.join(__dirname, '../functions/node_modules/firebase-admin'));

function parseArgs(argv) {
  const apply = argv.includes('--apply');
  let projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;

  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--project' && argv[i + 1]) {
      projectId = argv[i + 1];
    } else if (argv[i].startsWith('--project=')) {
      projectId = argv[i].split('=')[1];
    }
  }

  if (!projectId) {
    projectId = 'pedidos-alkoto-prod';
  }

  return { apply, projectId };
}

function currentCount(data) {
  const raw = data?.adminUnreadMessageCount;
  if (typeof raw === 'number' && !Number.isNaN(raw)) return raw;
  return 0;
}

async function countUnreadMessages(db, orderId) {
  const snap = await db
    .collection('messages')
    .where('orderId', '==', orderId)
    .get();

  let unread = 0;
  for (const doc of snap.docs) {
    if (doc.data().readByAdmin === false) unread++;
  }
  return unread;
}

async function main() {
  const { apply, projectId } = parseArgs(process.argv.slice(2));

  admin.initializeApp({ projectId });
  const db = admin.firestore();

  console.log('--- Recalcular adminUnreadMessageCount ---');
  console.log(`Proyecto: ${projectId}`);
  console.log(`Modo: ${apply ? 'APPLY (escribe en BD)' : 'DRY-RUN (solo lectura)'}`);
  console.log('Regla: unread real = mensajes con readByAdmin === false\n');

  const ordersSnap = await db
    .collection('orders')
    .where('adminUnreadMessageCount', '>', 0)
    .get();

  if (ordersSnap.empty) {
    console.log('No hay pedidos con adminUnreadMessageCount > 0.');
    return;
  }

  console.log(`Pedidos con contador > 0: ${ordersSnap.size}\n`);

  const toUpdate = [];
  let unchanged = 0;

  for (const orderDoc of ordersSnap.docs) {
    const data = orderDoc.data();
    const stored = currentCount(data);
    const real = await countUnreadMessages(db, orderDoc.id);
    const orderCode = data.orderCode != null ? String(data.orderCode) : orderDoc.id;

    if (stored === real) {
      unchanged++;
      console.log(
        `[OK] Pedido ${orderCode} (${orderDoc.id}) | contador=${stored} | unread real=${real} | sin cambio`,
      );
      continue;
    }

    toUpdate.push({ ref: orderDoc.ref, orderCode, orderId: orderDoc.id, stored, real });
    console.log(
      `[CAMBIO] Pedido ${orderCode} (${orderDoc.id}) | contador=${stored} | unread real=${real} | → ${real}`,
    );
  }

  console.log('\n--- Resumen ---');
  console.log(`Revisados: ${ordersSnap.size}`);
  console.log(`Sin cambio (ya correctos): ${unchanged}`);
  console.log(`A corregir: ${toUpdate.length}`);

  if (toUpdate.length === 0) {
    console.log('\nNada que escribir.');
    return;
  }

  if (!apply) {
    console.log('\nDry-run terminado. Para aplicar: agrega --apply al mismo comando.');
    return;
  }

  console.log('\nAplicando updates...');
  let written = 0;
  const batchSize = 400;

  for (let i = 0; i < toUpdate.length; i += batchSize) {
    const batch = db.batch();
    const chunk = toUpdate.slice(i, i + batchSize);
    for (const item of chunk) {
      batch.update(item.ref, { adminUnreadMessageCount: item.real });
    }
    await batch.commit();
    written += chunk.length;
    console.log(`  Escritos ${written}/${toUpdate.length}`);
  }

  console.log('\nListo.');
}

main().catch((err) => {
  console.error('Error:', err.message || err);
  process.exit(1);
});
