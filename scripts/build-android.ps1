$ErrorActionPreference = 'Stop'
$flutter = 'C:\Users\GAMING\develop\flutter\bin\flutter.bat'
$env:JAVA_HOME = 'C:\Users\GAMING\develop\jdk21\jdk-21.0.12.1+1'
& $flutter pub get
& $flutter analyze
& $flutter test
& $flutter build apk --debug
Write-Host 'APK: build\app\outputs\flutter-apk\app-debug.apk'
