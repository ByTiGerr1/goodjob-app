import { onCall } from "firebase-functions/v2/https";
import { SecretManagerServiceClient } from "@google-cloud/secret-manager";
import crypto from "crypto";

// Cliente de Secret Manager
const client = new SecretManagerServiceClient();

// Configuración para las funciones
const functionOptions = {
  region: "us-central1",
  timeoutSeconds: 60,
  memory: "256MiB",
};

// Reemplazar YOUR_PROJECT_ID por el ID de tu proyecto Firebase
const PROJECT_ID = "good-job-1";
const SECRET_NAME = "ENCRYPTION_KEY";

/**
 * Obtiene la clave de cifrado desde Secret Manager.
 * @return {Promise<Buffer>} Clave de cifrado en formato Buffer.
 */
async function getEncryptionKey() {
  const [version] = await client.accessSecretVersion({
    name: `projects/${PROJECT_ID}/secrets/${SECRET_NAME}/versions/latest`,
  });
  const payload = version.payload.data.toString("utf8");
  return Buffer.from(payload, "base64");
}

/**
 * Cifra texto plano utilizando AES-256-CBC.
 * @param {Object} request - Request object from Firebase Functions v2
 * @return {Promise<{encrypted: string}>} Texto cifrado en base64.
 */
export const encryptData = onCall(functionOptions, async (request) => {
  const text = request.data?.text;
  console.log("Texto recibido:", text);

  if (!text) {
    throw new Error("invalid-argument: No text provided");
  }

  const plainText = typeof text === "string" ? text : String(text);

  const key = await getEncryptionKey();
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv("aes-256-cbc", key, iv);

  let encrypted = cipher.update(plainText, "utf8", "base64");
  encrypted += cipher.final("base64");

  const payload = Buffer
      .concat([iv, Buffer.from(encrypted, "base64")])
      .toString("base64");
  
  console.log("Encriptación exitosa");
  return { encrypted: payload };
});

/**
 * Desencripta texto cifrado generado por encryptData.
 * @param {Object} request - Request object from Firebase Functions v2
 * @return {Promise<{decrypted: string}>} Texto desencriptado.
 */
export const decryptData = onCall(functionOptions, async (request) => {
  const encrypted = request.data?.encrypted;
  
  if (typeof encrypted !== "string" || encrypted.length === 0) {
    throw new Error("invalid-argument: No encrypted data provided");
  }

  const key = await getEncryptionKey();
  const payload = Buffer.from(encrypted, "base64");

  const iv = payload.subarray(0, 16);
  const encryptedText = payload.subarray(16);

  const decipher = crypto.createDecipheriv("aes-256-cbc", key, iv);
  let decrypted = decipher.update(encryptedText, undefined, "utf8");
  decrypted += decipher.final("utf8");

  return { decrypted };
});