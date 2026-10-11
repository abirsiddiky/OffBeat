# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Flutter Play Store deferred components optional dependencies
-dontwarn com.google.android.play.core.**

# audio_service
-keep class com.ryanheise.audioservice.** { *; }
-keepclassmembers class com.ryanheise.audioservice.** { *; }

# AndroidX Media & Support Media compat
-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }
-keepclassmembers class androidx.media.** { *; }
-keepclassmembers class android.support.v4.media.** { *; }

# media_kit and its JNI classes
-keep class com.alexmercerind.media_kit.** { *; }
-keep class com.alexmercerind.media_kit_libs_android_audio.** { *; }
-keep class com.alexmercerind.mediakit.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# audio_session
-keep class com.ryanheise.audio_session.** { *; }
-keep class com.ryanheise.audiosession.** { *; }
-keepclassmembers class com.ryanheise.audio_session.** { *; }

# on_audio_query
-keep class com.lucasjosino.on_audio_query.** { *; }
-keep class com.lucasjosino.on_audio_query_android.** { *; }
-keep class com.lucasjosino.on_audio_query_forked.** { *; }
-keepclassmembers class com.lucasjosino.on_audio_query.** { *; }
