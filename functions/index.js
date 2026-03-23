const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const crypto = require("crypto");

const cloudinaryApiSecret = defineSecret("CLOUDINARY_API_SECRET");

/**
 * Genera la firma para un Cloudinary signed upload.
 * Solo accesible para usuarios con custom claim admin=true.
 */
exports.getCloudinarySignature = onCall(
  { secrets: [cloudinaryApiSecret] },
  async (request) => {
    // Verificar autenticacion
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Se requiere autenticacion");
    }

    // Verificar custom claim admin
    if (!request.auth.token.admin) {
      throw new HttpsError("permission-denied", "Solo admins pueden subir media");
    }

    // Validar parametros
    const { folder } = request.data;
    if (!folder || typeof folder !== "string" || !/^matches\/\d+$/.test(folder)) {
      throw new HttpsError("invalid-argument", "folder invalido. Formato esperado: matches/{matchId}");
    }

    // Generar firma: SHA1(sorted_params + api_secret) — spec de Cloudinary
    const timestamp = Math.round(Date.now() / 1000);
    const apiSecret = cloudinaryApiSecret.value();
    const paramsToSign = `folder=${folder}&timestamp=${timestamp}`;
    const signature = crypto
      .createHash("sha1")
      .update(paramsToSign + apiSecret)
      .digest("hex");

    return { timestamp, signature };
  }
);
