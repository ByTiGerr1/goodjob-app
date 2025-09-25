const functions = require("firebase-functions/v1");
const admin = require('./firebaseAdmin');

// Notificaciones cuando un trabajo es cancelado
exports.notifyTrabajoCancelado = functions.firestore
  .document('trabajos/{trabajoId}')
  .onUpdate(async (change, context) => {
    const trabajoId = context.params.trabajoId;
    const before = change.before.data();
    const after = change.after.data();

    // Solo continuar si el estado cambió a "cancelado"
    if (before.estado === 'cancelado' || after.estado !== 'cancelado') {
      return null;
    }

    const titulo = after.titulo || "este trabajo";

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
        console.log(`Token inválido: ${tokens[idx]}, eliminando...`);
        // Aquí podrías borrar el token de Firestore
      }
    });

    return null;
  });
