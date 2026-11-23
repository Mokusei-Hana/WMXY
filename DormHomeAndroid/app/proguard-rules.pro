# Keep kotlinx.serialization & okhttp
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.sakiyui.dormhome.**$$serializer { *; }
-keepclassmembers class com.sakiyui.dormhome.** {
    *** Companion;
}
