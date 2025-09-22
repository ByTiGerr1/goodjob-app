const functions = require("firebase-functions");
const {SecretManagerServiceClient} = require("@google-cloud/secret-manager");
const crypto = require("crypto");

// Cliente de Secret Manager
const client = new SecretManagerServiceClient();

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
 * @param {{text: unknown}} data Datos recibidos desde el cliente.
 * @return {Promise<{encrypted: string}>} Texto cifrado en base64.
 */
exports.encryptData = functions.https.onCall(async (data, context) => {
  const text = data?.text;
  if (text === undefined || text === null) {
    throw new functions.https.HttpsError(
        "invalid-argument", "No text provided",
    );
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
  return {encrypted: payload};
});

/**
 * Desencripta texto cifrado generado por encryptData.
 * @param {{encrypted: unknown}} data Datos recibidos desde el cliente.
 * @return {Promise<{decrypted: string}>} Texto desencriptado.
 */
exports.decryptData = functions.https.onCall(async (data, context) => {
  const encrypted = data?.encrypted;
  if (typeof encrypted !== "string" || encrypted.length === 0) {
    throw new functions.https.HttpsError(
        "invalid-argument", "No encrypted data provided",
    );
  }

  const key = await getEncryptionKey();
  const payload = Buffer.from(encrypted, "base64");

  const iv = payload.subarray(0, 16);
  const encryptedText = payload.subarray(16);

  const decipher = crypto.createDecipheriv("aes-256-cbc", key, iv);
  let decrypted = decipher.update(encryptedText, undefined, "utf8");
  decrypted += decipher.final("utf8");

  return {decrypted};
});