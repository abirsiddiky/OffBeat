package com.ryanheise.audioservice

import android.content.Context
import android.content.Intent
import android.os.Build
import android.support.v4.media.session.MediaControllerCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.view.KeyEvent

open class MediaButtonReceiver : androidx.media.session.MediaButtonReceiver() {
    companion object {
        const val ACTION_NOTIFICATION_DELETE = "com.ryanheise.audioservice.intent.action.ACTION_NOTIFICATION_DELETE"
        private const val TAG = "OffBeatMediaButton"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        if (ACTION_NOTIFICATION_DELETE == intent.action && AudioService.instance != null) {
            AudioService.instance.handleDeleteNotification()
            return
        }

        if (Intent.ACTION_MEDIA_BUTTON == intent.action && AudioService.instance != null) {
            try {
                val sessionToken = AudioService.instance.sessionToken
                if (sessionToken != null) {
                    val keyEvent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT, KeyEvent::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT)
                    }

                    if (keyEvent != null && keyEvent.action == KeyEvent.ACTION_DOWN) {
                        val controller = MediaControllerCompat(context, sessionToken)
                        val controls = controller.transportControls
                        when (keyEvent.keyCode) {
                            AudioService.KEYCODE_BYPASS_PLAY, KeyEvent.KEYCODE_MEDIA_PLAY -> {
                                controls.play()
                                return
                            }
                            AudioService.KEYCODE_BYPASS_PAUSE, KeyEvent.KEYCODE_MEDIA_PAUSE -> {
                                controls.pause()
                                return
                            }
                            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, KeyEvent.KEYCODE_HEADSETHOOK -> {
                                val state = controller.playbackState?.state
                                if (state == PlaybackStateCompat.STATE_PLAYING) {
                                    controls.pause()
                                } else {
                                    controls.play()
                                }
                                return
                            }
                            KeyEvent.KEYCODE_MEDIA_NEXT -> {
                                controls.skipToNext()
                                return
                            }
                            KeyEvent.KEYCODE_MEDIA_PREVIOUS -> {
                                controls.skipToPrevious()
                                return
                            }
                            KeyEvent.KEYCODE_MEDIA_STOP -> {
                                controls.stop()
                                return
                            }
                            KeyEvent.KEYCODE_MEDIA_FAST_FORWARD -> {
                                controls.fastForward()
                                return
                            }
                            KeyEvent.KEYCODE_MEDIA_REWIND -> {
                                controls.rewind()
                                return
                            }
                            else -> {
                                controller.dispatchMediaButtonEvent(keyEvent)
                                return
                            }
                        }
                    } else if (keyEvent != null) {
                        val controller = MediaControllerCompat(context, sessionToken)
                        controller.dispatchMediaButtonEvent(keyEvent)
                        return
                    }
                }
            } catch (e: Throwable) {
                android.util.Log.e(TAG, "Fast in-process media button dispatch error", e)
            }
        }

        super.onReceive(context, intent)
    }
}
