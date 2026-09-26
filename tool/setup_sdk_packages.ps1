$ErrorActionPreference = "Stop"
$env:JAVA_HOME = "D:\jdk21"
$env:ANDROID_HOME = "C:\Users\dibiaozuiq\android-sdk"
$env:Path = "$env:ANDROID_HOME\cmdline-tools\latest\bin;D:\jdk21\bin;$env:Path"

# 自动接受所有许可
$licenses = sdkmanager.bat --licenses
$licenses | Out-Null

sdkmanager.bat "platforms;android-35" "build-tools;35.0.0" "platform-tools"
