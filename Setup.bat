@echo off
chcp 65001 > nul
setlocal

echo ============================================================
echo  退勤リマインダー + 週次レポート セットアップ
echo ============================================================
echo.
echo このスクリプトは以下を自動で設定します：
echo   1. PowerShell 実行ポリシーの確認・設定
echo   2. 出勤登録タスクのスケジューラ登録
echo   3. 必要フォルダの作成確認
echo.
echo 実行前に以下を確認してください：
echo   - Script-A_Register.ps1
echo   - Script-B_Notify.ps1
echo   - WeeklyReport.ps1
echo   が、このバッチファイルと同じフォルダにあること
echo.
pause

:: ============================================================
:: スクリプトのフォルダパスを取得
:: ============================================================
set SCRIPT_DIR=%~dp0
:: 末尾の \ を除去
if "%SCRIPT_DIR:~-1%"=="\" set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

set SCRIPT_A=%SCRIPT_DIR%\Script-A_Register.ps1
set SCRIPT_B=%SCRIPT_DIR%\Script-B_Notify.ps1
set SCRIPT_R=%SCRIPT_DIR%\WeeklyReport.ps1

:: ============================================================
:: ファイル存在確認
:: ============================================================
echo [確認] スクリプトファイルの存在を確認しています...

if not exist "%SCRIPT_A%" (
    echo [エラー] Script-A_Register.ps1 が見つかりません。
    echo          このバッチファイルと同じフォルダに置いてください。
    pause
    exit /b 1
)
if not exist "%SCRIPT_B%" (
    echo [エラー] Script-B_Notify.ps1 が見つかりません。
    echo          このバッチファイルと同じフォルダに置いてください。
    pause
    exit /b 1
)
if not exist "%SCRIPT_R%" (
    echo [エラー] WeeklyReport.ps1 が見つかりません。
    echo          このバッチファイルと同じフォルダに置いてください。
    pause
    exit /b 1
)
echo [OK] 全スクリプトファイルを確認しました。
echo.

:: ============================================================
:: PowerShell 実行ポリシー確認・設定
:: ============================================================
echo [確認] PowerShell 実行ポリシーを確認しています...

powershell.exe -Command "$policy = Get-ExecutionPolicy -Scope CurrentUser; if ($policy -eq 'Restricted') { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force; Write-Host '[設定] 実行ポリシーを RemoteSigned に変更しました。' } else { Write-Host '[OK] 実行ポリシーは変更不要です：' $policy }"

echo.

:: ============================================================
:: 起動時刻の入力
:: ============================================================
echo [入力] 出勤登録スクリプトの起動時刻を入力してください。
echo        毎朝この時刻にダイアログが表示されます。
echo        形式：HH:MM（例: 08:30）
echo.
set /p STARTUP_TIME=起動時刻を入力してください:

:: 入力値チェック（簡易）
if "%STARTUP_TIME%"=="" (
    echo [エラー] 時刻が入力されていません。
    pause
    exit /b 1
)

echo.
echo [確認] 以下の設定でタスクを登録します：
echo        タスク名  : AttendanceRegister
echo        起動時刻  : 毎日 %STARTUP_TIME%
echo        スクリプト: %SCRIPT_A%
echo.
pause

:: ============================================================
:: タスクスケジューラ登録
:: PowerShell の Register-ScheduledTask を使用
:: （schtasks /TR はパスにスペースが含まれると引数が壊れるため使用しない）
:: ============================================================
echo [登録] タスクスケジューラに登録しています...

set TEMP_PS=%TEMP%\setup_attendance_task.ps1

echo $scriptPath = '%SCRIPT_A%' > "%TEMP_PS%"
echo Unregister-ScheduledTask -TaskName 'AttendanceRegister' -Confirm:$false -ErrorAction SilentlyContinue >> "%TEMP_PS%"
echo $action   = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File "' + $scriptPath + '"') >> "%TEMP_PS%"
echo $trigger  = New-ScheduledTaskTrigger -Daily -At '%STARTUP_TIME%' >> "%TEMP_PS%"
echo $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1) >> "%TEMP_PS%"
echo Register-ScheduledTask -TaskName 'AttendanceRegister' -Action $action -Trigger $trigger -Settings $settings -RunLevel Limited -Force ^| Out-Null >> "%TEMP_PS%"
echo Write-Host '[OK] タスクスケジューラへの登録が完了しました。' >> "%TEMP_PS%"

powershell.exe -ExecutionPolicy Bypass -File "%TEMP_PS%"
set PS_EXIT=%errorlevel%
del "%TEMP_PS%" > nul 2>&1

if %PS_EXIT% neq 0 (
    echo [エラー] タスクの登録に失敗しました。
    echo          エラーコード: %PS_EXIT%
    pause
    exit /b 1
)

echo.

:: ============================================================
:: logsフォルダ作成
:: ============================================================
if not exist "%SCRIPT_DIR%\logs" (
    mkdir "%SCRIPT_DIR%\logs"
    echo [作成] logs フォルダを作成しました。
) else (
    echo [OK] logs フォルダは既に存在します。
)

:: ============================================================
:: 完了メッセージ
:: ============================================================
echo.
echo ============================================================
echo  セットアップ完了
echo ============================================================
echo.
echo 設定内容：
echo   出勤登録タスク : 毎日 %STARTUP_TIME% に自動起動
echo   退勤通知タスク : 出勤登録時に自動登録（当日分）
echo   週次レポート   : 金曜日のみ退勤60分前に自動起動
echo.
echo 次のステップ：
echo   1. 各スクリプトの CONFIG セクションのパスを確認してください
echo      （$ONEDRIVE_LOG_DIR は $env:OneDrive ベースで自動設定されます）
echo   2. 各 .ps1 スクリプトは UTF-8 BOM付きで保存してください
echo      （この Setup.bat は BOM なし UTF-8 で保存すること）
echo   3. タスクスケジューラを開いて動作確認してください
echo      （タスクスケジューラ → AttendanceRegister → 実行）
echo.
echo 注意：
echo   タスクスケジューラのプロパティで
echo   「ユーザーがログオンしているときのみ実行する」
echo   が選択されていることを確認してください。
echo.
pause
