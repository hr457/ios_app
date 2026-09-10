SAFL fixed project files

Replace your project lib files with these files, keep your login API code as-is.

Run:
flutter clean
flutter pub get
flutter run -d chrome

For Android camera add in android/app/src/main/AndroidManifest.xml:
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />

PDF receipt uses PdfGoogleFonts through the printing package, so no local font folder is required.
