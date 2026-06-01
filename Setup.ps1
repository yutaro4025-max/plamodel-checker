# =============================================================================
# Setup.ps1
# 役割: 退勤リマインダー + 週次レポート セットアップ
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# =============================================================================
# ファイル存在確認
# =============================================================================
Write-Host "============================================================"
Write-Host "  退勤リマインダー + 週次レポート セットアップ"
Write-Host "============================================================"
Write-Host ""
Write-Host "このスクリプトは以下を自動で設定します:"
Write-Host "  1. PowerShell 実行ポリシーの確認と設定"
Write-Host "  2. 出勤登録タスクのスケジューラ登録"
Write-Host "  3. 必要フォルダの作成確認"
Write-Host ""
Write-Host "実行前に以下が同じフォルダにあることを確認してください:"
Write-Host "  - Script-A_Register.ps1"
Write-Host "  - Script-B_Notify.ps1"
Write-Host "  - WeeklyReport.ps1"
Write-Host ""
Read-Host "準備ができたら Enter を押してください"

$scriptA = Join-Path $ScriptDir "Script-A_Register.ps1"
$scriptB = Join-Path $ScriptDir "Script-B_Notify.ps1"
$scriptR = Join-Path $ScriptDir "WeeklyReport.ps1"

Write-Host ""
Write-Host "[確認] スクリプトファイルの存在を確認しています..."

foreach ($file in @($scriptA, $scriptB, $scriptR)) {
    if (-not (Test-Path $file)) {
        Write-Host "[エラー] 見つかりません: $file" -ForegroundColor Red
        Read-Host "Enter を押して終了"
        exit 1
    }
}
Write-Host "[OK] 全スクリプトファイルを確認しました。" -ForegroundColor Green

# =============================================================================
# PowerShell 実行ポリシー確認
# =============================================================================
Write-Host ""
Write-Host "[確認] PowerShell 実行ポリシーを確認しています..."
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq "Restricted") {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    Write-Host "[設定] 実行ポリシーを RemoteSigned に変更しました。" -ForegroundColor Yellow
} else {
    Write-Host "[OK] 実行ポリシーは変更不要です: $policy" -ForegroundColor Green
}

# =============================================================================
# 起動時刻の入力（HH:MM 形式のバリデーション付き）
# =============================================================================
Write-Host ""
Write-Host "[入力] Script-A の毎朝の自動起動時刻を入力してください。"
Write-Host "       毎朝この時刻にダイアログが表示されます。"
Write-Host "       形式: HH:MM (例: 08:30)"
Write-Host ""

$startupTime = $null
while ($null -eq $startupTime) {
    $input = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Script-A (出勤登録) の毎朝の起動時刻を入力してください。`n形式: HH:MM (例: 08:30)",
        "セットアップ - 起動時刻入力",
        "08:30"
    )
    if ([string]::IsNullOrWhiteSpace($input)) {
        Write-Host "[キャンセル] 入力がキャンセルされました。終了します。" -ForegroundColor Yellow
        exit 0
    }
    try {
        $startupTime = [datetime]::ParseExact($input, "HH:mm", $null)
        Write-Host "[OK] 起動時刻: $($startupTime.ToString('HH:mm'))" -ForegroundColor Green
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "時刻の形式が正しくありません。`nHH:MM 形式で入力してください。`n例: 08:30",
            "入力エラー", 0, 16) | Out-Null
        $startupTime = $null
    }
}

$timeStr = $startupTime.ToString("HH:mm")

# =============================================================================
# タスクスケジューラ登録
# =============================================================================
Write-Host ""
Write-Host "[確認] 以下の設定でタスクを登録します:"
Write-Host "       タスク名  : AttendanceRegister"
Write-Host "       起動時刻  : 毎日 $timeStr"
Write-Host "       スクリプト: $scriptA"
Write-Host ""
Read-Host "登録するには Enter を押してください"

Write-Host "[登録] タスクスケジューラに登録しています..."

if (Get-ScheduledTask -TaskName "AttendanceRegister" -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName "AttendanceRegister" -Confirm:$false
    Write-Host "[削除] 既存の AttendanceRegister タスクを削除しました。"
}

$action   = New-ScheduledTaskAction -Execute "powershell.exe" `
                -Argument "-ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File `"$scriptA`""
$trigger  = New-ScheduledTaskTrigger -Daily -At $startupTime
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1)

Register-ScheduledTask `
    -TaskName "AttendanceRegister" `
    -Action   $action `
    -Trigger  $trigger `
    -Settings $settings `
    -RunLevel Limited `
    -Force | Out-Null

Write-Host "[OK] タスクスケジューラへの登録が完了しました。" -ForegroundColor Green

# =============================================================================
# logs フォルダ作成
# =============================================================================
$logsDir = Join-Path $ScriptDir "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    Write-Host "[作成] logs フォルダを作成しました。"
} else {
    Write-Host "[OK] logs フォルダは既に存在します。"
}

# =============================================================================
# 完了メッセージ
# =============================================================================
Write-Host ""
Write-Host "============================================================"
Write-Host "  セットアップ完了"
Write-Host "============================================================"
Write-Host ""
Write-Host "設定内容:"
Write-Host "  出勤登録タスク : 毎日 $timeStr に自動起動"
Write-Host "  退勤通知タスク : 出勤登録時に動的登録（当日分）"
Write-Host "  週次レポート   : 金曜日のみ退勤60分前に自動起動"
Write-Host ""
Write-Host "次のステップ:"
Write-Host "  1. 各スクリプトの CONFIG セクションのパスを確認してください"
Write-Host "  2. 各 .ps1 スクリプトは UTF-8 BOM付きで保存してください"
Write-Host "  3. タスクスケジューラを開いて動作確認してください"
Write-Host "     (タスクスケジューラ -> AttendanceRegister -> 実行)"
Write-Host ""
Write-Host "注意: タスクスケジューラのプロパティで" -ForegroundColor Yellow
Write-Host "  「ユーザーがログオンしているときのみ実行する」" -ForegroundColor Yellow
Write-Host "  が選択されていることを確認してください。" -ForegroundColor Yellow
Write-Host ""

[System.Windows.Forms.MessageBox]::Show(
    "セットアップが完了しました。`n`n" +
    "出勤登録タスク: 毎日 $timeStr に自動起動`n" +
    "退勤通知タスク: 出勤登録時に動的登録`n" +
    "週次レポート  : 金曜日のみ退勤60分前`n`n" +
    "タスクスケジューラで動作確認してください。",
    "セットアップ完了", 0, 64) | Out-Null
