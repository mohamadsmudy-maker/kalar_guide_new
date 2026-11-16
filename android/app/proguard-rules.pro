# ─────────────────────────────────────────────────────────────────────
# R8 / ProGuard rules for the release build (isMinifyEnabled = true).
#
# flutter_local_notifications stores every scheduled notification with Gson
# (reflection + generic type information). Without these rules R8 strips
# that information and zonedSchedule() fails in release builds with
# "Missing type parameter" — prayer notifications then never arrive.
# ─────────────────────────────────────────────────────────────────────
-keep class com.dexterous.** { *; }

-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Gson
-keep class com.google.gson.** { *; }
-keep class sun.misc.Unsafe { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
