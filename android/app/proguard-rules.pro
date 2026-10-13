# Proguard rules for OffBeat release builds

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# audio_service & audio_session
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.audio_session.** { *; }
-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }

# media_kit / com.alexmercerind.** / media.kit.** and classes with native methods
-keep class com.alexmercerind.** { *; }
-keep class media.kit.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# on_audio_query
-keep class com.lucasjosino.on_audio_query.** { *; }

# drift & sqlite
-keep class eu.simonbinder.** { *; }
-keep class org.sqlite.** { *; }

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# Attributes and common warnings
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-dontwarn com.google.android.play.core.**
