# フレームワーク依存リリースビルドスクリプト
# 出力先: tools/deploy/ フォルダ

$dotnet = "C:\Program Files\dotnet\dotnet.exe"
$project = "$PSScriptRoot\..\src\PlamodelChecker\PlamodelChecker.csproj"
$output  = "$PSScriptRoot\deploy"

Write-Host ""
Write-Host "PlamodelChecker リリースビルド" -ForegroundColor Cyan
Write-Host "================================"

# ビルド実行
Write-Host "ビルド中..." -ForegroundColor Yellow
& $dotnet publish $project `
    -c Release `
    --framework net8.0-windows `
    --self-contained false `
    -p:PublishSingleFile=true `
    -p:EnableCompressionInSingleFile=false `
    -o $output

if ($LASTEXITCODE -ne 0) {
    Write-Host "ビルド失敗" -ForegroundColor Red
    exit 1
}

# 不要ファイル削除
Remove-Item "$output\*.pdb"  -ErrorAction SilentlyContinue
Remove-Item "$output\*.xml"  -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "  ビルド完了！" -ForegroundColor Green
Write-Host "  出力先: $output" -ForegroundColor Green
Write-Host ""
Write-Host "  【配布フォルダ構成】" -ForegroundColor White
Write-Host "  deploy/"
Write-Host "    PlamodelChecker.exe     ← メイン実行ファイル（小さい）"
Write-Host "    荷姿設定書検索.xlsm      ← ここに配置"
Write-Host "    manual.html             ← ここに配置"
Write-Host "    セットアップ実行.bat      ← .NET未導入PC用"
Write-Host "    install_dotnet.ps1      ← セットアップ実行.batが呼び出す"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
