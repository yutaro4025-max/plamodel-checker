# .NET 8 Desktop Runtime インストールスクリプト
# PlamodelChecker 動作環境セットアップ用

$ErrorActionPreference = "Stop"
$host.UI.RawUI.WindowTitle = ".NET 8 セットアップ"

# ─────────────────────────────────────────────
# ログファイル（スクリプトと同フォルダに出力）
# ─────────────────────────────────────────────
$LogFile = Join-Path $PSScriptRoot "setup_log.txt"

function Write-Log {
    param($Level, $Msg)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$timestamp [$Level] $Msg" -Encoding UTF8
}

function Write-Step {
    param($Msg)
    Write-Host ""
    Write-Host ">>> $Msg" -ForegroundColor Cyan
    Write-Log "INFO" $Msg
}

function Write-Ok {
    param($Msg)
    Write-Host "    [OK] $Msg" -ForegroundColor Green
    Write-Log "OK  " $Msg
}

function Write-Warn {
    param($Msg)
    Write-Host "    [!!] $Msg" -ForegroundColor Yellow
    Write-Log "WARN" $Msg
}

function Write-Err {
    param($Msg)
    Write-Host "    [NG] $Msg" -ForegroundColor Red
    Write-Log "ERR " $Msg
}

# ─────────────────────────────────────────────
# ログ開始ヘッダー
# ─────────────────────────────────────────────
$sep = "=" * 60
Add-Content -Path $LogFile -Value "" -Encoding UTF8
Add-Content -Path $LogFile -Value $sep -Encoding UTF8
Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] セットアップ開始" -Encoding UTF8
Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] 実行ユーザー: $env:USERDOMAIN\$env:USERNAME" -Encoding UTF8
Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] コンピューター: $env:COMPUTERNAME" -Encoding UTF8
Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] OS: $([System.Environment]::OSVersion.VersionString)" -Encoding UTF8
Add-Content -Path $LogFile -Value $sep -Encoding UTF8

# ─────────────────────────────────────────────
# 1. 管理者権限チェック
# ─────────────────────────────────────────────
Write-Step "管理者権限を確認しています..."

$identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
$isAdmin   = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Err "管理者権限が必要です。"
    Write-Host ""
    Write-Host "  「セットアップ実行.bat」を右クリック → 「管理者として実行」でやり直してください。"
    Write-Host ""
    Write-Log "ERR " "セットアップ終了（管理者権限なし）"
    Read-Host "Enterキーで終了"
    exit 1
}

Write-Ok "管理者権限あり"

# ─────────────────────────────────────────────
# 2. .NET 8 インストール済みチェック
# ─────────────────────────────────────────────
Write-Step ".NET 8 Desktop Runtime の確認..."

$dotnetExe = Join-Path $env:ProgramFiles "dotnet\dotnet.exe"
$alreadyInstalled = $false

if (Test-Path $dotnetExe) {
    $runtimes = & $dotnetExe --list-runtimes 2>$null
    $matched  = $runtimes | Where-Object { $_ -match "^Microsoft\.WindowsDesktop\.App 8\." }
    if ($matched) {
        $alreadyInstalled = $true
        Write-Ok "既にインストール済みです："
        $matched | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
    }
}

if ($alreadyInstalled) {
    Write-Host ""
    Write-Host "  .NET 8 Desktop Runtime は既にインストール済みです。" -ForegroundColor Green
    Write-Host "  PlamodelChecker.exe をそのまま実行できます。"
    Write-Host ""
    Write-Log "INFO" "セットアップ終了（インストール不要）"
    Read-Host "Enterキーで終了"
    exit 0
}

Write-Warn ".NET 8 Desktop Runtime が見つかりません。インストールを開始します。"

# ─────────────────────────────────────────────
# 3. ダウンロード
# ─────────────────────────────────────────────
Write-Step ".NET 8 Desktop Runtime をダウンロード中..."

$url       = "https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x64.exe"
$installer = Join-Path $env:TEMP "dotnet8-desktop-runtime.exe"

try {
    $wc = New-Object System.Net.WebClient
    $wc.Proxy = [System.Net.WebRequest]::GetSystemWebProxy()
    $wc.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    $wc.UseDefaultCredentials = $true

    Write-Host "    ダウンロード中... しばらくお待ちください。" -ForegroundColor Gray
    $wc.DownloadFile($url, $installer)
    Write-Ok "ダウンロード完了"
}
catch {
    Write-Err "ダウンロードに失敗しました。"
    Write-Host ""
    Write-Host "  エラー: $_" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  【手動インストール方法】"
    Write-Host "  ブラウザで以下を開いて .NET Desktop Runtime 8.x.x (x64) をダウンロードして実行："
    Write-Host "  https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor White
    Write-Host ""
    Write-Log "ERR " "セットアップ終了（ダウンロード失敗: $_）"
    Read-Host "Enterキーで終了"
    exit 1
}

# ─────────────────────────────────────────────
# 4. インストール実行
# ─────────────────────────────────────────────
Write-Step "インストールを実行中..."
Write-Host "    （完了まで1～2分かかります）" -ForegroundColor Gray

try {
    $proc = Start-Process -FilePath $installer -ArgumentList "/install /quiet /norestart" -Wait -PassThru

    $code = $proc.ExitCode
    if ($code -eq 0) {
        Write-Ok "インストール完了"
    }
    elseif ($code -eq 3010) {
        Write-Ok "インストール完了（PCの再起動を推奨します）"
    }
    elseif ($code -eq 1638) {
        Write-Ok "既に同等バージョンがインストール済みです"
    }
    else {
        Write-Err "インストーラーが終了コード $code で終了しました。"
        Write-Log "ERR " "セットアップ終了（インストール失敗 ExitCode=$code）"
        Read-Host "Enterキーで終了"
        exit 1
    }
}
catch {
    Write-Err "インストール中にエラーが発生しました: $_"
    Write-Log "ERR " "セットアップ終了（インストール例外: $_）"
    Read-Host "Enterキーで終了"
    exit 1
}
finally {
    Remove-Item $installer -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────
# 5. 完了
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "  セットアップ完了！" -ForegroundColor Green
Write-Host "  PlamodelChecker.exe をダブルクリックして起動してください。" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "  ログファイル: $LogFile" -ForegroundColor Gray

Write-Log "INFO" "セットアップ終了（インストール成功）"
Read-Host "Enterキーで終了"
