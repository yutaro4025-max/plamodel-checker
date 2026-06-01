# =============================================================================
# Script-B_Notify.ps1
# 役割    : 退勤5分前通知・実退勤時刻記録・動的タスク自己削除
# 実行方式: Script-A が登録したタスクスケジューラから起動
# 注意    : 実行前にパス設定（CONFIG セクション）を環境に合わせて変更すること
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# =============================================================================
# CONFIG：Script-A と同じ値にすること
# =============================================================================
# Fix(Bug3): $env:OneDrive を使うことで "OneDrive" / "OneDrive - Honda" 等の
#            フォルダ名差異を吸収する。Script-A と必ず同じ値になる。
$ONEDRIVE_LOG_DIR = "$env:OneDrive\AttendanceLogs"
$LOCAL_LOG_DIR    = "$PSScriptRoot\logs"
$LOG_FILENAME     = "attendance_log.csv"
$TASK_NAME_PREFIX = "AttendanceNotify_"   # Script-A と合わせること
# =============================================================================

# --- ログ関数 -----------------------------------------------------------------
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp][$Level] $Message"
    Write-Host $line
    if (-not (Test-Path $LOCAL_LOG_DIR)) {
        New-Item -ItemType Directory -Path $LOCAL_LOG_DIR -Force | Out-Null
    }
    Add-Content -Path "$LOCAL_LOG_DIR\script_b.log" -Value $line -Encoding UTF8
}

# --- 大きめメッセージボックス（カスタムフォーム）-----------------------------
function Show-LargeNotification {
    param(
        [string]$Message,
        [string]$Title
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text            = $Title
    $form.Size            = New-Object System.Drawing.Size(520, 320)
    $form.StartPosition   = "CenterScreen"
    $form.TopMost         = $true
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox     = $false
    $form.MinimizeBox     = $false
    $form.BackColor       = [System.Drawing.Color]::FromArgb(245, 245, 245)

    # アイコンラベル
    $iconLabel = New-Object System.Windows.Forms.Label
    $iconLabel.Text      = "🔔"
    $iconLabel.Font      = New-Object System.Drawing.Font("Segoe UI Emoji", 36)
    $iconLabel.Location  = New-Object System.Drawing.Point(30, 30)
    $iconLabel.Size      = New-Object System.Drawing.Size(70, 70)
    $form.Controls.Add($iconLabel)

    # タイトルラベル
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text      = $Title
    $titleLabel.Font      = New-Object System.Drawing.Font("Meiryo UI", 14, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Location  = New-Object System.Drawing.Point(110, 35)
    $titleLabel.Size      = New-Object System.Drawing.Size(380, 35)
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $form.Controls.Add($titleLabel)

    # 本文ラベル
    $msgLabel = New-Object System.Windows.Forms.Label
    $msgLabel.Text      = $Message
    $msgLabel.Font      = New-Object System.Drawing.Font("Meiryo UI", 11)
    $msgLabel.Location  = New-Object System.Drawing.Point(30, 115)
    $msgLabel.Size      = New-Object System.Drawing.Size(460, 110)
    $msgLabel.ForeColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
    $form.Controls.Add($msgLabel)

    # 退勤ボタン
    $btnLeave = New-Object System.Windows.Forms.Button
    $btnLeave.Text      = "✅  退勤しました"
    $btnLeave.Font      = New-Object System.Drawing.Font("Meiryo UI", 12, [System.Drawing.FontStyle]::Bold)
    $btnLeave.Size      = New-Object System.Drawing.Size(200, 50)
    $btnLeave.Location  = New-Object System.Drawing.Point(155, 230)
    $btnLeave.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $btnLeave.ForeColor = [System.Drawing.Color]::White
    $btnLeave.FlatStyle = "Flat"
    $btnLeave.FlatAppearance.BorderSize = 0
    $btnLeave.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($btnLeave)
    $form.AcceptButton = $btnLeave

    $result = $form.ShowDialog()
    return $result
}

# --- CSVログ更新（本日行に NotifiedAt・ActualEndTime を追記）-----------------
function Update-CsvLog {
    param(
        [string]$LogPath,
        [string]$NotifiedAt,
        [string]$ActualEndTime
    )
    if (-not (Test-Path $LogPath)) {
        throw "CSVログが見つかりません: $LogPath"
    }

    $today   = Get-Date -Format "yyyy-MM-dd"
    $content = Get-Content $LogPath -Encoding UTF8
    $updated = $false
    $newContent = @()

    foreach ($line in $content) {
        if ($line.StartsWith($today)) {
            # CSV列: Date,StartTime,PlannedEndTime,NotifiedAt,ActualEndTime
            $cols = $line -split ","
            if ($cols.Count -ge 3) {
                $cols[3] = $NotifiedAt
                $cols[4] = $ActualEndTime
                $newContent += ($cols -join ",")
                $updated = $true
                continue
            }
        }
        $newContent += $line
    }

    if (-not $updated) {
        throw "本日分のログ行が見つかりませんでした。"
    }

    Set-Content -Path $LogPath -Value $newContent -Encoding UTF8
}

# --- 動的登録タスクの自己削除 -------------------------------------------------
function Remove-NotifyTask {
    param([string]$TaskName)
    # Fix(Bug2): schtasks CLI から Register-ScheduledTask 系コマンドレットに統一。
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Log "通知タスクを削除しました: $TaskName"
    } else {
        Write-Log "削除対象タスクが見つかりませんでした（既に削除済みの可能性）: $TaskName" "WARN"
    }
}

# =============================================================================
# メイン処理
# =============================================================================
try {
    Write-Log "=== Script-B 開始 ==="

    $csvPath    = Join-Path $ONEDRIVE_LOG_DIR $LOG_FILENAME
    $notifiedAt = Get-Date -Format "HH:mm"
    $taskName   = "$TASK_NAME_PREFIX$(Get-Date -Format 'yyyyMMdd')"

    # --- 大きめ通知ダイアログ表示 ---
    $today          = Get-Date -Format "yyyy-MM-dd"
    $plannedEndTime = ""

    # CSVから予定退勤時間を取得して通知文に含める
    if (Test-Path $csvPath) {
        $lines = Get-Content $csvPath -Encoding UTF8
        foreach ($line in $lines) {
            if ($line.StartsWith($today)) {
                $cols = $line -split ","
                if ($cols.Count -ge 3) { $plannedEndTime = $cols[2] }
                break
            }
        }
    }

    $notifyMessage = "予定退勤時刻まで あと5分 です。`n`n" +
                     "予定退勤時刻　: $plannedEndTime`n" +
                     "通知発火時刻　: $notifiedAt`n`n" +
                     "退勤の準備を始めてください。`n退勤したら下のボタンを押してください。"

    Write-Log "通知ダイアログを表示します。"
    $dialogResult = Show-LargeNotification `
        -Message $notifyMessage `
        -Title   "退勤準備リマインダー"

    # --- 退勤ボタン押下後の処理 ---
    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
        $actualEndTime = Get-Date -Format "HH:mm"
        Write-Log "退勤ボタンが押されました。実退勤時刻: $actualEndTime"

        Update-CsvLog `
            -LogPath       $csvPath `
            -NotifiedAt    $notifiedAt `
            -ActualEndTime $actualEndTime

        Write-Log "CSVログを更新しました（NotifiedAt: $notifiedAt / ActualEndTime: $actualEndTime）"
    } else {
        Write-Log "ダイアログが閉じられました（退勤ボタン未押下）。ログ更新はスキップします。" "WARN"
    }

    # --- 動的タスクの自己削除 ---
    Remove-NotifyTask -TaskName $taskName

    Write-Log "=== Script-B 正常終了 ==="

} catch {
    Write-Log "予期しないエラーが発生しました: $_" "ERROR"
    try {
        Add-Content -Path "$LOCAL_LOG_DIR\script_b_error.log" `
            -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')][ERROR] $_" `
            -Encoding UTF8
    } catch {}
    exit 1
}
