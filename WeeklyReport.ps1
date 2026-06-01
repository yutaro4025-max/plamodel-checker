# =============================================================================
# WeeklyReport.ps1
# 役割    : 週次振り返りHTMLレポート生成
# 実行方式: Script-Aが金曜日のみ退勤60分前に動的登録
# 注意    : 実行前にCONFIGセクションを環境に合わせて変更すること
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms

# =============================================================================
# CONFIG：環境に合わせて変更する箇所
# =============================================================================
# $env:OneDrive を使うことで "OneDrive" / "OneDrive - Honda" 等のフォルダ名差異を吸収する。
# Script-A / Script-B と必ず同じ値になる。
$ONEDRIVE_LOG_DIR  = "$env:OneDrive\AttendanceLogs"
$LOCAL_LOG_DIR     = "$PSScriptRoot\logs"
$LOG_FILENAME      = "attendance_log.csv"
$REPORT_DIR        = "$env:OneDrive\AttendanceLogs\WeeklyReports"
$OUTLOOK_WAIT_SEC  = 30   # Outlook起動待機秒数

# 休憩時間（分）。実際の休憩時間に合わせて変更すること。
# 労働時間 = (実退勤 - 出勤) - BREAK_MIN で計算される。
$BREAK_MIN         = 60

# --- Outlookカテゴリ名（実環境に合わせて変更）---
$CAT_PACKAGING     = "荷姿設定"
$CAT_MEETING       = "社内調整・会議"
$CAT_TROUBLE       = "トラブル・突発"
$CAT_ADMIN         = "管理・事務"
$CAT_LEARNING      = "研修・自己投資"
$CAT_FIXED         = "固定（定例・朝礼）"
$CAT_HOLIDAY       = "有給・休暇"

# --- 閾値設定（時間単位・変更可）---
$TH = @{
    # 残業時間（週合計）
    Overtime_High    = 10   # 警告
    Overtime_Mid     = 5    # 注意
    # 荷姿設定
    Pack_VeryHigh    = 15
    Pack_High        = 10
    Pack_Low         = 5
    # 社内調整・会議
    Meet_VeryHigh    = 12
    Meet_High        = 8
    Meet_Low         = 4
    # トラブル・突発
    Trouble_High     = 4
    Trouble_Mid      = 2
    # 管理・事務
    Admin_VeryHigh   = 10
    Admin_High       = 6
    Admin_Low        = 3
    # 研修・自己投資
    Learn_VeryHigh   = 20
    Learn_High       = 8
    Learn_Mid        = 3
    Learn_Low        = 1
    # 固定（定例・朝礼）平均比較用バッファ（時間）
    Fixed_Buffer     = 2
    # 作業ブロック（非公開予定）
    Block_Low        = 5
    Block_Mid        = 10
}

# --- コメント定義 ---
$COMMENTS = @{
    # 残業
    Overtime_High    = "今週は残業が多い週でした。来週は業務の優先度を絞り、定時退社を意識してみましょう。"
    Overtime_Mid     = "残業はありますが許容範囲内です。引き続き時間管理を意識しましょう。"
    Overtime_Low     = "残業が少なく抑えられた週です。この調子を維持しましょう。"
    Overtime_Zero    = "完全定時退社の週でした。理想的な働き方ができています。"
    # 荷姿設定
    Pack_VeryHigh    = "荷姿設定に集中した週です。会社の集中対応期間であれば問題ありません。他業務への影響がないか確認しましょう。"
    Pack_High        = "荷姿設定への投資が多い週でした。進捗が進んでいれば理想的です。消耗している場合は優先度を見直しましょう。"
    Pack_Mid         = "荷姿設定に適切な時間を使えています。承認フローの滞留がないか確認しましょう。"
    Pack_Low         = "荷姿設定の時間が少ない週でした。来週は意識的に時間を確保しましょう。"
    # 社内調整・会議
    Meet_VeryHigh    = "調整・会議が業務時間の3割を超えています。本来業務への影響が出ていないか振り返りましょう。断れる会議がなかったか確認する価値があります。"
    Meet_High        = "調整・会議が多い週でした。来週は会議を減らし、作業時間の確保を意識しましょう。"
    Meet_Mid         = "調整業務は許容範囲内です。会議の目的と成果を意識して臨みましょう。"
    Meet_Low         = "調整・会議が少なく、作業に集中できた週です。"
    # トラブル・突発
    Trouble_High     = "突発対応が多い週でした。原因の傾向を振り返り、再発防止の手を打ちましょう。"
    Trouble_Mid      = "突発対応がありましたが、ある程度コントロールできています。"
    Trouble_Low      = "突発対応が少ない安定した週でした。計画通り業務を進められています。"
    Trouble_Zero     = "トラブルゼロの週でした。引き続きこの状態を維持しましょう。"
    # 管理・事務
    Admin_VeryHigh   = "管理・事務に多くの時間を使っています。繰り返し作業が多い場合は自動化・テンプレート化を検討しましょう。"
    Admin_High       = "管理・事務作業が多い週でした。作業の効率化や自動化を検討する余地があるかもしれません。"
    Admin_Mid        = "管理・事務の時間は適切な範囲内です。"
    Admin_Low        = "管理・事務の時間が少ない週でした。進捗マスターの更新漏れがないか確認しましょう。"
    # 研修・自己投資
    Learn_VeryHigh   = "研修・講習メインの週だったようです。会社指定の研修であれば問題ありません。自己研鑽が中心であれば、業務とのバランスを確認しましょう。"
    Learn_High       = "自己投資にかなりの時間を使っています。学びの時間が業務を圧迫していないか確認しましょう。"
    Learn_Mid        = "自己投資に時間を使えた週です。学んだことを業務に活かしましょう。"
    Learn_Low        = "自己投資の時間を確保できています。継続することが大切です。"
    Learn_VeryLow    = "自己投資の時間が少ない週でした。来週は意識的に時間を作ってみましょう。"
    Learn_Zero       = "今週は自己投資の時間がありませんでした。忙しい週でも少しの時間を確保できると理想的です。"
    # 固定（定例・朝礼）
    Fixed_High       = "定例イベントが多い週でした。その分、自由に使える時間が少なかった週です。"
    Fixed_Normal     = "定例イベントは通常通りでした。"
    Fixed_Low        = "定例イベントが少ない週でした。有給や出張の影響があった可能性があります。"
    # 有給・休暇
    Holiday_Full     = "有給取得の週でした。しっかりリフレッシュできましたか。"
    Holiday_Half     = "半日休暇を取得した週です。メリハリのある働き方ができています。"
    Holiday_None     = "今週は休暇なしでした。疲れが溜まっていないか確認しましょう。"
    # 作業ブロック
    Block_Low        = "集中作業時間が少ない週でした。来週は早めにカレンダーをブロックしましょう。"
    Block_Mid        = "作業時間はある程度確保できています。引き続き意識的にブロックを入れましょう。"
    Block_High       = "集中作業時間をしっかり確保できた週です。計画的な時間管理ができています。"
}
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
    Add-Content -Path "$LOCAL_LOG_DIR\weekly_report.log" -Value $line -Encoding UTF8
}

# --- Outlook起動チェック・自動起動 -------------------------------------------
function Ensure-Outlook {
    $proc = Get-Process -Name "OUTLOOK" -ErrorAction SilentlyContinue
    if ($null -eq $proc) {
        Write-Log "Outlookが起動していません。自動起動します。"
        Start-Process "outlook.exe"
        Write-Log "Outlook起動待機中（${OUTLOOK_WAIT_SEC}秒）..."
        Start-Sleep -Seconds $OUTLOOK_WAIT_SEC
        $proc = Get-Process -Name "OUTLOOK" -ErrorAction SilentlyContinue
        if ($null -eq $proc) {
            throw "Outlookの起動に失敗しました。Outlookがインストールされているか確認してください。"
        }
        Write-Log "Outlookの起動を確認しました。"
    } else {
        Write-Log "Outlookは起動済みです。"
    }
}

# --- 今週の月曜〜金曜を取得 --------------------------------------------------
function Get-WeekRange {
    $today   = Get-Date
    $monday  = $today.AddDays(-([int]$today.DayOfWeek - 1))
    $friday  = $monday.AddDays(4)
    return @{
        Start = $monday.Date
        End   = $friday.Date.AddDays(1).AddSeconds(-1)
        Label = "$($monday.ToString('yyyy/MM/dd')) 〜 $($friday.ToString('yyyy/MM/dd'))"
    }
}

# --- 退勤ログCSV 読み込み -----------------------------------------------------
function Get-AttendanceData {
    param([hashtable]$WeekRange)

    $csvPath = Join-Path $ONEDRIVE_LOG_DIR $LOG_FILENAME
    if (-not (Test-Path $csvPath)) {
        Write-Log "退勤ログCSVが見つかりません: $csvPath" "WARN"
        return $null
    }

    $rows = Import-Csv -Path $csvPath -Encoding UTF8
    # @() で囲み、1件マッチ時でも配列として扱われるようにする（Set-StrictMode 対策）
    $weekRows = @($rows | Where-Object {
        $d = [datetime]::ParseExact($_.Date, "yyyy-MM-dd", $null)
        $d -ge $WeekRange.Start -and $d -le $WeekRange.End
    })

    if ($weekRows.Count -eq 0) {
        Write-Log "今週の退勤ログが存在しません。" "WARN"
        return $null
    }

    $totalWorkMin     = 0
    $totalOvertimeMin = 0
    $latestEnd        = $null
    $latestEndDate    = ""
    $workDetails      = @()

    foreach ($row in $weekRows) {
        if ([string]::IsNullOrWhiteSpace($row.StartTime) -or
            [string]::IsNullOrWhiteSpace($row.PlannedEndTime)) { continue }

        $start   = [datetime]::ParseExact($row.Date + " " + $row.StartTime,      "yyyy-MM-dd HH:mm", $null)
        $planned = [datetime]::ParseExact($row.Date + " " + $row.PlannedEndTime, "yyyy-MM-dd HH:mm", $null)

        $actualEnd = $planned
        if (-not [string]::IsNullOrWhiteSpace($row.ActualEndTime)) {
            $actualEnd = [datetime]::ParseExact($row.Date + " " + $row.ActualEndTime, "yyyy-MM-dd HH:mm", $null)
        }

        # Fix: 在籍時間から休憩時間（$BREAK_MIN）を差し引いて実働時間を算出する。
        # 以前は休憩を含む在籍時間をそのまま使っていたため労働時間が多く表示されていた。
        $rawMin      = ($actualEnd - $start).TotalMinutes
        $workMin     = [Math]::Max(0, $rawMin - $BREAK_MIN)
        $overtimeMin = [Math]::Max(0, ($actualEnd - $planned).TotalMinutes)

        $totalWorkMin     += $workMin
        $totalOvertimeMin += $overtimeMin

        if ($null -eq $latestEnd -or $actualEnd -gt $latestEnd) {
            $latestEnd     = $actualEnd
            $latestEndDate = $row.Date
        }

        $workDetails += @{
            Date        = $row.Date
            Start       = $row.StartTime
            Planned     = $row.PlannedEndTime
            Actual      = if ([string]::IsNullOrWhiteSpace($row.ActualEndTime)) { $row.PlannedEndTime } else { $row.ActualEndTime }
            WorkMin     = [Math]::Round($workMin)
            OvertimeMin = [Math]::Round($overtimeMin)
        }
    }

    $avgEndTime = ""
    if ($workDetails.Count -gt 0) {
        # Measure-Object -Property はスクリプトブロック非対応（PS 5.1）のため
        # ForEach-Object で計算値に変換してから Average を取る
        $avgEndMin = ($workDetails | ForEach-Object {
            [int]($_.Actual.Split(":")[0]) * 60 + [int]($_.Actual.Split(":")[1])
        } | Measure-Object -Average).Average
        $avgEndTime = "{0:D2}:{1:D2}" -f [int]($avgEndMin / 60), [int]($avgEndMin % 60)
    }

    return @{
        WorkDays          = $weekRows.Count
        TotalWorkHour     = [Math]::Round($totalWorkMin / 60, 1)
        TotalOvertimeHour = [Math]::Round($totalOvertimeMin / 60, 1)
        AvgEndTime        = $avgEndTime
        LatestEndDate     = $latestEndDate
        LatestEndTime     = if ($null -ne $latestEnd) { $latestEnd.ToString("HH:mm") } else { "-" }
        Details           = $workDetails
    }
}

# --- Outlookカレンダー読み込み ------------------------------------------------
function Get-OutlookData {
    param([hashtable]$WeekRange)

    try {
        $outlook   = [System.Runtime.InteropServices.Marshal]::GetActiveObject("Outlook.Application")
        $namespace = $outlook.GetNamespace("MAPI")
        $calendar  = $namespace.GetDefaultFolder(9)  # olFolderCalendar
        $items     = $calendar.Items
        $items.IncludeRecurrences = $true
        $items.Sort("[Start]")

        $startStr = $WeekRange.Start.ToString("yyyy/MM/dd HH:mm")
        $endStr   = $WeekRange.End.ToString("yyyy/MM/dd HH:mm")
        $filter   = "[Start] >= '$startStr' AND [End] <= '$endStr'"
        $filtered = $items.Restrict($filter)

        $catHours  = @{}
        $catEvents = @{}   # カテゴリ別イベント詳細（TOP3表示用）
        $blockMin  = 0

        foreach ($item in $filtered) {
            try {
                $durationMin = ($item.End - $item.Start).TotalMinutes
                $cat = $item.Categories
                if ([string]::IsNullOrWhiteSpace($cat)) { $cat = "未分類" }

                # 複数カテゴリ対応（カンマ区切り）
                $cats = $cat -split "," | ForEach-Object { $_.Trim() }
                foreach ($c in $cats) {
                    # カテゴリ別合計時間
                    if (-not $catHours.ContainsKey($c)) { $catHours[$c] = 0 }
                    $catHours[$c] += $durationMin

                    # カテゴリ別イベント詳細を収集
                    if (-not $catEvents.ContainsKey($c)) { $catEvents[$c] = @() }
                    $subj = if ([string]::IsNullOrWhiteSpace($item.Subject)) { "（件名なし）" } else { $item.Subject }
                    $catEvents[$c] += @{
                        Subject     = $subj
                        StartTime   = $item.Start.ToString("MM/dd HH:mm")
                        DurationMin = [Math]::Round($durationMin)
                    }
                }

                # 非公開予定＝作業ブロック
                if ($item.Sensitivity -eq 2) {
                    $blockMin += $durationMin
                }
            } catch {}
        }

        # カテゴリ別時間（時間単位に変換）＋イベント詳細を返す
        $result = @{
            BlockHour = [Math]::Round($blockMin / 60, 1)
            Events    = $catEvents
        }
        foreach ($key in $catHours.Keys) {
            $result[$key] = [Math]::Round($catHours[$key] / 60, 1)
        }
        return $result

    } catch {
        Write-Log "Outlookカレンダーの読み込みに失敗しました: $_" "WARN"
        return $null
    }
}

# --- コメント判定 -------------------------------------------------------------
function Get-Comment {
    param([string]$Key, [double]$Value, [double]$Avg = 0)
    switch ($Key) {
        "Overtime" {
            if ($Value -eq 0)                        { return $COMMENTS.Overtime_Zero }
            elseif ($Value -lt $TH.Overtime_Mid)     { return $COMMENTS.Overtime_Low }
            elseif ($Value -lt $TH.Overtime_High)    { return $COMMENTS.Overtime_Mid }
            else                                     { return $COMMENTS.Overtime_High }
        }
        "Pack" {
            if ($Value -gt $TH.Pack_VeryHigh)        { return $COMMENTS.Pack_VeryHigh }
            elseif ($Value -gt $TH.Pack_High)        { return $COMMENTS.Pack_High }
            elseif ($Value -gt $TH.Pack_Low)         { return $COMMENTS.Pack_Mid }
            else                                     { return $COMMENTS.Pack_Low }
        }
        "Meet" {
            if ($Value -gt $TH.Meet_VeryHigh)        { return $COMMENTS.Meet_VeryHigh }
            elseif ($Value -gt $TH.Meet_High)        { return $COMMENTS.Meet_High }
            elseif ($Value -gt $TH.Meet_Low)         { return $COMMENTS.Meet_Mid }
            else                                     { return $COMMENTS.Meet_Low }
        }
        "Trouble" {
            if ($Value -eq 0)                        { return $COMMENTS.Trouble_Zero }
            elseif ($Value -lt $TH.Trouble_Mid)      { return $COMMENTS.Trouble_Low }
            elseif ($Value -lt $TH.Trouble_High)     { return $COMMENTS.Trouble_Mid }
            else                                     { return $COMMENTS.Trouble_High }
        }
        "Admin" {
            if ($Value -gt $TH.Admin_VeryHigh)       { return $COMMENTS.Admin_VeryHigh }
            elseif ($Value -gt $TH.Admin_High)       { return $COMMENTS.Admin_High }
            elseif ($Value -gt $TH.Admin_Low)        { return $COMMENTS.Admin_Mid }
            else                                     { return $COMMENTS.Admin_Low }
        }
        "Learn" {
            if ($Value -gt $TH.Learn_VeryHigh)       { return $COMMENTS.Learn_VeryHigh }
            elseif ($Value -gt $TH.Learn_High)       { return $COMMENTS.Learn_High }
            elseif ($Value -gt $TH.Learn_Mid)        { return $COMMENTS.Learn_Mid }
            elseif ($Value -gt $TH.Learn_Low)        { return $COMMENTS.Learn_Low }
            elseif ($Value -gt 0)                    { return $COMMENTS.Learn_VeryLow }
            else                                     { return $COMMENTS.Learn_Zero }
        }
        "Fixed" {
            if ($Value -gt ($Avg + $TH.Fixed_Buffer))     { return $COMMENTS.Fixed_High }
            elseif ($Value -lt ($Avg - $TH.Fixed_Buffer)) { return $COMMENTS.Fixed_Low }
            else                                          { return $COMMENTS.Fixed_Normal }
        }
        "Holiday" {
            if ($Value -ge 8)    { return $COMMENTS.Holiday_Full }
            elseif ($Value -gt 0){ return $COMMENTS.Holiday_Half }
            else                 { return $COMMENTS.Holiday_None }
        }
        "Block" {
            if ($Value -lt $TH.Block_Low)            { return $COMMENTS.Block_Low }
            elseif ($Value -lt $TH.Block_Mid)        { return $COMMENTS.Block_Mid }
            else                                     { return $COMMENTS.Block_High }
        }
    }
    return ""
}

# --- 翌週メモ入力ダイアログ --------------------------------------------------
function Show-NextWeekMemo {
    $form = New-Object System.Windows.Forms.Form
    $form.Text            = "翌週やること・メモ"
    $form.Size            = New-Object System.Drawing.Size(500, 320)
    $form.StartPosition   = "CenterScreen"
    $form.TopMost         = $true
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox     = $false

    Add-Type -AssemblyName System.Drawing

    $label = New-Object System.Windows.Forms.Label
    $label.Text     = "来週やることや引き継ぎメモを入力してください："
    $label.Location = New-Object System.Drawing.Point(16, 16)
    $label.Size     = New-Object System.Drawing.Size(460, 24)
    $label.Font     = New-Object System.Drawing.Font("Meiryo UI", 10)
    $form.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Multiline  = $true
    $textBox.ScrollBars = "Vertical"
    $textBox.Location   = New-Object System.Drawing.Point(16, 48)
    $textBox.Size       = New-Object System.Drawing.Size(460, 180)
    $textBox.Font       = New-Object System.Drawing.Font("Meiryo UI", 10)
    $form.Controls.Add($textBox)

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text         = "レポートに追加"
    $btn.Location     = New-Object System.Drawing.Point(170, 244)
    $btn.Size         = New-Object System.Drawing.Size(160, 36)
    $btn.Font         = New-Object System.Drawing.Font("Meiryo UI", 10)
    $btn.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($btn)
    $form.AcceptButton = $btn

    $result = $form.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $textBox.Text
    }
    return ""
}

# --- HTMLレポート生成 ---------------------------------------------------------
function Build-HtmlReport {
    param(
        [hashtable]$WeekRange,
        [hashtable]$Attendance,
        [hashtable]$OutlookData,
        [string]$NextWeekMemo
    )

    # カテゴリ別時間取得ヘルパー
    function Get-CatHour([string]$CatName) {
        if ($null -ne $OutlookData -and $OutlookData.ContainsKey($CatName)) {
            return $OutlookData[$CatName]
        }
        return 0.0
    }

    # カテゴリ別 TOP3 イベントの HTML 生成ヘルパー
    # 同じ件名のイベントは合算して1件として扱う（複製登録の癖に対応）
    function Get-Top3Html([string]$CatName) {
        if ($null -eq $OutlookData) { return "" }
        if (-not $OutlookData.ContainsKey("Events")) { return "" }
        $eventsMap = $OutlookData["Events"]
        if (-not $eventsMap.ContainsKey($CatName)) { return "" }
        $evList = @($eventsMap[$CatName])
        if ($evList.Count -eq 0) { return "" }

        # 件名でグループ化して所要時間を合算する
        $grouped = @{}
        foreach ($ev in $evList) {
            $key = $ev.Subject
            if (-not $grouped.ContainsKey($key)) {
                $grouped[$key] = @{ Subject = $key; DurationMin = 0; Count = 0 }
            }
            $grouped[$key].DurationMin += $ev.DurationMin
            $grouped[$key].Count       += 1
        }

        # 合算後の所要時間降順で上位3件を取得
        $top3 = @($grouped.Values | Sort-Object { $_.DurationMin } -Descending | Select-Object -First 3)
        $items = $top3 | ForEach-Object {
            $h    = [Math]::Round($_.DurationMin / 60, 1)
            $subj = [System.Web.HttpUtility]::HtmlEncode($_.Subject)
            $cnt  = if ($_.Count -gt 1) { "<span class='ev-meta'>×$($_.Count)件・計</span>" } else { "" }
            "<li><span class='ev-name'>$subj</span>$cnt<span class='ev-meta'>${h}h</span></li>"
        }
        $listHtml = $items -join ""
        return "<div class='top-events'><span class='top-label'>▶ 主なイベント TOP$($top3.Count)</span><ol class='event-list'>$listHtml</ol></div>"
    }

    $packH    = Get-CatHour $CAT_PACKAGING
    $meetH    = Get-CatHour $CAT_MEETING
    $troubleH = Get-CatHour $CAT_TROUBLE
    $adminH   = Get-CatHour $CAT_ADMIN
    $learnH   = Get-CatHour $CAT_LEARNING
    $fixedH   = Get-CatHour $CAT_FIXED
    $holidayH = Get-CatHour $CAT_HOLIDAY
    $blockH   = if ($null -ne $OutlookData) { $OutlookData.BlockHour } else { 0.0 }

    $overtimeH = if ($null -ne $Attendance) { $Attendance.TotalOvertimeHour } else { 0.0 }
    $workDays  = if ($null -ne $Attendance) { $Attendance.WorkDays } else { 0 }
    $workH     = if ($null -ne $Attendance) { $Attendance.TotalWorkHour } else { 0.0 }
    $avgEnd    = if ($null -ne $Attendance) { $Attendance.AvgEndTime } else { "-" }
    $lateDate  = if ($null -ne $Attendance) { $Attendance.LatestEndDate } else { "-" }
    $lateTime  = if ($null -ne $Attendance) { $Attendance.LatestEndTime } else { "-" }

    # コメント取得
    $cmtOvertime = Get-Comment "Overtime" $overtimeH
    $cmtPack     = Get-Comment "Pack"     $packH
    $cmtMeet     = Get-Comment "Meet"     $meetH
    $cmtTrouble  = Get-Comment "Trouble"  $troubleH
    $cmtAdmin    = Get-Comment "Admin"    $adminH
    $cmtLearn    = Get-Comment "Learn"    $learnH
    $cmtFixed    = Get-Comment "Fixed"    $fixedH   2.0
    $cmtHoliday  = Get-Comment "Holiday"  $holidayH
    $cmtBlock    = Get-Comment "Block"    $blockH

    # 日別棒グラフ用データ
    $barData = ""
    if ($null -ne $Attendance -and $Attendance.Details.Count -gt 0) {
        foreach ($d in $Attendance.Details) {
            $barData += "<div class='bar-row'>"
            $barData += "<span class='bar-label'>$($d.Date.Substring(5))</span>"
            $barData += "<div class='bar-wrap'>"
            $barPct = [Math]::Min(100, [Math]::Round($d.WorkMin / 480 * 100))  # 8h = 480min 基準
            $ovPct  = [Math]::Min(100, [Math]::Round($d.OvertimeMin / 480 * 100))
            $barData += "<div class='bar-work' style='width:${barPct}%'></div>"
            if ($ovPct -gt 0) {
                $barData += "<div class='bar-over' style='width:${ovPct}%'></div>"
            }
            $barData += "</div>"
            $barData += "<span class='bar-val'>$([Math]::Round($d.WorkMin/60,1))h"
            if ($d.OvertimeMin -gt 0) { $barData += " (+$([Math]::Round($d.OvertimeMin/60,1))h)" }
            $barData += "</span></div>"
        }
    } else {
        $barData = "<p style='color:#9da3b4;font-size:13px;'>退勤ログデータがありません。</p>"
    }

    # カテゴリ行ヘルパー（TOP3 HTML を受け取り comment セルに埋め込む）
    function Cat-Row([string]$icon, [string]$name, [double]$h, [string]$cmt, [string]$top3 = "") {
        return "<tr><td>$icon $name</td><td class='td-num'>${h}h</td><td class='td-cmt'>$cmt$top3</td></tr>"
    }

    $memoHtml = if ([string]::IsNullOrWhiteSpace($NextWeekMemo)) {
        "<p style='color:#9da3b4;font-size:13px;'>入力なし</p>"
    } else {
        "<p style='white-space:pre-wrap;font-size:14px;color:#e8eaf0;line-height:1.7;'>$([System.Web.HttpUtility]::HtmlEncode($NextWeekMemo))</p>"
    }

    $reportDate  = Get-Date -Format "yyyy年MM月dd日 HH:mm"
    $weekNum     = (Get-Date -UFormat "%V")
    $breakHLabel = [Math]::Round($BREAK_MIN / 60, 1)

    return @"
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>週次振り返りレポート Week$weekNum</title>
<style>
:root{--bg:#0f1117;--bg2:#181c27;--bg3:#1e2336;--border:rgba(255,255,255,0.08);--border2:rgba(255,255,255,0.15);--text:#e8eaf0;--text2:#9da3b4;--accent:#4f9cf9;--accent2:#38d9a9;--accent3:#f77f4f;--warn:#f5c842;--danger:#f87171;--radius:12px;}
*{box-sizing:border-box;margin:0;padding:0;}
body{background:var(--bg);color:var(--text);font-family:'Segoe UI','Meiryo UI','Yu Gothic UI',sans-serif;font-size:15px;line-height:1.75;padding:32px 24px 64px;}
.container{max-width:860px;margin:0 auto;}
.hero{text-align:center;padding:32px 0 24px;border-bottom:1px solid var(--border);margin-bottom:32px;}
.hero h1{font-size:26px;font-weight:700;color:#fff;margin-bottom:6px;}
.hero-sub{font-size:14px;color:var(--text2);}
.section{margin-bottom:40px;}
.section-title{font-size:16px;font-weight:600;color:#fff;padding-bottom:10px;border-bottom:1px solid var(--border);margin-bottom:16px;display:flex;align-items:center;gap:8px;}
.card{background:var(--bg2);border:1px solid var(--border);border-radius:var(--radius);padding:16px 20px;margin-bottom:12px;}
.metrics{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin-bottom:16px;}
.metric{background:var(--bg3);border-radius:8px;padding:14px 16px;}
.metric-label{font-size:12px;color:var(--text2);margin-bottom:4px;}
.metric-value{font-size:22px;font-weight:600;color:#fff;}
.metric-value.warn{color:var(--warn);}
.metric-value.danger{color:var(--danger);}
.metric-value.ok{color:var(--accent2);}
.bar-row{display:flex;align-items:center;gap:10px;margin-bottom:8px;}
.bar-label{font-size:12px;color:var(--text2);width:44px;flex-shrink:0;}
.bar-wrap{flex:1;height:16px;background:var(--bg3);border-radius:4px;overflow:hidden;display:flex;}
.bar-work{background:var(--accent);height:100%;border-radius:4px;transition:width 0.3s;}
.bar-over{background:var(--danger);height:100%;margin-left:2px;border-radius:4px;}
.bar-val{font-size:12px;color:var(--text2);white-space:nowrap;min-width:80px;}
table{width:100%;border-collapse:collapse;font-size:13px;}
th{text-align:left;padding:8px 12px;background:var(--bg3);color:var(--text2);font-weight:600;border-bottom:1px solid var(--border2);font-size:12px;}
td{padding:10px 12px;border-bottom:1px solid var(--border);vertical-align:top;}
.td-num{color:var(--accent);font-weight:600;white-space:nowrap;width:60px;}
.td-cmt{color:var(--text2);font-size:13px;line-height:1.6;}
.comment-box{background:rgba(79,156,249,0.08);border:1px solid rgba(79,156,249,0.25);border-radius:8px;padding:12px 16px;font-size:14px;color:#93bff7;margin-top:10px;}
.footer{text-align:center;color:var(--text2);font-size:12px;margin-top:48px;padding-top:24px;border-top:1px solid var(--border);}
.top-events{margin-top:8px;padding-top:6px;border-top:1px solid var(--border);}
.top-label{font-size:11px;color:var(--text2);font-weight:600;letter-spacing:0.03em;}
.event-list{margin:4px 0 0 18px;font-size:12px;color:var(--text2);line-height:1.9;}
.ev-name{margin-right:6px;}
.ev-meta{color:#6b7280;font-size:11px;}
.note-box{font-size:11px;color:#6b7280;margin-top:6px;padding:4px 8px;border-left:2px solid var(--border2);}
</style>
</head>
<body>
<div class="container">

<div class="hero">
  <h1>📊 週次振り返りレポート Week$weekNum</h1>
  <div class="hero-sub">$($WeekRange.Label)　|　生成日時：$reportDate</div>
</div>

<!-- 勤怠サマリー -->
<div class="section">
  <div class="section-title">⏱️ 今週の勤怠サマリー</div>
  <div class="metrics">
    <div class="metric"><div class="metric-label">出勤日数</div><div class="metric-value">${workDays}日</div></div>
    <div class="metric"><div class="metric-label">実働時間（休憩${breakHLabel}h除く）</div><div class="metric-value">${workH}h</div></div>
    <div class="metric"><div class="metric-label">残業時間合計</div><div class="metric-value $(if($overtimeH -ge $TH.Overtime_High){'danger'}elseif($overtimeH -ge $TH.Overtime_Mid){'warn'}else{'ok'})">${overtimeH}h</div></div>
    <div class="metric"><div class="metric-label">平均退勤時刻</div><div class="metric-value">$avgEnd</div></div>
    <div class="metric"><div class="metric-label">最遅退勤</div><div class="metric-value">$lateTime</div></div>
  </div>
  <div class="comment-box">💬 $cmtOvertime</div>
</div>

<!-- 日別労働時間 -->
<div class="section">
  <div class="section-title">📅 日別労働時間</div>
  <div class="card">
    $barData
    <div style="font-size:11px;color:var(--text2);margin-top:10px;">■ 通常時間　■ 残業時間（予定退勤超過分）　※ バー幅は8h基準</div>
  </div>
</div>

<!-- カテゴリ別時間 -->
<div class="section">
  <div class="section-title">🗂️ カテゴリ別時間内訳</div>
  <div class="card">
    <table>
      <tr><th>カテゴリ</th><th>時間</th><th>コメント / 主なイベント TOP3</th></tr>
      $(Cat-Row "📦" $CAT_PACKAGING  $packH    $cmtPack    (Get-Top3Html $CAT_PACKAGING))
      $(Cat-Row "🤝" $CAT_MEETING   $meetH    $cmtMeet    (Get-Top3Html $CAT_MEETING))
      $(Cat-Row "🚨" $CAT_TROUBLE   $troubleH $cmtTrouble (Get-Top3Html $CAT_TROUBLE))
      $(Cat-Row "📋" $CAT_ADMIN     $adminH   $cmtAdmin   (Get-Top3Html $CAT_ADMIN))
      $(Cat-Row "📚" $CAT_LEARNING  $learnH   $cmtLearn   (Get-Top3Html $CAT_LEARNING))
      $(Cat-Row "🔁" $CAT_FIXED     $fixedH   $cmtFixed   (Get-Top3Html $CAT_FIXED))
      $(Cat-Row "🏖️" $CAT_HOLIDAY   $holidayH $cmtHoliday (Get-Top3Html $CAT_HOLIDAY))
    </table>
    <div class="note-box">※ カレンダー予定は重複登録があるため、カテゴリ合計が実働時間を超える場合があります。</div>
  </div>
</div>

<!-- 集中作業時間 -->
<div class="section">
  <div class="section-title">🔒 集中作業時間（カレンダーブロック）</div>
  <div class="metrics">
    <div class="metric"><div class="metric-label">作業ブロック時間</div><div class="metric-value $(if($blockH -lt $TH.Block_Low){'warn'}else{'ok'})">${blockH}h</div></div>
  </div>
  <div class="comment-box">💬 $cmtBlock</div>
</div>

<!-- 翌週メモ -->
<div class="section">
  <div class="section-title">📝 翌週やること・メモ</div>
  <div class="card">$memoHtml</div>
</div>

<div class="footer">週次振り返りレポート　|　自動生成　|　レビュー前提で参照してください</div>
</div>
</body>
</html>
"@
}

# =============================================================================
# メイン処理
# =============================================================================
try {
    Write-Log "=== WeeklyReport 開始 ==="

    # フォルダ確認
    if (-not (Test-Path $REPORT_DIR)) {
        New-Item -ItemType Directory -Path $REPORT_DIR -Force | Out-Null
        Write-Log "レポートフォルダを作成しました: $REPORT_DIR"
    }

    # 今週の範囲取得
    $weekRange = Get-WeekRange
    Write-Log "対象週: $($weekRange.Label)"

    # Outlook起動確認
    Ensure-Outlook

    # データ取得
    Write-Log "退勤ログを読み込みます。"
    $attendance = Get-AttendanceData -WeekRange $weekRange

    Write-Log "Outlookカレンダーを読み込みます。"
    $outlookData = Get-OutlookData -WeekRange $weekRange

    # 翌週メモ入力
    Write-Log "翌週メモ入力ダイアログを表示します。"
    $nextWeekMemo = Show-NextWeekMemo

    # HTMLレポート生成
    Write-Log "HTMLレポートを生成します。"
    Add-Type -AssemblyName System.Web
    $html = Build-HtmlReport `
        -WeekRange    $weekRange `
        -Attendance   $attendance `
        -OutlookData  $outlookData `
        -NextWeekMemo $nextWeekMemo

    # 保存
    $weekNum    = (Get-Date -UFormat "%V")
    $reportName = "WeeklyReport_$(Get-Date -Format 'yyyy')_Week$weekNum.html"
    $reportPath = Join-Path $REPORT_DIR $reportName
    Set-Content -Path $reportPath -Value $html -Encoding UTF8

    Write-Log "レポートを保存しました: $reportPath"
    Write-Log "=== WeeklyReport 正常終了 ==="

    # ブラウザで開く
    Start-Process $reportPath

} catch {
    Write-Log "予期しないエラーが発生しました: $_" "ERROR"
    try {
        Add-Content -Path "$LOCAL_LOG_DIR\weekly_report_error.log" `
            -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')][ERROR] $_" `
            -Encoding UTF8
    } catch {}
    exit 1
}
