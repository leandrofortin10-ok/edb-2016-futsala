import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../models/match_media.dart';

const _cloudName = 'dappsgujf';
const _uploadPreset = 'edb_admin_upload';

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
    XFile file,
    MediaType type, {
    void Function(double)? onProgress,
  }) async {
    final folder = 'matches/$matchId';
    final resourceType = type == MediaType.video ? 'video' : 'image';

    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload');

    final bytes = await file.readAsBytes();
    final filename = file.name.isNotEmpty ? file.name : 'upload';

    onProgress?.call(0.1);

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = folder
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

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
  }
}
