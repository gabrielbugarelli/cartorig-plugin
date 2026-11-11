@echo off
setlocal
echo Diagnostico de instalacao cartorig-dev (somente leitura)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0cartorig-dev-diagnose.ps1"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo ERRO ao coletar diagnostico - codigo %RC%.
echo Arquivo de relatorio: abra a pasta %%TEMP%% e procure cartorig-dev-install-check.txt
echo.
pause
exit /b %RC%
