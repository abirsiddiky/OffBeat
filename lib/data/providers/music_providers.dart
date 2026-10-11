import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../local/database.dart';
import '../models/models.dart';
import '../repositories/music_repository.dart';
import '../services/music_scanner.dart';
import '../services/permission_service.dart';

/// Database provider (singleton).
final databaseProvider = Provider<OffBeatDatabase>((ref) {
  final db = OffBeatDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Scanner service provider.
final musicScannerProvider = Provider<MusicScanner>((ref) {
  return MusicScanner();
});

/// Permission service provider.
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return const PermissionService();
});

/// Audio permission state notifier.
class MusicPermissionNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final service = ref.watch(permissionServiceProvider);
    return service.hasPermission();
  }

  Future<bool> request() async {
    state = const AsyncValue.loading();
    final service = ref.read(permissionServiceProvider);
    final granted = await service.requestPermission();
    state = AsyncValue.data(granted);
    if (granted) {
      // Trigger media scan when permission is granted
      ref.read(allSongsProvider.notifier).rescan();
      ref.read(albumsProvider.notifier).rescan();
      ref.read(artistsProvider.notifier).rescan();
    }
    return granted;
  }
}

final musicPermissionProvider =
    AsyncNotifierProvider<MusicPermissionNotifier, bool>(
  MusicPermissionNotifier.new,
);

/// Central music repository provider.
final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  final scanner = ref.watch(musicScannerProvider);
  final db = ref.watch(databaseProvider);
  return MusicRepository(scanner: scanner, db: db);
});

// ==========================================
// Media Scanning Async Providers (with pull-to-refresh)
// ==========================================

/// AsyncNotifier managing scanned songs with pull-to-refresh rescan.
class AllSongsNotifier extends AsyncNotifier<List<Song>> {
  @override
  Future<List<Song>> build() async {
    final hasPermission = await ref.watch(musicPermissionProvider.future);
    if (!hasPermission) {
      return [];
    }
    final repository = ref.watch(musicRepositoryProvider);
    return repository.scanAllSongs();
  }

  /// Trigger a full rescan from disk / MediaStore.
  Future<void> rescan() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(musicRepositoryProvider);
      return repository.scanAllSongs(forceRefresh: true);
    });
  }
}

final allSongsProvider =
    AsyncNotifierProvider<AllSongsNotifier, List<Song>>(
  AllSongsNotifier.new,
);

/// AsyncNotifier managing scanned albums with pull-to-refresh rescan.
class AlbumsNotifier extends AsyncNotifier<List<Album>> {
  @override
  Future<List<Album>> build() async {
    final hasPermission = await ref.watch(musicPermissionProvider.future);
    if (!hasPermission) {
      return [];
    }
    final repository = ref.watch(musicRepositoryProvider);
    return repository.scanAllAlbums();
  }

  Future<void> rescan() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(musicRepositoryProvider);
      return repository.scanAllAlbums(forceRefresh: true);
    });
  }
}

final albumsProvider =
    AsyncNotifierProvider<AlbumsNotifier, List<Album>>(
  AlbumsNotifier.new,
);

/// AsyncNotifier managing scanned artists with pull-to-refresh rescan.
class ArtistsNotifier extends AsyncNotifier<List<Artist>> {
  @override
  Future<List<Artist>> build() async {
    final hasPermission = await ref.watch(musicPermissionProvider.future);
    if (!hasPermission) {
      return [];
    }
    final repository = ref.watch(musicRepositoryProvider);
    return repository.scanAllArtists();
  }

  Future<void> rescan() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(musicRepositoryProvider);
      return repository.scanAllArtists(forceRefresh: true);
    });
  }
}

final artistsProvider =
    AsyncNotifierProvider<ArtistsNotifier, List<Artist>>(
  ArtistsNotifier.new,
);

// ==========================================
// Drift + Scanner Combined Stream Providers
// ==========================================

/// Stream provider for Hotlist tracks (favorites), mapped to [Song] models.
final hotlistProvider = StreamProvider<List<Song>>((ref) {
  // Ensure songs are loaded so IDs map to full metadata
  ref.watch(allSongsProvider);
  final repository = ref.watch(musicRepositoryProvider);
  return repository.watchHotlist();
});

/// Stream provider for user playlists from Drift.
final playlistsProvider = StreamProvider<List<Playlist>>((ref) {
  final repository = ref.watch(musicRepositoryProvider);
  return repository.watchPlaylists();
});

/// Stream provider for recently played songs, capped at 50 tracks.
final recentlyPlayedProvider = StreamProvider<List<Song>>((ref) {
  ref.watch(allSongsProvider);
  final repository = ref.watch(musicRepositoryProvider);
  return repository.watchRecentlyPlayed();
});

/// Family stream provider for songs in a specific playlist.
final playlistSongsProvider =
    StreamProvider.family<List<Song>, int>((ref, playlistId) {
  ref.watch(allSongsProvider);
  final repository = ref.watch(musicRepositoryProvider);
  return repository.watchPlaylistSongs(playlistId);
});

/// Family stream provider for checking if a specific song is favorited.
final isFavoriteSongProvider =
    StreamProvider.family<bool, int>((ref, songId) {
  final repository = ref.watch(musicRepositoryProvider);
  return repository.watchIsFavorite(songId);
});
