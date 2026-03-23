import 'package:cloud_firestore/cloud_firestore.dart';

enum MediaType { image, video }

class MatchMedia {
  final String id;
  final String matchId;
  final String url;
  final MediaType type;
  final DateTime uploadedAt;

  const MatchMedia({
    required this.id,
    required this.matchId,
    required this.url,
    required this.type,
    required this.uploadedAt,
  });

  factory MatchMedia.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MatchMedia(
      id: doc.id,
      matchId: data['matchId'] as String,
      url: data['url'] as String,
      type: (data['type'] as String) == 'video' ? MediaType.video : MediaType.image,
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'matchId': matchId,
    'url': url,
    'type': type == MediaType.video ? 'video' : 'image',
    'uploadedAt': Timestamp.fromDate(uploadedAt),
  };
}
