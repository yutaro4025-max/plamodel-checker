@echo off
chcp 65001 > nul
title .NET 8 セットアップ

set LOGFILE=%~dp0setup_log.txt

:: ── 管理者権限がなければ自動昇格 ──────────────────────────────
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo 管理者権限で再起動します...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: ── ログ開始 ──────────────────────────────────────────────────
for /f "usebackq" %%i in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"`) do set DT=%%i
echo. >> "%LOGFILE%"
echo ============================================================ >> "%LOGFILE%"
echo %DT% [INFO] セットアップ開始 >> "%LOGFILE%"
echo %DT% [INFO] PC=%COMPUTERNAME%  USER=%USERDOMAIN%\%USERNAME% >> "%LOGFILE%"

:: ── .NET 8 確認 ────────────────────────────────────────────────
echo.
echo ^>^>^> .NET 8 Desktop Runtime を確認しています...

where dotnet >nul 2>&1
if %errorLevel% EQU 0 (
    dotnet --list-runtimes 2>nul | findstr /C:"Microsoft.WindowsDesktop.App 8." >nul
    if %errorLevel% EQU 0 (
        echo     [OK] .NET 8 Desktop Runtime は既にインストール済みです。
        echo     PlamodelChecker.exe をそのまま実行できます。
        echo %DT% [OK  ] 終了（インストール不要） >> "%LOGFILE%"
        echo.
        pause
        exit /b 0
    )
)

echo     [!!] .NET 8 Desktop Runtime が見つかりません。インストールを開始します。
echo %DT% [WARN] .NET 8 未インストール >> "%LOGFILE%"

:: ── ダウンロード ────────────────────────────────────────────────
echo.
echo ^>^>^> ダウンロード中...（しばらくお待ちください）

set INSTALLER=%TEMP%\dotnet8-runtime.exe
curl -L --ssl-no-revoke "https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x64.exe" -o "%INSTALLER%"

if %errorLevel% NEQ 0 (
    echo     [NG] ダウンロードに失敗しました。
    echo.
    echo  手動インストール方法：
    echo  ブラウザで以下を開き .NET Desktop Runtime 8.x.x (x64) をダウンロードして実行：
    echo  https://dotnet.microsoft.com/download/dotnet/8.0
    echo %DT% [ERR ] 終了（ダウンロード失敗） >> "%LOGFILE%"
    echo.
    pause
    exit /b 1
)

echo     [OK] ダウンロード完了
echo %DT% [OK  ] ダウンロード完了 >> "%LOGFILE%"

:: ── インストール ────────────────────────────────────────────────
echo.
echo ^>^>^> インストール中...（1〜2分かかります）

start /wait "" "%INSTALLER%" /install /quiet /norestart
set EXITCODE=%ERRORLEVEL%
del /f /q "%INSTALLER%" >nul 2>&1

if %EXITCODE% EQU 0 (
    echo     [OK] インストール完了
    echo %DT% [OK  ] 終了（インストール成功） >> "%LOGFILE%"
    goto :done
)
if %EXITCODE% EQU 3010 (
    echo     [OK] インストール完了（PCの再起動を推奨します）
    echo %DT% [OK  ] 終了（インストール成功・要再起動） >> "%LOGFILE%"
    goto :done
)
if %EXITCODE% EQU 1638 (
    echo     [OK] 既に同等バージョンがインストール済みです
    echo %DT% [OK  ] 終了（既存バージョン検出） >> "%LOGFILE%"
    goto :done
)

echo     [NG] インストールに失敗しました。終了コード: %EXITCODE%
echo %DT% [ERR ] 終了（インストール失敗 ExitCode=%EXITCODE%） >> "%LOGFILE%"
pause
exit /b 1

:done
echo.
echo ================================================
echo   セットアップ完了！
echo   PlamodelChecker.exe をダブルクリックして起動
echo ================================================
echo   ログ: %LOGFILE%
echo.
pause
