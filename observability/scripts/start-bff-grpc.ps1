$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$appDir = Join-Path $projectRoot "bff"
$javaAgent = Join-Path $projectRoot ".otel\opentelemetry-javaagent.jar"

if (-not (Test-Path $javaAgent)) {
    throw "OpenTelemetry Java Agent が見つかりません: $javaAgent"
}

$env:JAVA_TOOL_OPTIONS = "-javaagent:$javaAgent"
$env:OTEL_SERVICE_NAME = "bff"
$env:OTEL_RESOURCE_ATTRIBUTES = "service.namespace=scc-api,deployment.environment=local,app.call_mode=grpc"
$env:OTEL_PROPAGATORS = "tracecontext,baggage"
$env:OTEL_TRACES_EXPORTER = "otlp"
$env:OTEL_METRICS_EXPORTER = "none"
$env:OTEL_LOGS_EXPORTER = "none"
$env:OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf"
$env:OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:4318"

Push-Location $appDir
try {
    .\gradlew.bat bootRun --args="--app.call-mode=grpc"
}
finally {
    Pop-Location
}