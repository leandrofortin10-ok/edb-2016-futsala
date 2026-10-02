import 'package:cloud_firestore/cloud_firestore.dart';

/// Previa del próximo partido, generada con IA por GitHub Actions
/// (.github/scripts/generate_previews.js).
class MatchPreview {
  final String text;
  final String? mapsUrl;
  final DateTime? generatedAt;

  const MatchPreview({required this.text, this.mapsUrl, this.generatedAt});

  factory MatchPreview.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MatchPreview(
      text: data['text'] as String? ?? '',
      mapsUrl: data['mapsUrl'] as String?,
      generatedAt: (data['generatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
