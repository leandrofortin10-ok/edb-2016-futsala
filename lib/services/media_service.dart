import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/match_media.dart';

const _cloudName = 'dappsgujf';
// api_key de Cloudinary (público — no es el api_secret).
// Se obtiene en: Cloudinary Dashboard > API Keys
const _cloudinaryApiKey = '442291124228712';

class MediaService {
  static final _db = FirebaseFirestore.instance;
  static final _functions = FirebaseFunctions.instance;

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
    final folder = 'matches/$matchId';
    final resourceType = type == MediaType.video ? 'video' : 'image';

    // 1. Obtener firma desde la Cloud Function (el api_secret nunca toca el cliente)
    onProgress?.call(0.05);
    final callable = _functions.httpsCallable('getCloudinarySignature');
    final result = await callable.call<Map<String, dynamic>>({'folder': folder});
    final timestamp = result.data['timestamp'] as int;
    final signature = result.data['signature'] as String;

    // 2. Upload firmado a Cloudinary (sin upload_preset)
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = _cloudinaryApiKey
      ..fields['timestamp'] = timestamp.toString()
      ..fields['signature'] = signature
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

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

    // 3. Guardar referencia en Firestore
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
  }
}
