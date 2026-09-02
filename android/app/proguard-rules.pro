# Flutter and plugin classes are resolved reflectively at runtime.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase / Google Play services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# mobile_scanner (ML Kit barcode) loads model classes dynamically.
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
