import * as admin from 'firebase-admin';

const db = admin.firestore();

/**
 * Libera postulaciones "aceptadas" que han expirado.
 * Esto significa que el postulante asignado no confirmó a tiempo.
 */
export const liberarPostulacionesExpiradas = async () => {
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
      return null;
    }

    const batch = db.batch();

    for (const doc of postulacionesExpiradasQuery.docs) {
      const postulacionData = doc.data();
      const trabajoId = doc.ref.parent.parent?.id;
      const postulanteId = postulacionData.usuarioId;

      if (!trabajoId || !postulanteId) {
        console.warn(`Postulación mal formada, saltando: ${doc.id}`);
        continue;
      }

      // 1. Actualiza el estado de la postulación en la colección de trabajos
      batch.update(doc.ref, {
        estado: 'expirado',
        liberadoPorExpiracionEn: ahora,
      });

      // 2. Actualiza el estado de la postulación en la colección de usuarios
      const postulacionUsuarioRef = db
        .collection('usuarios')
        .doc(postulanteId)
        .collection('postulaciones')
        .doc(trabajoId);

      batch.update(postulacionUsuarioRef, {
        estado: 'expirado',
        liberadoPorExpiracionEn: ahora,
      });

      // 3. Libera el trabajo para que otros puedan postularse
      const trabajoRef = db.collection('trabajos').doc(trabajoId);
      batch.update(trabajoRef, {
        trabajadorAsignadoId: admin.firestore.FieldValue.delete(),
        estadoAsignacion: admin.firestore.FieldValue.delete(),
        confirmacionExpiradaEn: ahora,
      });
    }

    await batch.commit();
    console.log(`Se liberaron ${postulacionesExpiradasQuery.docs.length} postulaciones expiradas.`);
    return null;
  } catch (e) {
    console.error('Error al liberar postulaciones expiradas:', e);
    return null;
  }
};