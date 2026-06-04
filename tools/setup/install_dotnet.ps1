# .NET 8 Desktop Runtime インストールスクリプト
# PlamodelChecker 動作環境セットアップ用

$ErrorActionPreference = "Stop"
$host.UI.RawUI.WindowTitle = ".NET 8 セットアップ"

function Write-Step($msg) {
    Write-Host ""
    Write-Host ">>> $msg" -ForegroundColor Cyan
}

function Write-Ok($msg) {
    Write-Host "    [OK] $msg" -ForegroundColor Green
}

function Write-Warn($msg) {
    Write-Host "    [!!] $msg" -ForegroundColor Yellow
}

function Write-Err($msg) {
    Write-Host "    [NG] $msg" -ForegroundColor Red
}

# ─────────────────────────────────────────────
# 1. 管理者権限チェック
# ─────────────────────────────────────────────
Write-Step "管理者権限を確認しています..."

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    Write-Err "管理者権限が必要です。"
    Write-Host ""
    Write-Host "  「セットアップ実行.bat」を右クリック → 「管理者として実行」でやり直してください。"
    Write-Host ""
    Read-Host "Enterキーで終了"
    exit 1
}

Write-Ok "管理者権限あり"

# ─────────────────────────────────────────────
# 2. .NET 8 インストール済みチェック
# ─────────────────────────────────────────────
Write-Step ".NET 8 Desktop Runtime の確認..."

$dotnetPath = "$env:ProgramFiles\dotnet\dotnet.exe"
$alreadyInstalled = $false

if (Test-Path $dotnetPath) {
    $runtimes = & $dotnetPath --list-runtimes 2>$null
    $match = $runtimes | Where-Object { $_ -match "^Microsoft\.WindowsDesktop\.App 8\." }
    if ($match) {
        $alreadyInstalled = $true
        Write-Ok "既にインストール済みです："
        $match | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
    }
}

if ($alreadyInstalled) {
    Write-Host ""
    Write-Host "  .NET 8 Desktop Runtime は既にインストール済みです。" -ForegroundColor Green
    Write-Host "  PlamodelChecker.exe をそのまま実行できます。"
    Write-Host ""
    Read-Host "Enterキーで終了"
    exit 0
}

Write-Warn ".NET 8 Desktop Runtime が見つかりません。インストールを開始します。"

# ─────────────────────────────────────────────
# 3. ダウンロード
# ─────────────────────────────────────────────
Write-Step ".NET 8 Desktop Runtime をダウンロード中..."

$url       = "https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x64.exe"
$installer = "$env:TEMP\dotnet8-desktop-runtime.exe"

try {
    $webClient = New-Object System.Net.WebClient

    # 社内プロキシ対応（Windowsの認証情報を自動使用）
    $webClient.Proxy = [System.Net.WebRequest]::GetSystemWebProxy()
    $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    $webClient.UseDefaultCredentials = $true

    Write-Host "    ダウンロード先URL: $url" -ForegroundColor Gray
    Write-Host "    しばらくお待ちください..." -ForegroundColor Gray

    $webClient.DownloadFile($url, $installer)
    Write-Ok "ダウンロード完了"
}
catch {
    Write-Err "ダウンロードに失敗しました。"
    Write-Host ""
    Write-Host "  ネットワーク接続またはプロキシ設定を確認してください。"
    Write-Host "  エラー: $_" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  【手動インストール方法】"
    Write-Host "  ブラウザで以下のURLを開いて手動でダウンロードしてください："
    Write-Host "  https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor White
    Write-Host "  「.NET Desktop Runtime 8.x.x」の「x64」をダウンロードして実行"
    Write-Host ""
    Read-Host "Enterキーで終了"
    exit 1
}

# ─────────────────────────────────────────────
# 4. インストール実行
# ─────────────────────────────────────────────
Write-Step "インストールを実行中..."
Write-Host "    （完了まで1～2分かかります）" -ForegroundColor Gray

try {
    $proc = Start-Process -FilePath $installer `
        -ArgumentList "/install /quiet /norestart" `
        -Wait -PassThru

    switch ($proc.ExitCode) {
        0    { Write-Ok "インストール完了" }
        3010 { Write-Ok "インストール完了（再起動を推奨）" }
        1638 { Write-Ok "既に同等バージョンがインストール済みです" }
        default {
            Write-Err "インストーラーが終了コード $($proc.ExitCode) で終了しました。"
            Write-Host "  手動でインストーラーを実行してみてください。"
            Write-Host "  インストーラーの場所: $installer"
            Write-Host ""
            Read-Host "Enterキーで終了"
            exit 1
        }
    }
}
catch {
    Write-Err "インストール中にエラーが発生しました: $_"
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

Read-Host "Enterキーで終了"
