$ErrorActionPreference = "Stop"
$dir = "C:\Users\dibiaozuiq\android-sdk"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$zip = Join-Path $dir "cmdtools.zip"
Invoke-WebRequest -Uri "https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip" -OutFile $zip -UseBasicParsing
Expand-Archive $zip -DestinationPath (Join-Path $dir "temp") -Force
New-Item -ItemType Directory -Force -Path (Join-Path $dir "cmdline-tools") | Out-Null
Move-Item (Join-Path $dir "temp\cmdline-tools") (Join-Path $dir "cmdline-tools\latest")
Remove-Item $zip
Remove-Item (Join-Path $dir "temp") -Recurse -Force
Write-Output "cmdline-tools installed"
