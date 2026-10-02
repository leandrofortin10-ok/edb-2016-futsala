import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'ai_config.dart';

/// Asistente de preguntas con Gemini (Firebase AI Logic). Responde con los
/// datos que la app ya cargó y con el reglamento del torneo.
class AssistantService {
  static String? _rules;

  static Future<String> _loadRules() async =>
      _rules ??= await rootBundle.loadString('assets/reglamento/reglamento_2026.txt');

  /// Nueva conversación. [dataContext] sale de buildAssistantContext().
  static Future<ChatSession> startChat(String dataContext) async {
    final rules = await _loadRules();
    final model = FirebaseAI.googleAI().generativeModel(
      model: kAssistantModel,
      systemInstruction: Content.system(_instructions(dataContext, rules)),
      generationConfig: GenerationConfig(temperature: 0.2, maxOutputTokens: 1024),
    );
    return model.startChat();
  }

  /// Mensaje para mostrar al usuario según el error.
  static String errorMessage(Object error) {
    if (error is QuotaExceeded) {
      return 'El asistente recibió muchas consultas. Probá de nuevo en unos minutos.';
    }
    return 'No pude responder en este momento. Probá de nuevo en un rato.';
  }

  static String _instructions(String data, String rules) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final today = '${now.year}-${two(now.month)}-${two(now.day)}';
    return '''
Sos el asistente de la app de Estrella de Boedo, un club que juega el Torneo Joma de Futsala BA
con sus equipos infantiles (Torneo Promocionales, zona Elite B). Respondés preguntas de las
familias sobre partidos, resultados, tabla, plantel, goleadores y el reglamento.

Reglas:
- Hoy es $today. Las fechas de los datos vienen como AAAA-MM-DD: respondelas en formato natural
  (por ejemplo, "domingo 4/10 a las 10:00").
- Respondé en español rioplatense, claro y breve (2 a 5 oraciones, salvo que pidan detalle).
- Usá solo los DATOS DE LA APP y el REGLAMENTO de abajo. Si la respuesta no está ahí, decí que no
  tenés ese dato. No inventes nada.
- Sobre el reglamento: aplicá lo que corresponde al Torneo Promocionales (zona Elite B) y a la
  categoría de los datos, y mencioná el punto (por ejemplo, "según el punto 9.1.2"). Si el
  reglamento no lo cubre, decilo.
- Son chicos: tono cálido y respetuoso. No compares ni critiques a jugadores ni remarques goleadas.
- Si te preguntan algo que no tiene que ver con el equipo, el torneo o el reglamento, decí
  amablemente que solo podés ayudar con eso.
- Texto plano, sin markdown. Para enumerar, usá líneas que empiecen con guion.

=== DATOS DE LA APP ===
$data
=== REGLAMENTO ===
$rules''';
  }
}
