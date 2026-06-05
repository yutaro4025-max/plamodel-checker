@echo off
chcp 65001 > nul
title .NET 8 セットアップ

set LOGFILE=%~dp0setup_log.txt

:: ── 管理者権限がなければ自動昇格 ──────────────────────────────
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: ── ログ開始（%date% %time% を使用、PowerShell不要） ──────────
set DT=%date% %time: =0%
echo. >> "%LOGFILE%"
echo ==================================================== >> "%LOGFILE%"
echo %DT% [INFO] セットアップ開始 >> "%LOGFILE%"
echo %DT% [INFO] PC=%COMPUTERNAME% USER=%USERDOMAIN%\%USERNAME% >> "%LOGFILE%"

:: ── .NET 8 確認 ────────────────────────────────────────────────
echo.
echo .NET 8 Desktop Runtime を確認しています...

where dotnet >nul 2>&1
if errorlevel 1 goto :not_found

dotnet --list-runtimes 2>nul | findstr /C:"Microsoft.WindowsDesktop.App 8." >nul
if errorlevel 1 goto :not_found

:: インストール済み
echo [OK] .NET 8 Desktop Runtime は既にインストール済みです。
echo     ツールをそのまま起動できます。
set DT=%date% %time: =0%
echo %DT% [OK] 終了（インストール不要） >> "%LOGFILE%"
echo.
pause
exit /b 0

:not_found
echo [!!] .NET 8 Desktop Runtime が見つかりません。インストールを開始します。
set DT=%date% %time: =0%
echo %DT% [WARN] .NET 8 未インストール >> "%LOGFILE%"

:: ── ダウンロード ────────────────────────────────────────────────
echo.
echo ダウンロード中...（しばらくお待ちください）
set DT=%date% %time: =0%
echo %DT% [INFO] ダウンロード開始 >> "%LOGFILE%"

set INSTALLER=%TEMP%\dotnet8-runtime.exe
curl -L --ssl-no-revoke "https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x64.exe" -o "%INSTALLER%"
if errorlevel 1 goto :download_fail

echo [OK] ダウンロード完了
set DT=%date% %time: =0%
echo %DT% [OK] ダウンロード完了 >> "%LOGFILE%"
goto :install

:download_fail
echo [NG] ダウンロードに失敗しました。
echo.
echo  手動インストール:
echo  https://dotnet.microsoft.com/download/dotnet/8.0
echo  .NET Desktop Runtime 8.x.x (x64) をダウンロードして実行してください。
set DT=%date% %time: =0%
echo %DT% [ERR] 終了（ダウンロード失敗） >> "%LOGFILE%"
echo.
pause
exit /b 1

:: ── インストール ────────────────────────────────────────────────
:install
echo.
echo インストール中...（1〜2分かかります）
set DT=%date% %time: =0%
echo %DT% [INFO] インストール開始 >> "%LOGFILE%"

start /wait "" "%INSTALLER%" /install /quiet /norestart
set EXITCODE=%errorLevel%
del /f /q "%INSTALLER%" >nul 2>&1

if %EXITCODE% EQU 0 goto :success
if %EXITCODE% EQU 3010 goto :success_reboot
if %EXITCODE% EQU 1638 goto :success

echo [NG] インストール失敗。終了コード: %EXITCODE%
set DT=%date% %time: =0%
echo %DT% [ERR] 終了（インストール失敗 ExitCode=%EXITCODE%） >> "%LOGFILE%"
pause
exit /b 1

:success
echo [OK] インストール完了
set DT=%date% %time: =0%
echo %DT% [OK] 終了（インストール成功） >> "%LOGFILE%"
goto :done

:success_reboot
echo [OK] インストール完了（PCの再起動を推奨します）
set DT=%date% %time: =0%
echo %DT% [OK] 終了（インストール成功・要再起動） >> "%LOGFILE%"
goto :done

:done
echo.
echo ================================================
echo   セットアップ完了!
echo   PlamodelChecker.exe をダブルクリックして起動
echo ================================================
echo   ログ: %LOGFILE%
echo.
pause
