import {onDocumentCreated, onDocumentUpdated} from 'firebase-functions/v2/firestore';
import {onRequest} from 'firebase-functions/v2/https';
import admin from './firebaseAdmin.js';
import {CloudTasksClient} from '@google-cloud/tasks';

const db = admin.firestore();
const client = new CloudTasksClient();

// Configuración de la cola de Cloud Tasks
const PROJECT_ID = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT;
const LOCATION_ID = 'us-central1';
const QUEUE_ID = 'cola-cambios-estado';

// Función para programar una tarea
async function programarTareaCambioEstado(trabajoId, fechaTimestamp, nuevoEstado){
    const parent = client.queuePath(PROJECT_ID, LOCATION_ID, QUEUE_ID);
    const url = `https://${LOCATION_ID}-${PROJECT_ID}.cloudfunctions.net/cambioEstadoTrabajo`;

    const task = {
        httpRequest: {
            httpMethod: 'POST',
            url,
            headers: {'Content-Type': 'application/json'},
            body: Buffer.from(JSON.stringify({
                trabajoId,
                nuevoEstado
            })).toString('base64'),
        },
        scheduleTime: { seconds: fechaTimestamp.seconds}, // Programar para la fecha dada
    };

    const [response] = await client.createTask({ parent, task});
    console.log(`Tarea programada: ${response.name} para trabajo ${trabajoId} al estado ${nuevoEstado}`);
    return response;
}

// Cloud Function: se ejecuta cuando se ejecuta al crear un trabajo.
export const programarTareasDeTrabajo = onDocumentCreated('trabajos/{trabajoId}', async (event) => {
    const trabajoId = event.params.trabajoId;
    const trabajoData = event.data?.data();
    
    if (!trabajoData) return;

    const {fechaInicioTrabajo, fechaFinTrabajo} = trabajoData;
    if (fechaInicioTrabajo && fechaFinTrabajo) {
        // Programar tarea para cambiar a "En curso"
        await programarTareaCambioEstado(trabajoId, fechaInicioTrabajo, 'enCurso');
        // Programar tarea para cambiar a "Por revisar"
        await programarTareaCambioEstado(trabajoId, fechaFinTrabajo, 'porRevisar');
    }
    
    console.log(`Tareas programadas para el trabajo ${trabajoId}`);
});

// Cloud Function: si cambian las fechas de un trabajo, actualizar las tareas programadas.
export const reprogramarTareasSiCambia = onDocumentUpdated('trabajos/{trabajoId}', async (event) => {
    const trabajoId = event.params.trabajoId;
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    if (!beforeData || !afterData) return;

    if (
        beforeData.fechaInicioTrabajo?.seconds !== afterData.fechaInicioTrabajo?.seconds ||
        beforeData.fechaFinTrabajo?.seconds !== afterData.fechaFinTrabajo?.seconds
    ) {
        console.log(`Fechas cambiaron para el trabajo ${trabajoId}, reprogramando tareas...`);
        await programarTareaCambioEstado(trabajoId, afterData.fechaInicioTrabajo, 'enCurso');
        await programarTareaCambioEstado(trabajoId, afterData.fechaFinTrabajo, 'porRevisar');
    }
});

// Cloud Function HTTP: cambia el estado del trabajo cuando se ejecuta la tarea programada.
export const cambioEstadoTrabajo = onRequest(async (req, res) => {
        const {trabajoId, nuevoEstado} = req.body;
        if (!trabajoId || !nuevoEstado) {
            res.status(400).send('Faltan parámetros trabajoId o nuevoEstado');
            return;
        }
    try {
        // Obtener el documento del trabajo
        const trabajoRef = db.collection('trabajos').doc(trabajoId);
        const trabajoDoc = await trabajoRef.get();
        
        if (!trabajoDoc.exists) {
            res.status(404).send(`Trabajo ${trabajoId} no encontrado`);
            return;
        }
        
        const trabajoData = trabajoDoc.data();
        const estadoActual = trabajoData.estado;
        const estadoActualNormalizado = (estadoActual || '').toLowerCase();
        
        // Validaciones según el nuevo estado
        if (nuevoEstado === 'enCurso') {
            // Verificar que el estado actual sea "pendiente"
            if (estadoActualNormalizado === 'pendiente') {
                // Si está en pendiente, cambiar a "En curso"
                await trabajoRef.update({
                    estado: 'enCurso',
                    actualizadoEn: admin.firestore.FieldValue.serverTimestamp(),
                });
                console.log(`Estado del trabajo ${trabajoId} cambiado a ${nuevoEstado}`);
                res.status(200).send(`Estado del trabajo ${trabajoId} cambiado a ${nuevoEstado}`);
                return;
            }
            
            // Solo finalizar si estaba en "activo" o "porConfirmar" (estados sin trabajador confirmado)
            if (estadoActualNormalizado === 'activo' || estadoActualNormalizado === 'abierto' || estadoActualNormalizado === 'porconfirmar') {
                await trabajoRef.update({
                    estado: 'finalizado',
                    actualizadoEn: admin.firestore.FieldValue.serverTimestamp(),
                    razonFinalizacion: 'No tenía un trabajador confirmado al momento de iniciar'
                });
                console.log(`Trabajo ${trabajoId} cambiado a "finalizado" porque no estaba en estado "pendiente" (estado actual: ${estadoActual})`);
                res.status(200).send(`Trabajo ${trabajoId} cambiado a "finalizado" porque no estaba en estado "pendiente"`);
                return;
            }
            
            // Para cualquier otro estado (cancelado, finalizado, etc.), no hacer nada
            console.log(`Trabajo ${trabajoId} está en estado "${estadoActual}", no se realiza cambio`);
            res.status(200).send(`Trabajo ${trabajoId} está en estado "${estadoActual}", no se realizó cambio`);
            return;
        }
        
        if (nuevoEstado === 'porRevisar') {
            // Verificar que el estado actual sea "En curso"
            if (estadoActual !== 'enCurso') {
                console.log(`Trabajo ${trabajoId} no está en estado "enCurso" (estado actual: ${estadoActual}), no se cambia a "Por revisar"`);
                res.status(200).send(`Trabajo ${trabajoId} no está en estado "enCurso", no se realizó el cambio`);
                return;
            }
            
            // Si está en curso, cambiar a "Por revisar"
            await trabajoRef.update({
                estado: 'porRevisar',
                actualizadoEn: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log(`Estado del trabajo ${trabajoId} cambiado a ${nuevoEstado}`);
            res.status(200).send(`Estado del trabajo ${trabajoId} cambiado a ${nuevoEstado}`);
            return;
        }
        
        // Para cualquier otro estado, realizar el cambio sin validaciones adicionales
        await trabajoRef.update({
            estado: nuevoEstado,
            actualizadoEn: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`Estado del trabajo ${trabajoId} cambiado a ${nuevoEstado}`);
        res.status(200).send(`Estado del trabajo ${trabajoId} cambiado a ${nuevoEstado}`);
    } catch (error) {
        console.error('Error al cambiar el estado del trabajo:', error);
        res.status(500).send('Error al cambiar el estado del trabajo');
    }
});