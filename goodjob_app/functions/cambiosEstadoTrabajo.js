const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const {onRequest} = require("firebase-functions/v2/https");
const admin = require("./firebaseAdmin");
const {CloudTasksClient} = require("@google-cloud/tasks");

const db = admin.firestore();
const client = new CloudTasksClient();

// Configuración de la cola de Cloud Tasks
const PROJECT_ID = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT;
const LOCATION_ID = "us-central1";
const QUEUE_ID = "cola-cambios-estado";

/**
 * Crea una tarea programada que actualizará el estado de un trabajo.
 * @param {string} trabajoId ID del trabajo en Firestore.
 * @param {admin.firestore.Timestamp} fechaTimestamp Momento para ejecutar.
 * @param {string} nuevoEstado Estado que debe aplicarse al disparar la tarea.
 * @return {Promise<object>} Respuesta devuelta por Cloud Tasks.
 */
async function programarTareaCambioEstado(
    trabajoId,
    fechaTimestamp,
    nuevoEstado,
) {
  const parent = client.queuePath(PROJECT_ID, LOCATION_ID, QUEUE_ID);
  const urlBase = `https://${LOCATION_ID}-${PROJECT_ID}`;
  const url = `${urlBase}.cloudfunctions.net/cambioEstadoTrabajo`;

  const task = {
    httpRequest: {
      httpMethod: "POST",
      url,
      headers: {"Content-Type": "application/json"},
      body: Buffer.from(
          JSON.stringify({
            trabajoId,
            nuevoEstado,
          }),
      ).toString("base64"),
    },
    // Programar para la fecha indicada por el timestamp recibido.
    scheduleTime: {seconds: fechaTimestamp.seconds},
  };

  const [response] = await client.createTask({parent, task});
  console.log(
      `Tarea programada: ${response.name} para trabajo ${trabajoId} ` +
      `al estado ${nuevoEstado}`,
  );
  return response;
}

// Cloud Function: se ejecuta al crear un trabajo.
const programarTareasDeTrabajo = onDocumentCreated(
    "trabajos/{trabajoId}",
    async (event) => {
      const trabajoId = event.params.trabajoId;
      const trabajoData = event.data?.data();

      if (!trabajoData) return;

      const {fechaInicioTrabajo, fechaFinTrabajo} = trabajoData;
      if (fechaInicioTrabajo && fechaFinTrabajo) {
      // Programar tarea para cambiar a "En curso"
        await programarTareaCambioEstado(
            trabajoId,
            fechaInicioTrabajo,
            "enCurso",
        );
        // Programar tarea para cambiar a "Por revisar"
        await programarTareaCambioEstado(
            trabajoId,
            fechaFinTrabajo,
            "porRevisar",
        );
      }

      console.log(`Tareas programadas para el trabajo ${trabajoId}`);
    },
);

// Cloud Function: si cambian las fechas de un trabajo, actualizar las tareas.
const reprogramarTareasSiCambia = onDocumentUpdated(
    "trabajos/{trabajoId}",
    async (event) => {
      const trabajoId = event.params.trabajoId;
      const beforeData = event.data?.before.data();
      const afterData = event.data?.after.data();
      if (!beforeData || !afterData) return;

      const inicioCambio =
      beforeData.fechaInicioTrabajo?.seconds !==
      afterData.fechaInicioTrabajo?.seconds;
      const finCambio =
      beforeData.fechaFinTrabajo?.seconds !==
      afterData.fechaFinTrabajo?.seconds;

      if (inicioCambio || finCambio) {
        console.log(
            `Fechas cambiaron para el trabajo ${trabajoId}, ` +
          "reprogramando tareas...",
        );
        await programarTareaCambioEstado(
            trabajoId,
            afterData.fechaInicioTrabajo,
            "enCurso",
        );
        await programarTareaCambioEstado(
            trabajoId,
            afterData.fechaFinTrabajo,
            "porRevisar",
        );
      }
    },
);

// Cloud Function HTTP: cambia el estado del trabajo cuando se ejecuta la tarea.
const cambioEstadoTrabajo = onRequest(async (req, res) => {
  const {trabajoId, nuevoEstado} = req.body;
  if (!trabajoId || !nuevoEstado) {
    res.status(400).send("Faltan parámetros trabajoId o nuevoEstado");
    return;
  }

  try {
    const trabajoRef = db.collection("trabajos").doc(trabajoId);
    const trabajoDoc = await trabajoRef.get();

    if (!trabajoDoc.exists) {
      res.status(404).send(`Trabajo ${trabajoId} no encontrado`);
      return;
    }

    const trabajoData = trabajoDoc.data();
    const estadoActual = trabajoData.estado;
    const estadoActualNormalizado = (estadoActual || "").toLowerCase();

    if (nuevoEstado === "enCurso") {
      if (estadoActualNormalizado === "pendiente") {
        await trabajoRef.update({
          estado: "enCurso",
          actualizadoEn: admin.firestore.FieldValue.serverTimestamp(),
        });
        res
            .status(200)
            .send(`Estado del trabajo ${trabajoId} cambiado a ${nuevoEstado}`);
        return;
      }

      const puedeFinalizar =
        estadoActualNormalizado === "activo" ||
        estadoActualNormalizado === "abierto" ||
        estadoActualNormalizado === "porconfirmar";
      if (puedeFinalizar) {
        await trabajoRef.update({
          estado: "finalizado",
          actualizadoEn: admin.firestore.FieldValue.serverTimestamp(),
          razonFinalizacion:
            "No tenía un trabajador confirmado al momento de iniciar",
        });
        res
            .status(200)
            .send(
                `Trabajo ${trabajoId} cambiado a "finalizado" ` +
              "porque no estaba en estado \"pendiente\"",
            );
        return;
      }

      res
          .status(200)
          .send(
              `Trabajo ${trabajoId} está en estado "${estadoActual}", ` +
            "no se realizó cambio",
          );
      return;
    }

    if (nuevoEstado === "porRevisar") {
      if (estadoActual !== "enCurso") {
        res
            .status(200)
            .send(
                `Trabajo ${trabajoId} no está en estado "enCurso", ` +
              "no se realizó el cambio",
            );
        return;
      }

      await trabajoRef.update({
        estado: "porRevisar",
        actualizadoEn: admin.firestore.FieldValue.serverTimestamp(),
      });
      res
          .status(200)
          .send(`Estado del trabajo ${trabajoId} cambiado a ${nuevoEstado}`);
      return;
    }

    await trabajoRef.update({
      estado: nuevoEstado,
      actualizadoEn: admin.firestore.FieldValue.serverTimestamp(),
    });
    res
        .status(200)
        .send(`Estado del trabajo ${trabajoId} cambiado a ${nuevoEstado}`);
  } catch (error) {
    console.error("Error al cambiar el estado del trabajo:", error);
    res.status(500).send("Error al cambiar el estado del trabajo");
  }
});

module.exports = {
  programarTareasDeTrabajo,
  reprogramarTareasSiCambia,
  cambioEstadoTrabajo,
};