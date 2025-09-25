import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import admin from './firebaseAdmin.js';

/**
 * Notificaciones cuando un trabajo es cancelado
 */
export const notifyTrabajoCancelado = onDocumentUpdated({
  document: 'trabajos/{trabajoId}',
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log('No data associated with the event');
    return;
  }

  const before = snapshot.before.data();
  const after = snapshot.after.data();
  const trabajoId = event.params.trabajoId;

  if (before.estado === 'cancelado' || after.estado !== 'cancelado') {
    console.log('El estado no cambió a cancelado o ya estaba cancelado');
    return null;
  }

  const titulo = after.titulo || "este trabajo";

  try {
    // Obtener todas las postulaciones del trabajo
    const postulacionesSnap = await admin
      .firestore()
      .collection(`trabajos/${trabajoId}/postulaciones`)
      .get();

    if (postulacionesSnap.empty) {
      console.log(`No hay postulaciones para el trabajo ${trabajoId}`);
      return null;
    }

    // Obtener tokens de todos los postulantes en paralelo
    const tokensArrays = await Promise.all(
      postulacionesSnap.docs.map(async (postulacionDoc) => {
        const postulacion = postulacionDoc.data();
        const usuarioId = postulacion.usuarioId;
        if (!usuarioId) return [];

        const tokensSnap = await admin
          .firestore()
          .collection(`usuarios/${usuarioId}/fcm_tokens`)
          .get();

        return tokensSnap.docs
          .map(tokenDoc => tokenDoc.data().token)
          .filter(Boolean);
      })
    );

    // Aplanar array de arrays en un solo array de tokens
    const tokens = tokensArrays.flat();

    if (tokens.length === 0) {
      console.log(`No hay tokens FCM para las postulaciones del trabajo ${trabajoId}`);
      return null;
    }

    // Construir mensajes para sendAll
    const messages = tokens.map(token => ({
      token,
      notification: {
        title: 'Trabajo Cancelado',
        body: `El trabajo "${titulo}" ha sido cancelado, disculpa las molestias.`,
      },
      data: {
        trabajoId,
        tipo: 'trabajo_cancelado'
      }
    }));

    // Enviar todos los mensajes
    const response = await admin.messaging().sendAll(messages);

    console.log("Notificaciones enviadas:", response.successCount);
    console.log("Fallos en notificaciones:", response.failureCount);

    // Opcional: limpiar tokens inválidos automáticamente
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        console.log(`Token inválido: ${tokens[idx]}, error:`, resp.error);
        // Agregar lógica para borrar el token de Firestore si es necesario
      }
    });

    return null;
  } catch (error) {
    console.error('Error en notifyTrabajoCancelado:', error);
    return null;
  }
});