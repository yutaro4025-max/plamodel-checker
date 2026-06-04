@echo off
chcp 65001 > nul
title .NET 8 セットアップ

:: ─────────────────────────────────────────────
:: 管理者権限がなければ自動で昇格して再起動
:: ─────────────────────────────────────────────
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo 管理者権限で再起動します...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: ─────────────────────────────────────────────
:: PowerShellスクリプトを実行
:: ─────────────────────────────────────────────
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0install_dotnet.ps1"
