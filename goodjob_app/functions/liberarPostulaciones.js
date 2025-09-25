import { onSchedule } from "firebase-functions/v2/scheduler";
import admin from './firebaseAdmin.js';
import { getFirestore } from "firebase-admin/firestore";

// Inicializar Firebase Admin
const db = getFirestore();

/**
 * Libera postulaciones "aceptadas" que han expirado.
 * Esto significa que el postulante asignado no confirmó a tiempo.
 */
export const liberarPostulacionesExpiradas = onSchedule({
  schedule: "every 5 minutes", // Ejecutar cada 5 minutos
  timeZone: "America/Santiago", 
  retryCount: 2, // Reintentar en caso de error
}, async (event) => {
  console.log('Iniciando el proceso de liberación de postulaciones expiradas.');
  const ahora = admin.firestore.Timestamp.now();

  try {
    const postulacionesExpiradasQuery = await db
      .collectionGroup('postulaciones')
      .where('estado', '==', 'aceptado')
      .where('confirmarAntesDe', '<', ahora)
      .get();

    if (postulacionesExpiradasQuery.empty) {
      console.log('No hay postulaciones expiradas para liberar.');
      return;
    }

    console.log(`Encontradas ${postulacionesExpiradasQuery.size} postulaciones expiradas.`);

    // Usar batches para evitar límites de escritura
    const batches = [];
    let currentBatch = db.batch();
    let operationCount = 0;
    const BATCH_LIMIT = 500; // Límite de Firestore

    for (const doc of postulacionesExpiradasQuery.docs) {
      const postulacionData = doc.data();
      const trabajoId = doc.ref.parent.parent?.id;
      const postulanteId = postulacionData.usuarioId;

      if (!trabajoId || !postulanteId) {
        console.warn(`Postulación mal formada, saltando: ${doc.id}`);
        continue;
      }

      console.log(`Procesando postulación expirada: ${doc.id} para trabajo ${trabajoId}`);

      // 1. Actualiza el estado de la postulación en la colección de trabajos
      currentBatch.update(doc.ref, {
        estado: 'expirado',
        liberadoPorExpiracionEn: ahora,
      });
      operationCount++;

      // 2. Actualiza el estado de la postulación en la colección de usuarios
      const postulacionUsuarioRef = db
        .collection('usuarios')
        .doc(postulanteId)
        .collection('postulaciones')
        .doc(trabajoId);

      currentBatch.update(postulacionUsuarioRef, {
        estado: 'expirado',
        liberadoPorExpiracionEn: ahora,
      });
      operationCount++;

      // 3. Libera el trabajo para que otros puedan postularse
      const trabajoRef = db.collection('trabajos').doc(trabajoId);
      currentBatch.update(trabajoRef, {
        trabajadorAsignadoId: null,
        estadoAsignacion: 'disponible',
        confirmacionExpiradaEn: ahora,
      });
      operationCount++;

      // Si nos acercamos al límite del batch, guardar y crear uno nuevo
      if (operationCount >= BATCH_LIMIT - 3) { // Dejar margen
        batches.push(currentBatch);
        currentBatch = db.batch();
        operationCount = 0;
      }
    }

    // Agregar el último batch si tiene operaciones
    if (operationCount > 0) {
      batches.push(currentBatch);
    }

    // Ejecutar todos los batches
    for (let i = 0; i < batches.length; i++) {
      await batches[i].commit();
      console.log(`Batch ${i + 1}/${batches.length} commit exitoso`);
    }

    console.log(`Se liberaron ${postulacionesExpiradasQuery.docs.length} postulaciones expiradas.`);
    
  } catch (error) {
    console.error('Error al liberar postulaciones expiradas:', error);
    throw error; // Relanzar el error para que Firebase lo registre
  }
});