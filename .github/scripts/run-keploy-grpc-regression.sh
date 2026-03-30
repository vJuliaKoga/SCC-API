#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BFF_DIR="$ROOT_DIR/bff"
GRPC_BACKEND_DIR="$ROOT_DIR/grpc-backend"
LOG_DIR="$ROOT_DIR/artifacts/ci/keploy-grpc-regression"
OBSERVABILITY_LOG_DIR="$ROOT_DIR/observability/logs"
GRPC_LOG="$LOG_DIR/grpc-backend.log"
BFF_LOG="$OBSERVABILITY_LOG_DIR/bff.log"
KEPLOY_LOG="$LOG_DIR/keploy.log"
KEPLOY_TEST_SET="${KEPLOY_TEST_SET:-test-set-rest}"
KEPLOY_DELAY="${KEPLOY_DELAY:-80}"
GRPC_READY_TIMEOUT="${GRPC_READY_TIMEOUT:-180}"

print_log_tail() {
    local label="$1"
    local file_path="$2"

    if [[ -f "$file_path" ]]; then
        echo "===== ${label} (tail -n 80) ====="
        tail -n 80 "$file_path"
    fi
}

wait_for_http() {
    local label="$1"
    local url="$2"
    local timeout_seconds="$3"
    local start_time="$SECONDS"

    while (( SECONDS - start_time < timeout_seconds )); do
        if curl --fail --silent --show-error "$url" > /dev/null; then
            echo "${label} が起動しました: ${url}"
            return 0
        fi
        sleep 2
    done

    echo "${label} の起動待ちがタイムアウトしました: ${url}" >&2
    return 1
}

wait_for_port() {
    local label="$1"
    local host="$2"
    local port="$3"
    local timeout_seconds="$4"
    local start_time="$SECONDS"

    while (( SECONDS - start_time < timeout_seconds )); do
        if (echo > "/dev/tcp/${host}/${port}") > /dev/null 2>&1; then
            echo "${label} の待受を確認しました: ${host}:${port}"
            return 0
        fi
        sleep 2
    done

    echo "${label} の待受確認がタイムアウトしました: ${host}:${port}" >&2
    return 1
}

cleanup() {
    local exit_code=$?

    set +e

    if [[ -n "${GRPC_PID:-}" ]] && kill -0 "$GRPC_PID" 2>/dev/null; then
        kill "$GRPC_PID" 2>/dev/null || true
        wait "$GRPC_PID" 2>/dev/null || true
    fi

    sudo chown -R "$USER":"$USER" \
        "$ROOT_DIR/bff/keploy/reports" \
        "$ROOT_DIR/observability/logs" \
        "$ROOT_DIR/artifacts/ci/keploy-grpc-regression" \
        2>/dev/null || true

    if [[ $exit_code -ne 0 ]]; then
        print_log_tail "grpc-backend.log" "$GRPC_LOG"
        print_log_tail "bff.log" "$BFF_LOG"
        print_log_tail "keploy.log" "$KEPLOY_LOG"
    fi

    exit "$exit_code"
}

trap cleanup EXIT

mkdir -p "$LOG_DIR"
mkdir -p "$OBSERVABILITY_LOG_DIR"
: > "$GRPC_LOG"
: > "$BFF_LOG"
: > "$KEPLOY_LOG"

chmod +x "$BFF_DIR/gradlew" "$GRPC_BACKEND_DIR/gradlew"

echo "Keploy 元配置を確認します。"
find "$BFF_DIR/keploy/$KEPLOY_TEST_SET" -maxdepth 3 -print | sort

echo "grpc-backend を起動します。"
(
    cd "$GRPC_BACKEND_DIR"
    ./gradlew --no-daemon bootRun > "$GRPC_LOG" 2>&1
) &
GRPC_PID=$!

wait_for_http "grpc-backend actuator" "http://127.0.0.1:19091/actuator/health" "$GRPC_READY_TIMEOUT"
wait_for_port "grpc-backend gRPC" "127.0.0.1" "29090" "$GRPC_READY_TIMEOUT"

BFF_COMMAND='bash -lc '"'"'
    USER_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
    export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$USER_HOME/.gradle}"
    export APP_LOG_FILE="'"$BFF_LOG"'"
    ./gradlew --no-daemon bootRun --args="--app.call-mode=grpc"
'"'"''

echo "Keploy で ${KEPLOY_TEST_SET} を gRPC 実装に対して実行します。"
(
    cd "$BFF_DIR"
    sudo -E env "PATH=$PATH" keploy test \
        --path keploy \
        --config-path "$BFF_DIR" \
        --test-sets "$KEPLOY_TEST_SET" \
        --delay "$KEPLOY_DELAY" \
        --mocking=false \
        --in-ci \
        -c "$BFF_COMMAND" \
        2>&1 | tee "$KEPLOY_LOG"
)

echo "Keploy 回帰確認が完了しました。"
