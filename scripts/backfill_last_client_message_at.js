#!/usr/bin/env node
/**
 * Rellena orders.lastClientMessageAt según el último mensaje del cliente.
 * Si no hay mensajes del cliente, usa orders.createdAt.
 *
 * Uso:
 *   cd functions && node ../scripts/backfill_last_client_message_at.js --project pedidosapp-5eb2c
 *   cd functions && node ../scripts/backfill_last_client_message_at.js --project pedidos-alkoto-prod --apply
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

function timestampMillis(ts) {
  if (!ts || typeof ts.toMillis !== 'function') return null;
  return ts.toMillis();
}

function timestampsEqual(a, b) {
  const ma = timestampMillis(a);
  const mb = timestampMillis(b);
  if (ma == null && mb == null) return true;
  if (ma == null || mb == null) return false;
  return ma === mb;
}

async function latestClientMessageAt(db, orderId, clientId) {
  const snap = await db
    .collection('messages')
    .where('orderId', '==', orderId)
    .get();

  let latest = null;
  for (const doc of snap.docs) {
    const data = doc.data();
    if (String(data.userId ?? '') !== clientId) continue;
    const createdAt = data.createdAt;
    if (!createdAt) continue;
    if (latest == null || createdAt.toMillis() > latest.toMillis()) {
      latest = createdAt;
    }
  }
  return latest;
}

async function main() {
  const { apply, projectId } = parseArgs(process.argv.slice(2));

  admin.initializeApp({ projectId });
  const db = admin.firestore();

  console.log('--- Backfill lastClientMessageAt ---');
  console.log(`Proyecto: ${projectId}`);
  console.log(`Modo: ${apply ? 'APPLY' : 'DRY-RUN'}\n`);

  const toUpdate = [];
  let unchanged = 0;
  let scanned = 0;
  let lastDoc = null;
  const pageSize = 300;
  let pageIndex = 0;

  while (true) {
    pageIndex++;
    let query = db
      .collection('orders')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(pageSize);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const page = await query.get();
    if (page.empty) break;

    console.log(
      `Página ${pageIndex}: ${page.size} documento(s) (máx ${pageSize} por página)\n`,
    );

    for (const orderDoc of page.docs) {
      scanned++;
      const data = orderDoc.data();
      const clientId =
        data.clientId != null && String(data.clientId).trim() !== ''
          ? String(data.clientId)
          : null;
      const stored = data.lastClientMessageAt ?? null;
      const orderCode =
        data.orderCode != null ? String(data.orderCode) : orderDoc.id;

      let target = null;
      if (clientId) {
        target = await latestClientMessageAt(db, orderDoc.id, clientId);
      }
      if (target == null) {
        target = data.createdAt ?? null;
      }

      if (target == null) {
        console.log(
          `[SKIP] Pedido ${orderCode} (${orderDoc.id}) | sin mensajes ni createdAt`,
        );
        continue;
      }

      if (timestampsEqual(stored, target)) {
        unchanged++;
        continue;
      }

      toUpdate.push({
        ref: orderDoc.ref,
        orderCode,
        orderId: orderDoc.id,
        target,
      });
      console.log(
        `[CAMBIO] Pedido ${orderCode} (${orderDoc.id}) | lastClientMessageAt → ${target.toDate?.() ?? target}`,
      );
    }

    lastDoc = page.docs[page.docs.length - 1];
    if (page.size < pageSize) {
      console.log(`Fin del listado (última página con ${page.size} docs).\n`);
      break;
    }
  }

  let totalInCollection = null;
  try {
    const countSnap = await db.collection('orders').count().get();
    totalInCollection = countSnap.data().count;
  } catch (_) {
    // count() no disponible en proyectos/SDK muy viejos
  }

  console.log('\n--- Resumen ---');
  if (totalInCollection != null) {
    console.log(`Total documentos en orders (Firestore count): ${totalInCollection}`);
  }
  console.log(`Pedidos escaneados: ${scanned}`);
  console.log(`Sin cambio: ${unchanged}`);
  console.log(`A escribir: ${toUpdate.length}`);

  if (toUpdate.length === 0) {
    console.log('\nNada que escribir.');
    return;
  }

  if (!apply) {
    console.log('\nDry-run terminado. Para aplicar: agrega --apply');
    return;
  }

  console.log('\nAplicando...');
  let written = 0;
  const batchSize = 400;

  for (let i = 0; i < toUpdate.length; i += batchSize) {
    const batch = db.batch();
    const chunk = toUpdate.slice(i, i + batchSize);
    for (const item of chunk) {
      batch.update(item.ref, { lastClientMessageAt: item.target });
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
