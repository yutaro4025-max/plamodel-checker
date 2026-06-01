# =============================================================================
# Script-A_Register.ps1
# 役割    : 出勤登録・予定退勤時間入力・通知タスク動的登録
# 実行方式: タスクスケジューラ（毎朝定時起動）
# 注意    : 実行前にパス設定（CONFIG セクション）を環境に合わせて変更すること
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms

# =============================================================================
# CONFIG：環境に合わせて変更する箇所
# =============================================================================
# Fix(Bug3): $env:OneDrive を使うことで "OneDrive" / "OneDrive - Honda" 等の
#            フォルダ名差異を吸収する。Script-B と必ず同じ値にすること。
$ONEDRIVE_LOG_DIR  = "$env:OneDrive\AttendanceLogs"
$LOCAL_LOG_DIR     = "$PSScriptRoot\logs"
$SCRIPT_B_PATH     = "$PSScriptRoot\Script-B_Notify.ps1"
$TASK_NAME         = "AttendanceNotify_$(Get-Date -Format 'yyyyMMdd')"
$LOG_FILENAME      = "attendance_log.csv"
# =============================================================================

# --- ログ関数 -----------------------------------------------------------------
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp][$Level] $Message"
    Write-Host $line
    # Fix(Bug1): Write-Log はメイン try より先に呼ばれる可能性があるため
    #            ここでもディレクトリを保証する（Script-B と同じ実装に統一）
    if (-not (Test-Path $LOCAL_LOG_DIR)) {
        New-Item -ItemType Directory -Path $LOCAL_LOG_DIR -Force | Out-Null
    }
    Add-Content -Path "$LOCAL_LOG_DIR\script_a.log" -Value $line -Encoding UTF8
}

# --- フォルダ確認・作成 -------------------------------------------------------
function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Log "フォルダを作成しました: $Path"
    }
}

# --- 入力ダイアログ（InputBox）------------------------------------------------
function Show-InputDialog {
    param([string]$Prompt, [string]$Title, [string]$Default = "")
    Add-Type -AssemblyName Microsoft.VisualBasic
    $result = [Microsoft.VisualBasic.Interaction]::InputBox($Prompt, $Title, $Default)
    return $result
}

# --- 時刻バリデーション -------------------------------------------------------
function Validate-Time {
    param([string]$TimeStr)
    try {
        $parsed = [datetime]::ParseExact($TimeStr, "HH:mm", $null)
        return $parsed
    } catch {
        return $null
    }
}

# --- CSV ログ書き込み（新規行追加）--------------------------------------------
function Write-CsvLog {
    param(
        [string]$LogPath,
        [string]$Date,
        [string]$StartTime,
        [string]$PlannedEndTime
    )
    $header = "Date,StartTime,PlannedEndTime,NotifiedAt,ActualEndTime"
    $newRow  = "$Date,$StartTime,$PlannedEndTime,,"

    if (-not (Test-Path $LogPath)) {
        Set-Content -Path $LogPath -Value $header -Encoding UTF8
        Write-Log "CSVログを新規作成しました: $LogPath"
    }
    Add-Content -Path $LogPath -Value $newRow -Encoding UTF8
}

# --- 同日二重起動ガード -------------------------------------------------------
function Check-DuplicateEntry {
    param([string]$LogPath)
    if (-not (Test-Path $LogPath)) { return $false }
    $today = Get-Date -Format "yyyy-MM-dd"
    $content = Get-Content $LogPath -Encoding UTF8
    foreach ($line in $content) {
        if ($line.StartsWith($today)) { return $true }
    }
    return $false
}

# --- タスクスケジューラ動的登録 -----------------------------------------------
function Register-NotifyTask {
    param(
        [string]$TaskName,
        [datetime]$NotifyTime,
        [string]$ScriptBPath
    )

    # 既存の同名タスクがあれば削除
    # Fix(Bug2): schtasks CLI は PowerShell がスペース含み変数を複数引数に分割して
    #            渡すため /TR の値が壊れる。Register-ScheduledTask に置き換えて解消。
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Log "既存の通知タスクを削除しました: $TaskName"
    }

    $action   = New-ScheduledTaskAction `
                    -Execute  "powershell.exe" `
                    -Argument "-ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File `"$ScriptBPath`""
    $trigger  = New-ScheduledTaskTrigger -Once -At $NotifyTime
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1)

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action   $action `
        -Trigger  $trigger `
        -Settings $settings `
        -RunLevel Limited `
        -Force | Out-Null

    Write-Log "通知タスクを登録しました: $TaskName / 実行予定時刻: $($NotifyTime.ToString('yyyy/MM/dd HH:mm'))"
}

# =============================================================================
# メイン処理
# =============================================================================
try {
    # Fix(Bug1): タスクスケジューラ経由の非インタラクティブセッションでは
    #            スクリプト先頭の Add-Type が別コンテキスト扱いになる場合がある。
    #            try ブロック内で再ロードして MessageBox が確実に使えるようにする。
    Add-Type -AssemblyName System.Windows.Forms

    Ensure-Directory $LOCAL_LOG_DIR
    Ensure-Directory $ONEDRIVE_LOG_DIR

    Write-Log "=== Script-A 開始 ==="

    $csvPath = Join-Path $ONEDRIVE_LOG_DIR $LOG_FILENAME

    # 同日二重起動チェック
    if (Check-DuplicateEntry -LogPath $csvPath) {
        Write-Log "本日分のログが既に存在します。二重登録を防止して終了します。" "WARN"
        [System.Windows.Forms.MessageBox]::Show(
            "本日分の出勤記録がすでに登録されています。`n重複登録を防止しました。",
            "出勤登録", 0, 48) | Out-Null
        exit 0
    }

    # --- 出勤時間入力 ---
    $startTimeStr = ""
    $startTime    = $null
    while ($null -eq $startTime) {
        $startTimeStr = Show-InputDialog `
            -Prompt "出勤時間を入力してください（例: 09:00）" `
            -Title  "出勤登録" `
            -Default (Get-Date -Format "HH:mm")

        if ([string]::IsNullOrWhiteSpace($startTimeStr)) {
            Write-Log "出勤時間の入力がキャンセルされました。終了します。" "WARN"
            exit 0
        }
        $startTime = Validate-Time $startTimeStr
        if ($null -eq $startTime) {
            [System.Windows.Forms.MessageBox]::Show(
                "時刻の形式が正しくありません。`nHH:mm 形式で入力してください（例: 09:00）",
                "入力エラー", 0, 16) | Out-Null
        }
    }

    # --- 予定退勤時間入力 ---
    $plannedEndStr  = ""
    $plannedEndTime = $null
    while ($null -eq $plannedEndTime) {
        $plannedEndStr = Show-InputDialog `
            -Prompt "予定退勤時間を入力してください（例: 18:00）" `
            -Title  "出勤登録" `
            -Default "18:00"

        if ([string]::IsNullOrWhiteSpace($plannedEndStr)) {
            Write-Log "予定退勤時間の入力がキャンセルされました。終了します。" "WARN"
            exit 0
        }
        $plannedEndTime = Validate-Time $plannedEndStr
        if ($null -eq $plannedEndTime) {
            [System.Windows.Forms.MessageBox]::Show(
                "時刻の形式が正しくありません。`nHH:mm 形式で入力してください（例: 18:00）",
                "入力エラー", 0, 16) | Out-Null
        }
    }

    Write-Log "入力受付完了 / 出勤: $startTimeStr / 予定退勤: $plannedEndStr"

    # --- 通知時刻計算（予定退勤の5分前）---
    $today       = Get-Date
    $notifyTime  = $today.Date `
        + [TimeSpan]::FromHours($plannedEndTime.Hour) `
        + [TimeSpan]::FromMinutes($plannedEndTime.Minute) `
        - [TimeSpan]::FromMinutes(5)

    if ($notifyTime -le (Get-Date)) {
        Write-Log "通知予定時刻が過去です。通知タスクは登録しません。" "WARN"
        [System.Windows.Forms.MessageBox]::Show(
            "予定退勤時刻の5分前がすでに過ぎているため、`n退勤通知タスクは登録されませんでした。",
            "注意", 0, 48) | Out-Null
    } else {
        # タスクスケジューラに通知タスクを登録
        Register-NotifyTask `
            -TaskName    $TASK_NAME `
            -NotifyTime  $notifyTime `
            -ScriptBPath $SCRIPT_B_PATH
    }

    # --- CSVログ書き込み ---
    $dateStr = Get-Date -Format "yyyy-MM-dd"
    Write-CsvLog `
        -LogPath        $csvPath `
        -Date           $dateStr `
        -StartTime      $startTimeStr `
        -PlannedEndTime $plannedEndStr

    Write-Log "CSVログへの書き込みが完了しました。"
    Write-Log "=== Script-A 正常終了 ==="

    [System.Windows.Forms.MessageBox]::Show(
        "出勤登録が完了しました。`n`n" +
        "出勤時間　　: $startTimeStr`n" +
        "予定退勤　　: $plannedEndStr`n" +
        "退勤通知予定: $($notifyTime.ToString('HH:mm'))`n`n" +
        "退勤5分前に通知が表示されます。",
        "登録完了", 0, 64) | Out-Null

} catch {
    Write-Log "予期しないエラーが発生しました: $_" "ERROR"
    try {
        Add-Content -Path "$LOCAL_LOG_DIR\script_a_error.log" `
            -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')][ERROR] $_" `
            -Encoding UTF8
    } catch {}
    exit 1
}
