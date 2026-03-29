/**
 * Inserta una referencia de media en Firestore (colección match_media).
 * Uso: node add_match_media.js
 */

const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function addMedia() {
  const doc = {
    matchId: "42129",
    url: "https://res.cloudinary.com/dappsgujf/video/upload/v1774825027/matches/42129/hne1fxijiahazkg8ypmy.mp4",
    type: "video",
    uploadedAt: admin.firestore.Timestamp.now(),
  };

  const ref = await db.collection("match_media").add(doc);
  console.log(`✅ Documento creado: ${ref.id}`);
  console.log(doc);
  process.exit(0);
}

addMedia().catch((err) => {
  console.error("❌ Error:", err.message);
  process.exit(1);
});
