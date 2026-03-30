#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BFF_DIR="$ROOT_DIR/bff"
GRPC_BACKEND_DIR="$ROOT_DIR/grpc-backend"
KEPLOY_PROJECT_ROOT="$BFF_DIR"
KEPLOY_ASSET_ROOT="$BFF_DIR/keploy"
LOG_DIR="$ROOT_DIR/artifacts/ci/keploy-grpc-regression"
GRPC_LOG="$LOG_DIR/grpc-backend.log"
KEPLOY_LOG="$LOG_DIR/keploy.log"

PRIMARY_TEST_SET="${KEPLOY_TEST_SET:-test-set-rest}"
FALLBACK_TEST_SET="${KEPLOY_FALLBACK_TEST_SET:-test-set-rest-ci-smoke}"
FALLBACK_RUNTIME_TEST_SET="test-set-0"
KEPLOY_DELAY="${KEPLOY_DELAY:-80}"
GRPC_READY_TIMEOUT="${GRPC_READY_TIMEOUT:-180}"
ACTIVE_TEST_SET=""

print_info() {
    echo "[keploy-ci] $1"
}

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
            print_info "${label} が起動しました: ${url}"
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
            print_info "${label} の待受を確認しました: ${host}:${port}"
            return 0
        fi
        sleep 2
    done

    echo "${label} の待受確認がタイムアウトしました: ${host}:${port}" >&2
    return 1
}

ensure_test_set_layout() {
    local test_set_name="$1"
    local test_set_dir="$KEPLOY_ASSET_ROOT/${test_set_name}"

    if [[ ! -d "$test_set_dir" ]]; then
        echo "test-set ディレクトリが存在しません: ${test_set_dir}" >&2
        return 1
    fi

    if [[ ! -f "$test_set_dir/mocks.yaml" ]]; then
        echo "mocks.yaml が存在しません: ${test_set_dir}/mocks.yaml" >&2
        return 1
    fi

    if [[ ! -d "$test_set_dir/tests" ]]; then
        echo "tests ディレクトリが存在しません: ${test_set_dir}/tests" >&2
        return 1
    fi

    if ! find "$test_set_dir/tests" -maxdepth 1 -type f -name "*.yaml" | grep -q .; then
        echo "testcase YAML が存在しません: ${test_set_dir}/tests" >&2
        return 1
    fi
}

test_set_contains_generic_mocks() {
    local test_set_name="$1"
    local mocks_file="$KEPLOY_ASSET_ROOT/${test_set_name}/mocks.yaml"

    grep -Eq "^kind: Generic$" "$mocks_file"
}

prepare_runtime_fallback_test_set() {
    local source_dir="$KEPLOY_ASSET_ROOT/${FALLBACK_TEST_SET}"
    local runtime_dir="$KEPLOY_ASSET_ROOT/${FALLBACK_RUNTIME_TEST_SET}"

    ensure_test_set_layout "$FALLBACK_TEST_SET"

    if [[ -d "$runtime_dir" ]]; then
        rm -rf "$runtime_dir"
    fi

    cp -R "$source_dir" "$runtime_dir"
    ACTIVE_TEST_SET="$FALLBACK_RUNTIME_TEST_SET"
}

select_active_test_set() {
    ensure_test_set_layout "$PRIMARY_TEST_SET"

    if test_set_contains_generic_mocks "$PRIMARY_TEST_SET"; then
        print_info "${PRIMARY_TEST_SET} は Generic mock を含んでおり、CI replay 用 asset として汚染されています。"
        print_info "${FALLBACK_TEST_SET} を source として、Keploy が既知で扱えていた数値系 test-set 名 ${FALLBACK_RUNTIME_TEST_SET} へ staging します。"
        prepare_runtime_fallback_test_set
        return 0
    fi

    ACTIVE_TEST_SET="$PRIMARY_TEST_SET"
}

print_active_test_set_summary() {
    local test_set_dir="$KEPLOY_ASSET_ROOT/${ACTIVE_TEST_SET}"

    print_info "使用する test-set: ${ACTIVE_TEST_SET}"
    print_info "Keploy project root: ${KEPLOY_PROJECT_ROOT}"
    print_info "Keploy asset root: ${KEPLOY_ASSET_ROOT}"
    print_info "testcase 一覧:"
    find "$test_set_dir/tests" -maxdepth 1 -type f -name "*.yaml" | sort
}

cleanup() {
    local exit_code=$?

    set +e

    if [[ -n "${GRPC_PID:-}" ]] && kill -0 "$GRPC_PID" 2>/dev/null; then
        kill "$GRPC_PID" 2>/dev/null || true
        wait "$GRPC_PID" 2>/dev/null || true
    fi

    if [[ -n "${ACTIVE_TEST_SET:-}" ]] && [[ "$ACTIVE_TEST_SET" == "$FALLBACK_RUNTIME_TEST_SET" ]]; then
        rm -rf "$KEPLOY_ASSET_ROOT/$FALLBACK_RUNTIME_TEST_SET" 2>/dev/null || true
    fi

    sudo chown -R "$USER":"$USER" "$ROOT_DIR/bff/keploy/reports" "$ROOT_DIR/observability/logs" 2>/dev/null || true

    if [[ $exit_code -ne 0 ]]; then
        print_log_tail "grpc-backend.log" "$GRPC_LOG"
        print_log_tail "keploy.log" "$KEPLOY_LOG"
    fi

    exit "$exit_code"
}

trap cleanup EXIT

mkdir -p "$LOG_DIR"
: > "$GRPC_LOG"
: > "$KEPLOY_LOG"

chmod +x "$BFF_DIR/gradlew" "$GRPC_BACKEND_DIR/gradlew"

select_active_test_set
print_active_test_set_summary

print_info "grpc-backend を起動します。"
(
    cd "$GRPC_BACKEND_DIR"
    ./gradlew --no-daemon bootRun > "$GRPC_LOG" 2>&1
) &
GRPC_PID=$!

wait_for_http "grpc-backend actuator" "http://127.0.0.1:19091/actuator/health" "$GRPC_READY_TIMEOUT"
wait_for_port "grpc-backend gRPC" "127.0.0.1" "29090" "$GRPC_READY_TIMEOUT"

# BFF は Keploy に起動させる。sudo 実行時でも元ユーザーの Gradle キャッシュを使う。
BFF_COMMAND='bash -lc '"'"'USER_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"; export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$USER_HOME/.gradle}"; ./gradlew --no-daemon bootRun --args="--app.call-mode=grpc"'"'"''

print_info "Keploy で ${ACTIVE_TEST_SET} を gRPC 実装に対して実行します。"
(
    cd "$BFF_DIR"
    sudo -E env "PATH=$PATH" keploy test \
        --path "$KEPLOY_PROJECT_ROOT" \
        --test-sets "$ACTIVE_TEST_SET" \
        --delay "$KEPLOY_DELAY" \
        --mocking=false \
        -c "$BFF_COMMAND" \
        2>&1 | tee "$KEPLOY_LOG"
)

print_info "Keploy 回帰確認が完了しました。"
