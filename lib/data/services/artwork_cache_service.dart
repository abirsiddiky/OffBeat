import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

/// Top-level function executed in an isolate/compute() to re-encode PNG bytes
/// into a baseline JPEG with quality 85, guarding against flat-color palette extraction bugs.
Uint8List? processPngToBaselineJpeg(Uint8List pngBytes) {
  try {
    final img.Image? decoded = img.decodePng(pngBytes);
    if (decoded == null || decoded.width < 16 || decoded.height < 16) {
      return null;
    }

    // Check if the image is a single flat color (all sampled pixels identical)
    final firstPixel = decoded.getPixel(0, 0);
    final num r0 = firstPixel.r;
    final num g0 = firstPixel.g;
    final num b0 = firstPixel.b;

    bool isUniform = true;

    // Fast stride check across the 512x512 image
    for (int y = 0; y < decoded.height; y += 4) {
      for (int x = 0; x < decoded.width; x += 4) {
        final p = decoded.getPixel(x, y);
        if (p.r != r0 || p.g != g0 || p.b != b0) {
          isUniform = false;
          break;
        }
      }
      if (!isUniform) break;
    }

    // Verify exhaustively if stride check found uniformity
    if (isUniform) {
      for (int y = 0; y < decoded.height; y++) {
        for (int x = 0; x < decoded.width; x++) {
          final p = decoded.getPixel(x, y);
          if (p.r != r0 || p.g != g0 || p.b != b0) {
            isUniform = false;
            break;
          }
        }
        if (!isUniform) break;
      }
    }

    // If completely uniform, alter a single pixel in a corner by a subtle offset
    // so SystemUI palette extraction doesn't fail on a single flat color
    if (isUniform) {
      final num newR = (r0 < 128) ? (r0 + 32).clamp(0, 255) : (r0 - 32).clamp(0, 255);
      final num newG = (g0 < 128) ? (g0 + 32).clamp(0, 255) : (g0 - 32).clamp(0, 255);
      final num newB = (b0 < 128) ? (b0 + 32).clamp(0, 255) : (b0 - 32).clamp(0, 255);
      decoded.setPixelRgb(0, 0, newR, newG, newB);
    }

    // Re-encode as standard baseline JPEG (RGB, quality 85, no EXIF, no progressive)
    final jpgBytes = img.encodeJpg(decoded, quality: 85);
    return Uint8List.fromList(jpgBytes);
  } catch (e) {
    debugPrint('[ArtworkCacheService] Isolate JPEG encoding failed: $e');
    return null;
  }
}

/// Service responsible for extracting and strictly normalizing artwork into 512x512
/// baseline JPEGs in the app cache directory (`<songId>.jpg`), safe for Android 11 SystemUI.
class ArtworkCacheService {
  static ArtworkCacheService? _instance;
  static ArtworkCacheService get instance =>
      _instance ??= ArtworkCacheService._();

  ArtworkCacheService._();

  final OnAudioQuery _audioQuery = OnAudioQuery();
  Directory? _cacheDir;
  bool _initialized = false;

  /// Initialize the cache directory asynchronously.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final tempDir = await getTemporaryDirectory();
      _cacheDir = Directory('${tempDir.path}/offbeat_art');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[ArtworkCacheService] initialization error: $e');
    }
  }

  /// Synchronously returns cached JPEG file:// Uri if already on disk and valid (> 500 bytes).
  /// Returns null if not cached or invalid. Never returns placeholder or asset URIs.
  Uri? getCachedArtUri(int songId) {
    if (_cacheDir == null) return null;
    final file = File('${_cacheDir!.path}/$songId.jpg');
    try {
      if (file.existsSync() && file.lengthSync() >= 500) {
        return Uri.file(file.path);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Fetches raw artwork, normalizes it to a safe 512x512 baseline JPEG without alpha,
  /// caches it at `<songId>.jpg`, and returns its file:// Uri.
  /// If ANY step fails or returns "no artwork", returns null.
  Future<Uri?> getOrFetchArtworkUri(int songId) async {
    if (!_initialized) {
      await initialize();
    }
    if (_cacheDir == null) return null;

    final file = File('${_cacheDir!.path}/$songId.jpg');
    try {
      if (await file.exists() && (await file.length()) >= 500) {
        return Uri.file(file.path);
      }
    } catch (_) {}

    try {
      // 1. Get raw bytes (embedded art / MediaStore artwork)
      final rawBytes = await _audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 1000,
        quality: 100,
      );

      // If bytes are null, empty, or smaller than ~500 bytes -> no artwork
      if (rawBytes == null || rawBytes.length < 500) {
        return null;
      }

      // 2. Decode with dart:ui instantiateImageCodec(bytes, targetWidth: 512, targetHeight: 512)
      final ui.Codec codec;
      try {
        codec = await ui.instantiateImageCodec(
          rawBytes,
          targetWidth: 512,
          targetHeight: 512,
        );
      } catch (e) {
        debugPrint('[ArtworkCacheService] instantiateImageCodec failed for $songId: $e');
        return null;
      }

      final ui.FrameInfo frameInfo;
      try {
        frameInfo = await codec.getNextFrame();
      } catch (e) {
        return null;
      }

      final ui.Image decodedImage = frameInfo.image;
      if (decodedImage.width < 16 || decodedImage.height < 16) {
        decodedImage.dispose();
        return null;
      }

      final double srcW = decodedImage.width.toDouble();
      final double srcH = decodedImage.height.toDouble();

      // Center-crop onto SQUARE 512x512
      final double cropSide = srcW < srcH ? srcW : srcH;
      final double srcX = (srcW - cropSide) / 2.0;
      final double srcY = (srcH - cropSide) / 2.0;

      final srcRect = ui.Rect.fromLTWH(srcX, srcY, cropSide, cropSide);
      const dstRect = ui.Rect.fromLTWH(0, 0, 512, 512);

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, dstRect);

      // Fill with #171C26 first so there is no alpha channel and no transparent pixels
      final bgPaint = ui.Paint()
        ..color = const ui.Color(0xFF171C26)
        ..style = ui.PaintingStyle.fill;
      canvas.drawRect(dstRect, bgPaint);

      final imagePaint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
      canvas.drawImageRect(decodedImage, srcRect, dstRect, imagePaint);

      final picture = recorder.endRecording();
      final squareImage = await picture.toImage(512, 512);

      decodedImage.dispose();
      picture.dispose();

      // Export with toByteData(format: png)
      final byteData = await squareImage.toByteData(format: ui.ImageByteFormat.png);
      squareImage.dispose();

      if (byteData == null) return null;
      final pngBytes = byteData.buffer.asUint8List();

      // Re-encode as JPEG quality 85 using the image package in compute()
      final jpegBytes = await compute(processPngToBaselineJpeg, pngBytes);
      if (jpegBytes == null || jpegBytes.length < 500) {
        return null;
      }

      // Save to the app cache dir as <songId>.jpg
      await file.writeAsBytes(jpegBytes, flush: true);

      if (await file.exists() && (await file.length()) >= 500) {
        return Uri.file(file.path);
      }
    } catch (e) {
      debugPrint('[ArtworkCacheService] getOrFetchArtworkUri error for $songId: $e');
    }

    return null;
  }
}
