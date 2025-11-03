# Evita que R8 elimine o renombre clases de ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Evita eliminar clases específicas del reconocimiento de texto multilenguaje
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }
-keep class com.google.mlkit.vision.text.latin.** { *; }

# Mantén las interfaces
-keep interface com.google.mlkit.** { *; }

# Desactiva advertencias innecesarias
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**