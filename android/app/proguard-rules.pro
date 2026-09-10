# Flutter ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-keep class com.google.android.gms.common.internal.safeparcel.SafeParcelable {
    public static final *** CREATOR;
}

# Keep local notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Fix Play Core missing classes error in R8
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.**
-dontwarn org.checkerframework.**
-dontwarn javax.annotation.**

# Common Flutter rules
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }
