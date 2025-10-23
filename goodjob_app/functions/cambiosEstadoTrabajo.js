const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const {onRequest} = require("firebase-functions/v2/https");
const admin = require("./firebaseAdmin");
const {CloudTasksClient} = require("@google-cloud/tasks");
const moment = require("moment-timezone");

const db = admin.firestore();
const client = new CloudTasksClient();

// Configuración de la cola de Cloud Tasks
const PROJECT_ID = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT;
const LOCATION_ID = "us-central1";
const QUEUE_ID = "cola-cambios-estado";
const TIMEZONE = "America/Santiago"; // Zona horaria de Chile

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

  // CORRECCIÓN: Las fechas en Firestore están en hora local de Chile (UTC-3)
  // pero los Timestamps de Firestore son siempre UTC.
  // Necesitamos interpretar la fecha como si fuera Chile y convertir a UTC real.
  const fechaOriginal = fechaTimestamp.toDate();
  
  // Interpretar la fecha como si fuera Chile (quitando la conversión UTC)
  const fechaMomentChile = moment.tz(
      {
        year: fechaOriginal.getUTCFullYear(),
        month: fechaOriginal.getUTCMonth(),
        day: fechaOriginal.getUTCDate(),
        hour: fechaOriginal.getUTCHours(),
        minute: fechaOriginal.getUTCMinutes(),
        second: fechaOriginal.getUTCSeconds(),
      },
      TIMEZONE,
  );

  // Convertir a UTC para programar la tarea
  const fechaUTCCorrecta = fechaMomentChile.utc();
  const timestampCorregido = Math.floor(fechaUTCCorrecta.valueOf() / 1000);

  console.log(
      `Programando tarea para trabajo ${trabajoId} al estado ${nuevoEstado}:` +
      `\n  - Fecha guardada en Firestore (interpretada como UTC): ${fechaOriginal.toISOString()}` +
      `\n  - Fecha interpretada como Chile: ${fechaMomentChile.format("YYYY-MM-DD HH:mm:ss z")}` +
      `\n  - Fecha UTC correcta para ejecución: ${fechaUTCCorrecta.format("YYYY-MM-DD HH:mm:ss z")}`,
  );

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
    // Programar con la fecha UTC corregida
    scheduleTime: {seconds: timestampCorregido},
    // Configuración de reintentos: máximo 3 intentos
    retryConfig: {
      maxAttempts: 3,
      maxRetryDuration: {seconds: 300}, // 5 minutos máximo
      minBackoff: {seconds: 10},
      maxBackoff: {seconds: 60},
      maxDoublings: 2,
    },
  };

  const [response] = await client.createTask({parent, task});
  console.log(
      `Tarea programada exitosamente: ${response.name}`,
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
const cambioEstadoTrabajo = onRequest(
    {
      maxInstances: 10,
      timeoutSeconds: 60,
      memory: "256MiB",
    },
    async (req, res) => {
      // Validar que sea una petición POST
      if (req.method !== "POST") {
        res.status(405).send("Método no permitido. Use POST");
        return;
      }

      const {trabajoId, nuevoEstado} = req.body;
      if (!trabajoId || !nuevoEstado) {
        console.error("Faltan parámetros en la petición:", req.body);
        res.status(400).send("Faltan parámetros trabajoId o nuevoEstado");
        return;
      }

      // Obtener la hora actual en Chile para logging
      const ahora = moment().tz(TIMEZONE);
      const ahoraChile = ahora.format("YYYY-MM-DD HH:mm:ss z");

      console.log(
          `[${ahoraChile}] Procesando cambio de estado para trabajo ` +
        `${trabajoId} a ${nuevoEstado}`,
      );

      try {
        const trabajoRef = db.collection("trabajos").doc(trabajoId);
        const trabajoDoc = await trabajoRef.get();

        if (!trabajoDoc.exists) {
          console.error(
              `[${ahoraChile}] Trabajo ${trabajoId} no encontrado en Firestore`,
          );
          res.status(404).send(`Trabajo ${trabajoId} no encontrado`);
          return;
        }

        const trabajoData = trabajoDoc.data();
        const estadoActual = trabajoData.estado;
        const estadoActualNormalizado = (estadoActual || "").toLowerCase();

        console.log(
            `[${ahoraChile}] Estado actual del trabajo ${trabajoId}: ` +
          `${estadoActual}`,
        );

        if (nuevoEstado === "enCurso") {
          if (estadoActualNormalizado === "pendiente") {
            await trabajoRef.update({
              estado: "enCurso",
              actualizadoEn: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log(
                `[${ahoraChile}] Trabajo ${trabajoId} cambiado exitosamente ` +
              `a enCurso`,
            );
            res
                .status(200)
                .send(
                    `Estado del trabajo ${trabajoId} cambiado a ${nuevoEstado}`,
                );
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
            console.log(
                `[${ahoraChile}] Trabajo ${trabajoId} finalizado ` +
              "(no tenía trabajador confirmado)",
            );
            res
                .status(200)
                .send(
                    `Trabajo ${trabajoId} cambiado a "finalizado" ` +
                "porque no estaba en estado \"pendiente\"",
                );
            return;
          }

          console.log(
              `[${ahoraChile}] Trabajo ${trabajoId} en estado ` +
            `"${estadoActual}", no se realizó cambio`,
          );
          res
              .status(200)
              .send(
                  `Trabajo ${trabajoId} está en estado "${estadoActual}", ` +
              "no se realizó cambio",
              );
          return;
        }

        if (nuevoEstado === "porRevisar") {
          if (estadoActualNormalizado !== "encurso") {
            console.log(
                `[${ahoraChile}] Trabajo ${trabajoId} no está en estado ` +
              `"enCurso", no se cambia a porRevisar`,
            );
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
          console.log(
              `[${ahoraChile}] Trabajo ${trabajoId} cambiado exitosamente ` +
            `a porRevisar`,
          );
          res
              .status(200)
              .send(
                  `Estado del trabajo ${trabajoId} cambiado a ${nuevoEstado}`,
              );
          return;
        }

        // Caso genérico para otros estados
        await trabajoRef.update({
          estado: nuevoEstado,
          actualizadoEn: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(
            `[${ahoraChile}] Trabajo ${trabajoId} cambiado exitosamente a ` +
          `${nuevoEstado}`,
        );
        res
            .status(200)
            .send(`Estado del trabajo ${trabajoId} cambiado a ${nuevoEstado}`);
      } catch (error) {
        console.error(
            `Error al cambiar el estado del trabajo ${trabajoId}:`,
            error,
        );
        res
            .status(500)
            .send(`Error al cambiar el estado del trabajo: ${error.message}`);
      }
    },
);

module.exports = {
  programarTareasDeTrabajo,
  reprogramarTareasSiCambia,
  cambioEstadoTrabajo,
};