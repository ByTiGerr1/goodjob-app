const functions = require("firebase-functions");
const {SecretManagerServiceClient} = require("@google-cloud/secret-manager");
const crypto = require("crypto");

// Cliente de Secret Manager
const client = new SecretManagerServiceClient();

// Reemplazar YOUR_PROJECT_ID por el ID de tu proyecto Firebase
const PROJECT_ID = "good-job-1";
const SECRET_NAME = "ENCRYPTION_KEY";

async function getEncryptionKey() {
  const [version] = await client.accessSecretVersion({
    name: `projects/${PROJECT_ID}/secrets/${SECRET_NAME}/versions/latest`,
  });
  const payload = version.payload.data.toString("utf8");
  return Buffer.from(payload, "base64");
}

exports.encryptData = functions.https.onCall(async (data, context) => {
  if (!data?.text) {
    throw new functions.https.HttpsError('invalid-argument', 'No text provided');
  }

  const key = await getEncryptionKey();
  const text = data.text;

  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv("aes-256-cbc", key, iv);

  let encrypted = cipher.update(text, "utf8", "base64");
  encrypted += cipher.final("base64");

  const payload = Buffer.concat([iv, Buffer.from(encrypted, "base64")]).toString("base64");
  return { encrypted: payload };
});

exports.decryptData = functions.https.onCall(async (data, context) => {
  if (!data?.encrypted) {
    throw new functions.https.HttpsError('invalid-argument', 'No encrypted data provided');
  }

  const key = await getEncryptionKey();
  const payload = Buffer.from(data.encrypted, "base64");

  const iv = payload.subarray(0, 16);
  const encryptedText = payload.subarray(16);

  const decipher = crypto.createDecipheriv("aes-256-cbc", key, iv);
  let decrypted = decipher.update(encryptedText, undefined, "utf8");
  decrypted += decipher.final("utf8");

  return { decrypted };
});