import 'dart:async';
import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import '../audio_query_gate.dart';

const bool kNoArtworkMode = false;

class ArtworkService {
  ArtworkService._();

  static final OnAudioQuery _audioQuery = OnAudioQuery();
  static Directory? _cacheDir;

  /// In-memory cache keyed by songId / albumId.
  static final Map<String, Uint8List> _thumbMemoryCache = {};

  /// In-flight de-duplication map keyed by numeric ID (songId/albumId).
  static final Map<int, Future<Uint8List?>> _inFlightArtwork = {};

  static Future<Directory> get _getCacheDir async {
    _cacheDir ??= await getTemporaryDirectory();
    return _cacheDir!;
  }

  static String computeThumbKey({
    int id = 0,
    String? songId,
    int? albumId,
    ArtworkType type = ArtworkType.AUDIO,
  }) {
    if (songId != null && songId.isNotEmpty) {
      return 'song_$songId';
    }
    if (type == ArtworkType.AUDIO && id > 0) {
      return 'song_$id';
    }
    if (albumId != null && albumId > 0) {
      return 'album_$albumId';
    }
    if (type == ArtworkType.ALBUM && id > 0) {
      return 'album_$id';
    }
    return 'thumb_${type.name}_$id';
  }

  /// TIER 1: THUMB (lists, mini player, album cards, recently played)
  /// ~200x200 via on_audio_query artwork / embedded tags, decoded with cacheWidth.
  static Widget getThumbWidget({
    int id = 0,
    String? songId,
    int? albumId,
    String? filePath,
    ArtworkType type = ArtworkType.AUDIO,
    double size = 48,
    double radius = 14,
    Widget? placeholder,
  }) {
    return _SharedThumbWidget(
      id: id,
      songId: songId,
      albumId: albumId,
      filePath: filePath,
      type: type,
      size: size,
      radius: radius,
      placeholder: placeholder,
    );
  }

  /// Resolves thumbnail bytes with in-memory + disk cache and in-flight deduplication.
  static Future<Uint8List?> resolveThumbBytes({
    required int id,
    String? songId,
    int? albumId,
    String? filePath,
    ArtworkType type = ArtworkType.AUDIO,
  }) async {
    final key = computeThumbKey(id: id, songId: songId, albumId: albumId, type: type);

    // 1. In-memory cache hit
    if (_thumbMemoryCache.containsKey(key)) {
      return _thumbMemoryCache[key];
    }

    // Determine numeric ID for in-flight deduplication
    final numericId = int.tryParse(songId ?? '') ?? (id > 0 ? id : (albumId ?? 0));

    // 2. In-flight request deduplication
    if (numericId > 0 && _inFlightArtwork.containsKey(numericId)) {
      return _inFlightArtwork[numericId];
    }

    final future = _loadThumbBytes(
      key: key,
      numericId: numericId,
      id: id,
      songId: songId,
      albumId: albumId,
      filePath: filePath,
      type: type,
    );

    if (numericId > 0) {
      _inFlightArtwork[numericId] = future;
    }

    try {
      final res = await future;
      return res;
    } finally {
      if (numericId > 0) {
        _inFlightArtwork.remove(numericId);
      }
    }
  }

  static Future<Uint8List?> _loadThumbBytes({
    required String key,
    required int numericId,
    required int id,
    String? songId,
    int? albumId,
    String? filePath,
    required ArtworkType type,
  }) async {
    try {
      // 1. Disk cache lookup
      final cache = await _getCacheDir;
      final cachedFile = File('${cache.path}/thumb_$key.jpg');
      if (await cachedFile.exists() && (await cachedFile.length()) > 100) {
        final diskBytes = await cachedFile.readAsBytes();
        _thumbMemoryCache[key] = diskBytes;
        return diskBytes;
      }

      Uint8List? rawBytes;

      // 2. Query artwork via AudioQueryGate
      if (type == ArtworkType.AUDIO || (songId != null && songId.isNotEmpty)) {
        final querySongId = int.tryParse(songId ?? '') ?? (type == ArtworkType.AUDIO ? id : 0);
        if (querySongId > 0) {
          try {
            rawBytes = await AudioQueryGate.run(() async {
              return await _audioQuery.queryArtwork(
                querySongId,
                ArtworkType.AUDIO,
                size: 200,
                format: ArtworkFormat.JPEG,
                quality: 90,
              );
            });
          } catch (e) {
            debugPrint('[ArtworkService] Safe queryArtwork failure for song $querySongId: $e');
          }
        }

        // Fallback to albumId
        if ((rawBytes == null || rawBytes.isEmpty) && albumId != null && albumId > 0) {
          try {
            rawBytes = await AudioQueryGate.run(() async {
              return await _audioQuery.queryArtwork(
                albumId,
                ArtworkType.ALBUM,
                size: 200,
                format: ArtworkFormat.JPEG,
                quality: 90,
              );
            });
          } catch (e) {
            debugPrint('[ArtworkService] Safe queryArtwork failure for album $albumId: $e');
          }
        }

        // Fallback to embedded cover read from audio file (audio_metadata_reader)
        if ((rawBytes == null || rawBytes.isEmpty) &&
            filePath != null &&
            filePath.isNotEmpty &&
            !filePath.startsWith('asset://')) {
          final file = File(filePath);
          if (file.existsSync()) {
            try {
              final metadata = readMetadata(file, getImage: true);
              if (metadata.pictures.isNotEmpty) {
                final picBytes = metadata.pictures.first.bytes;
                if (picBytes.isNotEmpty) {
                  rawBytes = picBytes;
                }
              }
            } catch (e) {
              debugPrint('[ArtworkService] Embedded metadata reader for thumb failed ($filePath): $e');
            }
          }
        }
      } else if (type == ArtworkType.ALBUM) {
        final queryAlbumId = albumId ?? id;
        if (queryAlbumId > 0) {
          try {
            rawBytes = await AudioQueryGate.run(() async {
              return await _audioQuery.queryArtwork(
                queryAlbumId,
                ArtworkType.ALBUM,
                size: 200,
                format: ArtworkFormat.JPEG,
                quality: 90,
              );
            });
          } catch (e) {
            debugPrint('[ArtworkService] Safe queryArtwork failure for album $queryAlbumId: $e');
          }
        }
      }

      if (rawBytes != null && rawBytes.length >= 32) {
        _thumbMemoryCache[key] = rawBytes;
        // Asynchronously persist to disk cache
        cachedFile.writeAsBytes(rawBytes, flush: true).ignore();
        return rawBytes;
      }

      return null;
    } catch (e) {
      debugPrint('[ArtworkService] Error loading thumbnail ($key): $e');
      return null;
    }
  }

  static Widget _buildDefaultPlaceholder(double size, double radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF222836),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: size * 0.5,
          color: const Color(0xFF6C7689),
        ),
      ),
    );
  }

  /// TIER 2: LARGE (Now Playing ONLY — fixes blurry art)
  /// (a) read embedded picture bytes straight from the audio file with audio_metadata_reader
  /// (b) else queryArtwork from on_audio_query with size 1024, JPEG, quality 100 via AudioQueryGate
  /// (c) else null (placeholder).
  /// Downscale to max 1024 px (center-crop square), cache as `art_large_<songId>.jpg`.
  static Future<File?> getLargeArtworkFile({
    required String songId,
    required String? filePath,
    int? albumId,
  }) async {
    try {
      final cache = await _getCacheDir;
      final cachedFile = File('${cache.path}/art_large_$songId.jpg');
      if (await cachedFile.exists() && (await cachedFile.length()) > 500) {
        return cachedFile;
      }

      Uint8List? rawBytes;

      // (a) Read embedded metadata from audio file
      if (filePath != null && filePath.isNotEmpty && !filePath.startsWith('asset://')) {
        final file = File(filePath);
        if (await file.exists()) {
          try {
            final metadata = readMetadata(file, getImage: true);
            if (metadata.pictures.isNotEmpty) {
              rawBytes = metadata.pictures.first.bytes;
            }
          } catch (e) {
            debugPrint('[ArtworkService] Embedded metadata reader failed for $filePath: $e');
          }
        }
      }

      // (b) Fallback to on_audio_query 1024 JPEG via AudioQueryGate
      if (rawBytes == null || rawBytes.isEmpty) {
        final intId = int.tryParse(songId);
        if (intId != null && intId > 0) {
          try {
            rawBytes = await AudioQueryGate.run(() async {
              return await _audioQuery.queryArtwork(
                intId,
                ArtworkType.AUDIO,
                size: 1024,
                format: ArtworkFormat.JPEG,
                quality: 100,
              );
            });
          } catch (e) {
            debugPrint('[ArtworkService] Safe large queryArtwork failed for song $songId: $e');
          }
        }

        if ((rawBytes == null || rawBytes.isEmpty) && albumId != null && albumId > 0) {
          try {
            rawBytes = await AudioQueryGate.run(() async {
              return await _audioQuery.queryArtwork(
                albumId,
                ArtworkType.ALBUM,
                size: 1024,
                format: ArtworkFormat.JPEG,
                quality: 100,
              );
            });
          } catch (e) {
            debugPrint('[ArtworkService] Safe large queryArtwork failed for album $albumId: $e');
          }
        }
      }

      if (rawBytes == null || rawBytes.length < 32) {
        return null;
      }

      // Process in isolate
      final processedBytes = await compute(_processLargeArtworkIsolate, rawBytes);
      if (processedBytes == null || processedBytes.isEmpty) {
        return null;
      }

      await cachedFile.writeAsBytes(processedBytes, flush: true);
      return cachedFile;
    } catch (e) {
      debugPrint('[ArtworkService] getLargeArtworkFile error: $e');
      return null;
    }
  }

  /// TIER 3: NOTIFICATION (MediaItem.artUri)
  /// separate file `art_notif_<songId>.jpg`: decode with a target size (never full size),
  /// center-crop to SQUARE 512x512, draw on an OPAQUE #171C26 background (no alpha),
  /// encode as baseline RGB JPEG quality 85 (<150 KB, no EXIF/progressive).
  static Future<Uri?> getNotificationArtworkUri({
    required String songId,
    required String? filePath,
    int? albumId,
  }) async {
    if (kNoArtworkMode) return null;

    try {
      final cache = await _getCacheDir;
      final cachedFile = File('${cache.path}/art_notif_$songId.jpg');
      if (await cachedFile.exists()) {
        final len = await cachedFile.length();
        if (len > 500 && len < 150 * 1024) {
          return Uri.file(cachedFile.path);
        }
      }

      return await Future<Uri?>.microtask(() async {
        Uint8List? rawBytes;

        // Try reading embedded art first
        if (filePath != null && filePath.isNotEmpty && !filePath.startsWith('asset://')) {
          final file = File(filePath);
          if (await file.exists()) {
            try {
              final metadata = readMetadata(file, getImage: true);
              if (metadata.pictures.isNotEmpty) {
                rawBytes = metadata.pictures.first.bytes;
              }
            } catch (e) {
              debugPrint('[ArtworkService] Embedded metadata reader for notif failed: $e');
            }
          }
        }

        // Fallback to on_audio_query via AudioQueryGate
        if (rawBytes == null || rawBytes.isEmpty) {
          final intId = int.tryParse(songId);
          if (intId != null && intId > 0) {
            try {
              rawBytes = await AudioQueryGate.run(() async {
                return await _audioQuery.queryArtwork(
                  intId,
                  ArtworkType.AUDIO,
                  size: 512,
                  format: ArtworkFormat.JPEG,
                  quality: 90,
                );
              });
            } catch (e) {
              debugPrint('[ArtworkService] Safe notif queryArtwork failed for song $songId: $e');
            }
          }

          if ((rawBytes == null || rawBytes.isEmpty) && albumId != null && albumId > 0) {
            try {
              rawBytes = await AudioQueryGate.run(() async {
                return await _audioQuery.queryArtwork(
                  albumId,
                  ArtworkType.ALBUM,
                  size: 512,
                  format: ArtworkFormat.JPEG,
                  quality: 90,
                );
              });
            } catch (e) {
              debugPrint('[ArtworkService] Safe notif queryArtwork failed for album $albumId: $e');
            }
          }
        }

        if (rawBytes == null || rawBytes.length < 32) {
          return null;
        }

        // Process in isolate
        final processedBytes = await compute(_processNotificationArtworkIsolate, rawBytes);
        if (processedBytes == null || processedBytes.isEmpty) {
          return null;
        }

        await cachedFile.writeAsBytes(processedBytes, flush: true);
        return Uri.file(cachedFile.path);
      }).timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () {
          debugPrint('[ArtworkService] Notification artwork timed out for $songId');
          return null;
        },
      );
    } catch (e) {
      debugPrint('[ArtworkService] Notification artwork error for $songId: $e');
      return null;
    }
  }
}

class _SharedThumbWidget extends StatefulWidget {
  final int id;
  final String? songId;
  final int? albumId;
  final String? filePath;
  final ArtworkType type;
  final double size;
  final double radius;
  final Widget? placeholder;

  const _SharedThumbWidget({
    required this.id,
    this.songId,
    this.albumId,
    this.filePath,
    required this.type,
    required this.size,
    required this.radius,
    this.placeholder,
  });

  @override
  State<_SharedThumbWidget> createState() => _SharedThumbWidgetState();
}

class _SharedThumbWidgetState extends State<_SharedThumbWidget> {
  Uint8List? _bytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_SharedThumbWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.songId != widget.songId ||
        oldWidget.albumId != widget.albumId ||
        oldWidget.filePath != widget.filePath ||
        oldWidget.type != widget.type) {
      _load();
    }
  }

  void _load() {
    final key = ArtworkService.computeThumbKey(
      id: widget.id,
      songId: widget.songId,
      albumId: widget.albumId,
      type: widget.type,
    );
    if (ArtworkService._thumbMemoryCache.containsKey(key)) {
      _bytes = ArtworkService._thumbMemoryCache[key];
      _isLoading = false;
      return;
    }

    _isLoading = true;
    ArtworkService.resolveThumbBytes(
      id: widget.id,
      songId: widget.songId,
      albumId: widget.albumId,
      filePath: widget.filePath,
      type: widget.type,
    ).then((bytes) {
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    final targetCacheWidth = (widget.size * dpr).toInt().clamp(100, 400);
    final fallbackWidget = widget.placeholder ??
        ArtworkService._buildDefaultPlaceholder(widget.size, widget.radius);

    // If bytes are already in memory, display immediately without cross-fade to prevent flicker
    if (_bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: Image.memory(
          _bytes!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          cacheWidth: targetCacheWidth,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        ),
      );
    }

    if (!_isLoading && _bytes == null) {
      return fallbackWidget;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _bytes != null ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: fallbackWidget,
          secondChild: _bytes != null
              ? Image.memory(
                  _bytes!,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                  cacheWidth: targetCacheWidth,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Isolate worker for Large artwork: downscale to max 1024 px center crop
Uint8List? _processLargeArtworkIsolate(Uint8List rawBytes) {
  try {
    final image = img.decodeImage(rawBytes);
    if (image == null || image.width < 16 || image.height < 16) {
      return null;
    }

    // Square crop then resize to max 1024
    final shortest = image.width < image.height ? image.width : image.height;
    final x = (image.width - shortest) ~/ 2;
    final y = (image.height - shortest) ~/ 2;
    var cropped = img.copyCrop(image, x: x, y: y, width: shortest, height: shortest);

    if (cropped.width > 1024) {
      cropped = img.copyResize(cropped, width: 1024, height: 1024, interpolation: img.Interpolation.linear);
    }

    return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
  } catch (e) {
    debugPrint('[ArtworkService Isolate] Large artwork processing failed: $e');
    return null;
  }
}

/// Isolate worker for Notification artwork:
/// SQUARE 512x512, draw on OPAQUE #171C26 background (no alpha), baseline RGB JPEG quality 85 (<150 KB)
Uint8List? _processNotificationArtworkIsolate(Uint8List rawBytes) {
  try {
    final image = img.decodeImage(rawBytes);
    if (image == null || image.width < 16 || image.height < 16) {
      return null;
    }

    // Center-crop to square
    final shortest = image.width < image.height ? image.width : image.height;
    final x = (image.width - shortest) ~/ 2;
    final y = (image.height - shortest) ~/ 2;
    final cropped = img.copyCrop(image, x: x, y: y, width: shortest, height: shortest);

    // Resize to 512x512
    final resized = img.copyResize(cropped, width: 512, height: 512, interpolation: img.Interpolation.linear);

    // Create 512x512 opaque canvas #171C26 to guarantee NO alpha channel
    final canvas = img.Image(width: 512, height: 512, numChannels: 3);
    final bgNavy = img.ColorRgb8(0x17, 0x1C, 0x26);
    img.fill(canvas, color: bgNavy);

    // Draw resized artwork on opaque background
    img.compositeImage(canvas, resized, dstX: 0, dstY: 0);

    // Encode as baseline JPEG quality 85
    var encoded = Uint8List.fromList(img.encodeJpg(canvas, quality: 85));

    // Ensure under 150 KB
    if (encoded.length > 140 * 1024) {
      encoded = Uint8List.fromList(img.encodeJpg(canvas, quality: 70));
    }

    return encoded;
  } catch (e) {
    debugPrint('[ArtworkService Isolate] Notification artwork processing failed: $e');
    return null;
  }
}
