/// Clave de Fraud Defense (reCAPTCHA Enterprise, plan gratuito) para Firebase
/// App Check. Es pública; se administra en Google Cloud → Fraud Defense.
/// Vacía = App Check desactivado: la app funciona, pero el asistente no.
const kRecaptchaSiteKey = '6LejptstAAAAAIJ7I0v_09nqqftoOIiMDnaLHxh7';

/// Modelo del asistente (Firebase AI Logic con la Gemini Developer API,
/// tier gratuito). Flash-Lite: respuestas rápidas para un chat.
const kAssistantModel = 'gemini-3.5-flash-lite';

/// Máximo de preguntas por conversación (cuida el cupo gratuito).
const kAssistantMaxQuestions = 20;
