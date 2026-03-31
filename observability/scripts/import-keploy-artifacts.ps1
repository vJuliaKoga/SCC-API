param(
    [Parameter(Mandatory = $true)]
    [string]$ArtifactRoot,

    [switch]$IncludeAppLogs,

    [switch]$RestartCollector
)

$ErrorActionPreference = "Stop"

function Resolve-ArtifactLogPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string[]]$RelativeCandidates
    )

    foreach ($candidate in $RelativeCandidates) {
        $candidatePath = Join-Path $Root $candidate
        if (Test-Path $candidatePath) {
            return (Resolve-Path $candidatePath).Path
        }
    }

    return $null
}

function Copy-LogFromArtifact {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$DestinationDir,

        [Parameter(Mandatory = $true)]
        [string]$DestinationFileName,

        [Parameter(Mandatory = $true)]
        [string[]]$RelativeCandidates,

        [switch]$Optional
    )

    $sourcePath = Resolve-ArtifactLogPath -Root $Root -RelativeCandidates $RelativeCandidates

    if (-not $sourcePath) {
        if ($Optional) {
            Write-Host "省略しました: $DestinationFileName"
            return
        }

        throw "artifact 内に $DestinationFileName のコピー元が見つかりませんでした。"
    }

    $destinationPath = Join-Path $DestinationDir $DestinationFileName
    Copy-Item -Path $sourcePath -Destination $destinationPath -Force
    Write-Host "取り込みました: $destinationPath"
}

function Ensure-KeployLabelHeader {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$RunLabel
    )

    $content = Get-Content -Path $Path -Raw -Encoding UTF8
    if ($content -match '^\[keploy-ci\] 実行ラベル: ') {
        return
    }

    $header = @(
        "[keploy-ci] 実行ラベル: $RunLabel"
        "[keploy-ci] BFF call-mode: $RunLabel"
        ""
    ) -join [Environment]::NewLine

    Set-Content -Path $Path -Value ($header + $content) -Encoding UTF8
    Write-Host "Keploy ヘッダーを追記しました: $Path"
}

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

function Restart-ObservabilityStack {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ObservabilityDir
    )

    Push-Location $ObservabilityDir
    try {
        docker compose up -d --force-recreate otel-collector grafana
        if ($LASTEXITCODE -ne 0) {
            throw "otel-collector / grafana の再起動に失敗しました。"
        }
    }
    finally {
        Pop-Location
    }

    Wait-HttpReady -Url "http://localhost:13000/api/health"
    Wait-HttpReady -Url "http://localhost:13133"
}

function Stop-ObservabilityWriters {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ObservabilityDir
    )

    Push-Location $ObservabilityDir
    try {
        docker compose stop otel-collector grafana
        if ($LASTEXITCODE -ne 0) {
            throw "otel-collector / grafana の停止に失敗しました。"
        }
    }
    finally {
        Pop-Location
    }
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$observabilityDir = Join-Path $projectRoot "observability"
$logsDir = Join-Path $observabilityDir "logs"
$artifactRootPath = (Resolve-Path $ArtifactRoot).Path

if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

if ($RestartCollector) {
    Stop-ObservabilityWriters -ObservabilityDir $observabilityDir
}

Copy-LogFromArtifact `
    -Root $artifactRootPath `
    -DestinationDir $logsDir `
    -DestinationFileName "keploy-rest.log" `
    -RelativeCandidates @(
        "observability/logs/keploy-rest.log",
        "artifacts/ci/keploy-regression/rest/keploy.log",
        "keploy-rest.log",
        "rest/keploy.log"
    )

Ensure-KeployLabelHeader `
    -Path (Join-Path $logsDir "keploy-rest.log") `
    -RunLabel "rest"

Copy-LogFromArtifact `
    -Root $artifactRootPath `
    -DestinationDir $logsDir `
    -DestinationFileName "keploy-grpc.log" `
    -RelativeCandidates @(
        "observability/logs/keploy-grpc.log",
        "artifacts/ci/keploy-regression/grpc/keploy.log",
        "keploy-grpc.log",
        "grpc/keploy.log"
    )

Ensure-KeployLabelHeader `
    -Path (Join-Path $logsDir "keploy-grpc.log") `
    -RunLabel "grpc"

if ($IncludeAppLogs) {
    Copy-LogFromArtifact `
        -Root $artifactRootPath `
        -DestinationDir $logsDir `
        -DestinationFileName "bff.log" `
        -RelativeCandidates @(
            "observability/logs/bff.log",
            "bff.log"
        ) `
        -Optional

    Copy-LogFromArtifact `
        -Root $artifactRootPath `
        -DestinationDir $logsDir `
        -DestinationFileName "rest-backend.log" `
        -RelativeCandidates @(
            "observability/logs/rest-backend.log",
            "rest-backend.log"
        ) `
        -Optional

    Copy-LogFromArtifact `
        -Root $artifactRootPath `
        -DestinationDir $logsDir `
        -DestinationFileName "grpc-backend.log" `
        -RelativeCandidates @(
            "observability/logs/grpc-backend.log",
            "grpc-backend.log"
        ) `
        -Optional
}

if ($RestartCollector) {
    Restart-ObservabilityStack -ObservabilityDir $observabilityDir
}

Write-Host ""
Write-Host "Keploy artifact の取り込みが完了しました。"
Write-Host "Grafana: http://localhost:13000"
