const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("./firebaseAdmin");
const {getFirestore} = require("firebase-admin/firestore");

// Inicializar Firebase Admin
const db = getFirestore();

/**
 * Libera postulaciones "aceptadas" que han expirado.
 * Esto significa que el postulante asignado no confirmó a tiempo.
 */
const liberarPostulacionesExpiradas = onSchedule({
  schedule: "every 5 minutes", // Ejecutar cada 5 minutos
  timeZone: "America/Santiago",
  retryCount: 2, // Reintentar en caso de error
}, async (event) => {
  console.log("Iniciando el proceso de liberación de postulaciones expiradas.");
  const ahora = admin.firestore.Timestamp.now();

  try {
    const postulacionesExpiradasQuery = await db
        .collectionGroup("postulaciones")
        .where("estado", "==", "aceptado")
        .where("confirmarAntesDe", "<", ahora)
        .get();

    if (postulacionesExpiradasQuery.empty) {
      console.log("No hay postulaciones expiradas para liberar.");
      return;
    }

    const totalEncontradas = postulacionesExpiradasQuery.size;
    console.log(`Encontradas ${totalEncontradas} postulaciones expiradas.`);

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

      console.log(
          `Procesando postulación expirada: ${doc.id} ` +
          `para trabajo ${trabajoId}`,
      );

      // 1. Actualiza el estado de la postulación en la colección de trabajos
      currentBatch.update(doc.ref, {
        estado: "expirado",
        liberadoPorExpiracionEn: ahora,
      });
      operationCount++;

      // 2. Actualiza el estado de la postulación en la colección de usuarios
      const postulacionUsuarioRef = db
          .collection("usuarios")
          .doc(postulanteId)
          .collection("postulaciones")
          .doc(trabajoId);

      currentBatch.update(postulacionUsuarioRef, {
        estado: "expirado",
        liberadoPorExpiracionEn: ahora,
      });
      operationCount++;

      // 3. Verificar si existen otras postulaciones aceptadas o confirmadas.
      const otrasPostulacionesQuery = await db
          .collection("trabajos")
          .doc(trabajoId)
          .collection("postulaciones")
          .where("estado", "in", ["aceptado", "confirmado"])
          .where("usuarioId", "!=", postulanteId) // Excluir la actual
          .limit(1) // Solo necesitamos saber si existe al menos una
          .get();

      // 3. Liberar el trabajo para que otros puedan postularse.
      const trabajoRef = db.collection("trabajos").doc(trabajoId);
      const trabajoDoc = await trabajoRef.get();
      if (!trabajoDoc.exists) {
        console.warn(
            `Trabajo ${trabajoId} no encontrado al liberar ` +
            "postulación expirada.",
        );
        continue;
      }
      const trabajoData = trabajoDoc.data();
      const sinFechaLimiteTrabajo = trabajoData?.sinFechaLimite === true;
      const nuevoEstadoAbierto = sinFechaLimiteTrabajo ? "abierto" : "activo";

      if (otrasPostulacionesQuery.empty) {
        // Sin aceptados/confirmados: restablecer estado del trabajo.
        currentBatch.update(trabajoRef, {
          trabajadorAsignadoId: null,
          estadoAsignacion: "disponible",
          estado: nuevoEstadoAbierto, // Cambiar estado a activo/abierto
          confirmacionExpiradaEn: ahora,
        });
        console.log(
            `Trabajo ${trabajoId} cambiado a estado "${nuevoEstadoAbierto}"`,
        );
      } else {
        // Mantener estado y limpiar la asignación.
        currentBatch.update(trabajoRef, {
          trabajadorAsignadoId: null,
          estadoAsignacion: "disponible",
          confirmacionExpiradaEn: ahora,
        });
        console.log(`Trabajo ${trabajoId} mantiene su estado actual`);
      }
      operationCount++;

      // Si nos acercamos al límite del batch, guardar y crear uno nuevo.
      // Dejar margen para no exceder el límite permitido.
      if (operationCount >= BATCH_LIMIT - 3) {
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

    const totalLiberadas = postulacionesExpiradasQuery.docs.length;
    console.log(`Se liberaron ${totalLiberadas} postulaciones expiradas.`);
  } catch (error) {
    console.error("Error al liberar postulaciones expiradas:", error);
    throw error; // Relanzar el error para que Firebase lo registre
  }
});

module.exports = {
  liberarPostulacionesExpiradas,
};