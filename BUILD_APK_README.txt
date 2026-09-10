SAFL Android APK Build Ready

Changes done:
- Gradle downgraded to 8.7
- Android Gradle Plugin downgraded to 8.5.2
- Kotlin downgraded to 1.9.24
- Kotlin incremental cache disabled
- Removed unused package_info_plus / permission_handler / path_provider dependencies
- Duplicate MainActivity removed
- Internet + Camera + cleartext HTTP allowed in AndroidManifest.xml

Before building APK on Developer PC:
1. Close Android Studio.
2. Delete these folders if present:
   D:\projects\build
   D:\projects\.dart_tool
   D:\projects\.gradle
   D:\projects\android\.gradle
   C:\Users\YOUR_USER\.gradle\caches
   C:\Users\YOUR_USER\.gradle\daemon

Then run:
   cd /d D:\projects
   flutter clean
   flutter pub get
   cd android
   gradlew clean --no-daemon
   cd ..
   flutter build apk --release --no-shrink

APK path:
   build\app\outputs\flutter-apk\app-release.apk
