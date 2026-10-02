import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_preview.dart';

class PreviewService {
  static final _db = FirebaseFirestore.instance;

  /// Previa del partido para la categoría, o null si todavía no se generó.
  /// Es un stream: si la previa aparece o se actualiza con la app abierta,
  /// la tarjeta se refresca sola.
  static Stream<MatchPreview?> watchPreview(int matchId, int categoryId) {
    return _db
        .collection('ai_previews')
        .doc('${matchId}_$categoryId')
        .snapshots()
        .map((d) {
          if (!d.exists) return null;
          final preview = MatchPreview.fromFirestore(d);
          return preview.text.isEmpty ? null : preview;
        })
        // Sin permisos o sin conexión: no mostrar la tarjeta en lugar de romper.
        .handleError((_) {});
  }
}
