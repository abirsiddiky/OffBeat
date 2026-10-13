package com.offbeat.offbeat

import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ContentUris
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val TAG = "OffBeatMedia"
        private const val CHANNEL_NAME = "offbeat/media"
        private const val REQUEST_CODE_DELETE_API_30 = 9001
        private const val REQUEST_CODE_DELETE_API_29 = 9002

        private val AUDIO_EXTENSIONS = setOf(
            "mp3", "m4a", "aac", "flac", "wav", "ogg", "opus", "wma", "amr", "mka", "3gp"
        )
    }

    private val bgExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var pendingDeleteResult: MethodChannel.Result? = null
    private var pendingDeleteUriForApi29: Uri? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanRecent" -> handleScanRecent(call, result)
                    "deleteAudio" -> handleDeleteAudio(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Light targeted media registration.
     * Lists top-level + 1 subfolder level (depth 2 max), filtered by audio extension,
     * lastModified > sinceEpochMs, cap maxFiles, calls MediaScannerConnection.scanFile.
     */
    private fun handleScanRecent(call: MethodCall, result: MethodChannel.Result) {
        val dirs = call.argument<List<String>>("dirs") ?: emptyList()
        val sinceEpochMs = (call.argument<Number>("sinceEpochMs") ?: 0L).toLong()
        val maxFiles = (call.argument<Number>("maxFiles") ?: 200).toInt()

        bgExecutor.execute {
            val candidatePaths = mutableListOf<String>()

            for (dirPath in dirs) {
                if (candidatePaths.size >= maxFiles) break
                try {
                    val dir = File(dirPath)
                    if (!dir.exists() || !dir.isDirectory || dir.isHidden || dir.name.startsWith(".")) {
                        continue
                    }
                    if (File(dir, ".nomedia").exists()) {
                        continue
                    }

                    val entries = dir.listFiles() ?: continue
                    for (entry in entries) {
                        if (candidatePaths.size >= maxFiles) break
                        try {
                            if (entry.isFile) {
                                if (!entry.name.startsWith(".")) {
                                    val ext = entry.extension.lowercase(Locale.ROOT)
                                    if (ext in AUDIO_EXTENSIONS && entry.lastModified() > sinceEpochMs) {
                                        candidatePaths.add(entry.absolutePath)
                                    }
                                }
                            } else if (entry.isDirectory) {
                                // Level 2: only 1 level of subfolders (depth 2 max, no deeper)
                                if (!entry.isHidden && !entry.name.startsWith(".") && !File(entry, ".nomedia").exists()) {
                                    val subEntries = entry.listFiles() ?: continue
                                    for (sub in subEntries) {
                                        if (candidatePaths.size >= maxFiles) break
                                        try {
                                            if (sub.isFile && !sub.name.startsWith(".")) {
                                                val ext = sub.extension.lowercase(Locale.ROOT)
                                                if (ext in AUDIO_EXTENSIONS && sub.lastModified() > sinceEpochMs) {
                                                    candidatePaths.add(sub.absolutePath)
                                                }
                                            }
                                        } catch (e: Exception) {
                                            Log.w(TAG, "Error checking sub-entry ${sub.absolutePath}", e)
                                        }
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "Error checking entry ${entry.absolutePath}", e)
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Error checking directory $dirPath", e)
                }
            }

            if (candidatePaths.isEmpty()) {
                mainHandler.post {
                    result.success(0)
                }
                return@execute
            }

            val latch = CountDownLatch(candidatePaths.size)
            val scannedCount = AtomicInteger(0)

            try {
                MediaScannerConnection.scanFile(
                    applicationContext,
                    candidatePaths.toTypedArray(),
                    null
                ) { _, uri ->
                    if (uri != null) {
                        scannedCount.incrementAndGet()
                    }
                    latch.countDown()
                }
                latch.await(5000, TimeUnit.MILLISECONDS)
            } catch (e: Exception) {
                Log.e(TAG, "MediaScannerConnection error", e)
            }

            mainHandler.post {
                result.success(scannedCount.get())
            }
        }
    }

    /**
     * Native audio deletion per Android platform specification.
     * Guarded to ensure ONE pending Result at a time (double-tap guard).
     */
    private fun handleDeleteAudio(call: MethodCall, result: MethodChannel.Result) {
        if (pendingDeleteResult != null) {
            Log.w(TAG, "Delete already in flight; rejecting duplicate request")
            result.success("error")
            return
        }

        val mediaStoreIds = call.argument<List<Number>>("mediaStoreIds")?.map { it.toLong() } ?: emptyList()
        val filePath = call.argument<String>("filePath")

        if (mediaStoreIds.isEmpty()) {
            result.success("error")
            return
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // API 30+ (Android 11+)
                val uris = mediaStoreIds.map { id ->
                    ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
                }
                val pendingIntent = MediaStore.createDeleteRequest(contentResolver, uris)
                pendingDeleteResult = result
                startIntentSenderForResult(
                    pendingIntent.intentSender,
                    REQUEST_CODE_DELETE_API_30,
                    null,
                    0,
                    0,
                    0
                )
            } else if (Build.VERSION.SDK_INT == Build.VERSION_CODES.Q) {
                // API 29 (Android 10)
                val firstId = mediaStoreIds.first()
                val uri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, firstId)
                try {
                    val rows = contentResolver.delete(uri, null, null)
                    if (rows > 0) {
                        result.success("deleted")
                    } else {
                        result.success("error")
                    }
                } catch (e: RecoverableSecurityException) {
                    pendingDeleteResult = result
                    pendingDeleteUriForApi29 = uri
                    try {
                        startIntentSenderForResult(
                            e.userAction.actionIntent.intentSender,
                            REQUEST_CODE_DELETE_API_29,
                            null,
                            0,
                            0,
                            0
                        )
                    } catch (intentEx: Exception) {
                        Log.e(TAG, "API 29 startIntentSenderForResult failed", intentEx)
                        pendingDeleteResult = null
                        pendingDeleteUriForApi29 = null
                        result.success("error")
                    }
                }
            } else {
                // API 24–28 (Android 7.0–9.0)
                val firstId = mediaStoreIds.first()
                val uri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, firstId)

                bgExecutor.execute {
                    try {
                        var pathToDelete = filePath
                        if (pathToDelete == null || pathToDelete.isEmpty()) {
                            try {
                                contentResolver.query(
                                    uri,
                                    arrayOf(MediaStore.Audio.Media.DATA),
                                    null,
                                    null,
                                    null
                                )?.use { cursor ->
                                    if (cursor.moveToFirst()) {
                                        val dataIdx = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
                                        if (dataIdx >= 0) {
                                            pathToDelete = cursor.getString(dataIdx)
                                        }
                                    }
                                }
                            } catch (e: Exception) {
                                Log.w(TAG, "Failed resolving path for ID $firstId", e)
                            }
                        }

                        var deleted = false
                        try {
                            val rows = contentResolver.delete(uri, null, null)
                            if (rows > 0) {
                                deleted = true
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "contentResolver.delete failed for $uri", e)
                        }

                        if (!deleted && pathToDelete != null) {
                            try {
                                val file = File(pathToDelete)
                                if (file.exists()) {
                                    deleted = file.delete()
                                }
                            } catch (e: Exception) {
                                Log.w(TAG, "File.delete fallback failed for $pathToDelete", e)
                            }
                        }

                        if (pathToDelete != null) {
                            try {
                                MediaScannerConnection.scanFile(
                                    applicationContext,
                                    arrayOf(pathToDelete),
                                    null,
                                    null
                                )
                            } catch (e: Exception) {
                                Log.w(TAG, "MediaScannerConnection scanFile failed for $pathToDelete", e)
                            }
                        }

                        mainHandler.post {
                            result.success(if (deleted) "deleted" else "error")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "API 24-28 delete execution error", e)
                        mainHandler.post {
                            result.success("error")
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "handleDeleteAudio exception", e)
            pendingDeleteResult = null
            pendingDeleteUriForApi29 = null
            result.success("error")
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            REQUEST_CODE_DELETE_API_30 -> {
                val pending = pendingDeleteResult
                pendingDeleteResult = null
                if (resultCode == Activity.RESULT_OK) {
                    pending?.success("deleted")
                } else {
                    pending?.success("cancelled")
                }
            }
            REQUEST_CODE_DELETE_API_29 -> {
                val pending = pendingDeleteResult
                val uri = pendingDeleteUriForApi29
                pendingDeleteResult = null
                pendingDeleteUriForApi29 = null

                if (resultCode == Activity.RESULT_OK && uri != null) {
                    try {
                        val rows = contentResolver.delete(uri, null, null)
                        if (rows > 0) {
                            pending?.success("deleted")
                        } else {
                            pending?.success("error")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "API 29 retry delete failed", e)
                        pending?.success("error")
                    }
                } else {
                    pending?.success("cancelled")
                }
            }
        }
    }
}
