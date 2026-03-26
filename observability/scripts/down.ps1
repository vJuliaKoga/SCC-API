param(
    [switch]$RemoveVolumes
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$observabilityDir = Join-Path $projectRoot "observability"

Push-Location $observabilityDir
try {
    $args = @("compose", "down")

    if ($RemoveVolumes) {
        $args += "--volumes"
    }

    docker @args
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose down に失敗しました。"
    }
}
finally {
    Pop-Location
}

Write-Host "統合観測基盤を停止しました。"