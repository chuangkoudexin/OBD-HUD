@echo off
rem ============================================
rem  OBD HUD - 一键构建脚本 (Windows)
rem  用法: build_apk.bat            -> release
rem        build_apk.bat --debug    -> debug
rem ============================================
setlocal

set "FLUTTER_ROOT=C:\flutter"
set "JAVA_HOME=C:\jdk-17.0.13+11"
set "ANDROID_HOME=C:\Android\Sdk"
set "ANDROID_SDK_ROOT=C:\Android\Sdk"
set "PUB_CACHE=C:\Users\Administrator\AppData\Local\Pub\Cache"
set "LOCALAPPDATA=C:\Users\Administrator\AppData\Local"

rem 加入 Flutter 自带 MinGit, 解决 "Unable to find git in your PATH"
set "PATH=C:\flutter\bin\mingit\cmd;C:\Windows\system32;C:\Windows;C:\flutter\bin;C:\jdk-17.0.13+11\bin;C:\Android\Sdk\platform-tools;%PATH%"

echo [OBD HUD] JAVA_HOME=%JAVA_HOME%
echo [OBD HUD] ANDROID_HOME=%ANDROID_HOME%
echo [OBD HUD] Building APK: flutter build apk %* --no-pub

call "C:\flutter\bin\flutter.bat" build apk %* --no-pub
echo [OBD HUD] exit code = %ERRORLEVEL%
endlocal
