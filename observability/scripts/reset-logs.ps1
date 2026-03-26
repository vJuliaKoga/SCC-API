$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$logsDir = Join-Path $projectRoot "observability\logs"

if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

$targets = @(
    "bff.log",
    "rest-backend.log",
    "grpc-backend.log"
)

foreach ($name in $targets) {
    $path = Join-Path $logsDir $name

    if (Test-Path $path) {
        Clear-Content -Path $path -ErrorAction SilentlyContinue
    }
    else {
        New-Item -ItemType File -Path $path -Force | Out-Null
    }
}

Write-Host "アプリログを初期化しました。"