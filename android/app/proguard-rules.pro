## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

## Gson rules (if using JSON)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

## Keep model classes (your data models)
-keep class com.dailyrhythm.dailyrhythm.** { *; }

## SQLite
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

## Google services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
