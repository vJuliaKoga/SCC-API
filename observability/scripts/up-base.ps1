$ErrorActionPreference = "Stop"

function Wait-HttpReady {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [int]$MaxRetry = 30,

        [int]$SleepSeconds = 2
    )

    for ($i = 1; $i -le $MaxRetry; $i++) {
        try {
            Invoke-WebRequest -Uri $Url -UseBasicParsing | Out-Null
            Write-Host "起動確認OK: $Url"
            return
        }
        catch {
            Start-Sleep -Seconds $SleepSeconds
        }
    }

    throw "起動確認に失敗しました: $Url"
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$observabilityDir = Join-Path $projectRoot "observability"
$logsDir = Join-Path $observabilityDir "logs"

if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

Push-Location $observabilityDir
try {
    docker compose up -d
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose up -d に失敗しました。"
    }
}
finally {
    Pop-Location
}

Wait-HttpReady -Url "http://localhost:3000/api/health"
Wait-HttpReady -Url "http://localhost:19093/-/ready"
Wait-HttpReady -Url "http://localhost:3200/ready"
Wait-HttpReady -Url "http://localhost:3100/ready"
Wait-HttpReady -Url "http://localhost:13133"

Write-Host ""
Write-Host "統合観測基盤を起動しました。"
Write-Host "Grafana     : http://localhost:3000"
Write-Host "Prometheus  : http://localhost:19093"
Write-Host "Tempo Ready : http://localhost:3200/ready"
Write-Host "Loki Ready  : http://localhost:3100/ready"
Write-Host "Collector   : http://localhost:13133"