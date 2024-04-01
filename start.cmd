@echo off
mode con: cols=120 lines=50
Rem PowerShell scripts can not be launched directly so we launch PowerShell using a command file.
Rem First make powershell read this file, skip a number of lines, and execute it.


PowerShell -Command "Get-Content 'scripts\main.ps1' | Select-Object | Out-String | Invoke-Expression"



