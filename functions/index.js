const { onCall, HttpsError } = require("firebase-functions/v1/https");
const crypto = require("crypto");

/**
 * Genera la firma para un Cloudinary signed upload.
 * Solo accesible para usuarios con custom claim admin=true.
 */
exports.getCloudinarySignature = onCall(async (data, context) => {
  // Verificar autenticacion
  if (!context.auth) {
    throw new HttpsError("unauthenticated", "Se requiere autenticacion");
  }

  // Verificar custom claim admin
  if (!context.auth.token.admin) {
    throw new HttpsError("permission-denied", "Solo admins pueden subir media");
  }

  // Validar parametros
  const { folder } = data;
  if (!folder || typeof folder !== "string" || !/^matches\/\d+$/.test(folder)) {
    throw new HttpsError("invalid-argument", "folder invalido. Formato esperado: matches/{matchId}");
  }

  const apiSecret = process.env.CLOUDINARY_API_SECRET;
  if (!apiSecret) {
    throw new HttpsError("internal", "API secret no configurado");
  }

  // Generar firma: SHA1(sorted_params + api_secret) — spec de Cloudinary
  const timestamp = Math.round(Date.now() / 1000);
  const paramsToSign = `folder=${folder}&timestamp=${timestamp}`;
  const signature = crypto
    .createHash("sha1")
    .update(paramsToSign + apiSecret)
    .digest("hex");

  return { timestamp: String(timestamp), signature };
});
