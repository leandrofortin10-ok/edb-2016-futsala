import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/match_media.dart';

const _cloudName   = 'dappsgujf';
const _uploadPreset = 'edb2016';

class MediaService {
  static final _db = FirebaseFirestore.instance;

  static Stream<List<MatchMedia>> watchMatchMedia(String matchId) {
    return _db
        .collection('match_media')
        .where('matchId', isEqualTo: matchId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => MatchMedia.fromFirestore(
                d as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
  }

  static Future<void> uploadMedia(
    String matchId,
    File file,
    MediaType type, {
    void Function(double)? onProgress,
  }) async {
    final resourceType = type == MediaType.video ? 'video' : 'image';
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = 'matches/$matchId'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    // Progreso aproximado: no disponible en http.MultipartRequest,
    // simulamos 50% al iniciar y 100% al terminar
    onProgress?.call(0.1);
    final streamed = await request.send();
    onProgress?.call(0.9);

    if (streamed.statusCode != 200) {
      final body = await streamed.stream.bytesToString();
      throw Exception('Error Cloudinary: $body');
    }

    final body = await streamed.stream.bytesToString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final url = json['secure_url'] as String;

    await _db.collection('match_media').add({
      'matchId': matchId,
      'url': url,
      'type': type == MediaType.video ? 'video' : 'image',
      'uploadedAt': Timestamp.now(),
    });

    onProgress?.call(1.0);
  }

  static Future<void> deleteMedia(MatchMedia media) async {
    await _db.collection('match_media').doc(media.id).delete();
    // La URL de Cloudinary queda huérfana (borrado requiere firma del servidor)
    // Para un equipo chico esto es aceptable
  }
}
