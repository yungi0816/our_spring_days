import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'album_provider.dart';
import '../providers/route_models.dart';
import '../services/firebase_service.dart';

// SharedPreferences Provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// FirebaseService Provider
final firebaseServiceProvider = Provider((ref) => FirebaseService());

// Album stream Provider
final albumStreamProvider = StreamProvider<List<AlbumEntry>>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.getAlbumStream();
});

// Album comments Provider
final albumCommentsProvider = StreamProvider.family<List<AlbumComment>, String>(
  (ref, albumId) {
    final firebaseService = ref.watch(firebaseServiceProvider);
    return firebaseService.getAlbumCommentStream(albumId);
  },
);
