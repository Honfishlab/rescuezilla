@echo off
setlocal
set "SYSTEM_IMAGE_APP=%~dp0SystemImage.ps1"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -Command "Start-Process -Verb RunAs -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList ('-NoProfile -ExecutionPolicy RemoteSigned -File ' + [char]34 + $env:SYSTEM_IMAGE_APP + [char]34) -ErrorAction Stop"
if errorlevel 1 pause
