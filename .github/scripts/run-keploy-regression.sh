#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BFF_DIR="$ROOT_DIR/bff"
REST_BACKEND_DIR="$ROOT_DIR/rest-backend"
GRPC_BACKEND_DIR="$ROOT_DIR/grpc-backend"
KEPLOY_PROJECT_ROOT="$BFF_DIR"
KEPLOY_ASSET_ROOT="$BFF_DIR/keploy"
RUN_LABEL="${RUN_LABEL:-${BFF_CALL_MODE:-grpc}}"
LOG_DIR="$ROOT_DIR/artifacts/ci/keploy-regression/${RUN_LABEL}"
REST_LOG="$LOG_DIR/rest-backend.log"
GRPC_LOG="$LOG_DIR/grpc-backend.log"
KEPLOY_LOG="$LOG_DIR/keploy.log"

PRIMARY_TEST_SET="${KEPLOY_TEST_SET:-test-set-rest}"
BFF_CALL_MODE="${BFF_CALL_MODE:-grpc}"
KEPLOY_DELAY="${KEPLOY_DELAY:-80}"
REST_READY_TIMEOUT="${REST_READY_TIMEOUT:-180}"
GRPC_READY_TIMEOUT="${GRPC_READY_TIMEOUT:-180}"
KEPLOY_OBSERVABILITY_ENABLED="${KEPLOY_OBSERVABILITY_ENABLED:-false}"
ACTIVE_TEST_SET="$PRIMARY_TEST_SET"

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

validate_call_mode() {
    case "$BFF_CALL_MODE" in
        grpc|rest)
            ;;
        *)
            echo "BFF_CALL_MODE は grpc または rest を指定してください: ${BFF_CALL_MODE}" >&2
            return 1
            ;;
    esac
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

select_active_test_set() {
    ensure_test_set_layout "$PRIMARY_TEST_SET"

    if test_set_contains_generic_mocks "$PRIMARY_TEST_SET"; then
        echo "${PRIMARY_TEST_SET} は Generic mock を含んでおり、通常 CI の正本として使えません。" >&2
        echo "bff/keploy/${PRIMARY_TEST_SET}/mocks.yaml を clean 化してから再実行してください。" >&2
        return 1
    fi
}

print_active_test_set_summary() {
    local test_set_dir="$KEPLOY_ASSET_ROOT/${ACTIVE_TEST_SET}"

    print_info "実行ラベル: ${RUN_LABEL}"
    print_info "BFF call-mode: ${BFF_CALL_MODE}"
    print_info "使用する test-set: ${ACTIVE_TEST_SET}"
    print_info "Keploy project root: ${KEPLOY_PROJECT_ROOT}"
    print_info "Keploy asset root: ${KEPLOY_ASSET_ROOT}"
    print_info "Keploy observability: ${KEPLOY_OBSERVABILITY_ENABLED}"
    print_info "testcase 一覧:"
    find "$test_set_dir/tests" -maxdepth 1 -type f -name "*.yaml" | sort
}

write_keploy_observability_header() {
    if [[ "$KEPLOY_OBSERVABILITY_ENABLED" != "true" ]]; then
        return 0
    fi

    {
        echo "[keploy-ci] 実行ラベル: ${RUN_LABEL}"
        echo "[keploy-ci] BFF call-mode: ${BFF_CALL_MODE}"
        echo "[keploy-ci] 使用する test-set: ${ACTIVE_TEST_SET}"
    } >> "$KEPLOY_LOG"
}

start_rest_backend() {
    print_info "rest-backend を起動します。"
    (
        cd "$REST_BACKEND_DIR"
        ./gradlew --no-daemon bootRun > "$REST_LOG" 2>&1
    ) &
    REST_PID=$!

    wait_for_http "rest-backend actuator" "http://127.0.0.1:19092/actuator/health" "$REST_READY_TIMEOUT"
}

start_grpc_backend() {
    print_info "grpc-backend を起動します。"
    (
        cd "$GRPC_BACKEND_DIR"
        ./gradlew --no-daemon bootRun > "$GRPC_LOG" 2>&1
    ) &
    GRPC_PID=$!

    wait_for_http "grpc-backend actuator" "http://127.0.0.1:19091/actuator/health" "$GRPC_READY_TIMEOUT"
    wait_for_port "grpc-backend gRPC" "127.0.0.1" "29090" "$GRPC_READY_TIMEOUT"
}

start_backend_for_call_mode() {
    case "$BFF_CALL_MODE" in
        rest)
            start_rest_backend
            ;;
        grpc)
            start_grpc_backend
            ;;
    esac
}

cleanup() {
    local exit_code=$?

    set +e

    if [[ -n "${REST_PID:-}" ]] && kill -0 "$REST_PID" 2>/dev/null; then
        kill "$REST_PID" 2>/dev/null || true
        wait "$REST_PID" 2>/dev/null || true
    fi

    if [[ -n "${GRPC_PID:-}" ]] && kill -0 "$GRPC_PID" 2>/dev/null; then
        kill "$GRPC_PID" 2>/dev/null || true
        wait "$GRPC_PID" 2>/dev/null || true
    fi

    sudo chown -R "$USER":"$USER" "$ROOT_DIR/bff/keploy/reports" "$ROOT_DIR/observability/logs" "$ROOT_DIR/artifacts" 2>/dev/null || true

    if [[ $exit_code -ne 0 ]]; then
        print_log_tail "rest-backend.log" "$REST_LOG"
        print_log_tail "grpc-backend.log" "$GRPC_LOG"
        print_log_tail "keploy.log" "$KEPLOY_LOG"
    fi

    exit "$exit_code"
}

trap cleanup EXIT

mkdir -p "$LOG_DIR"
: > "$REST_LOG"
: > "$GRPC_LOG"
: > "$KEPLOY_LOG"

chmod +x "$BFF_DIR/gradlew" "$REST_BACKEND_DIR/gradlew" "$GRPC_BACKEND_DIR/gradlew"

validate_call_mode
select_active_test_set
print_active_test_set_summary

start_backend_for_call_mode

# BFF は Keploy に起動させる。sudo 実行時でも元ユーザーの Gradle キャッシュを使う。
# observability workflow では APP_LOG_FILE を固定し、Collector が拾える位置へ出力する。
BFF_COMMAND="bash -lc 'USER_HOME=\"\$(getent passwd \"\${SUDO_USER:-\$USER}\" | cut -d: -f6)\"; export GRADLE_USER_HOME=\"\${GRADLE_USER_HOME:-\$USER_HOME/.gradle}\"; if [[ \"${KEPLOY_OBSERVABILITY_ENABLED}\" == \"true\" ]]; then export APP_LOG_FILE=\"../observability/logs/bff.log\"; export APP_LOG_FILE_PATTERN=\"../observability/logs/bff.%d{yyyy-MM-dd}.%i.log\"; fi; ./gradlew --no-daemon bootRun --args=\"--app.call-mode=${BFF_CALL_MODE}\"'"

write_keploy_observability_header

print_info "Keploy で ${ACTIVE_TEST_SET} を ${BFF_CALL_MODE} 実装に対して実行します。"
(
    cd "$BFF_DIR"
    sudo -E env "PATH=$PATH" keploy test \
        --path "$KEPLOY_PROJECT_ROOT" \
        --test-sets "$ACTIVE_TEST_SET" \
        --delay "$KEPLOY_DELAY" \
        --mocking=false \
        -c "$BFF_COMMAND" \
        2>&1 | tee -a "$KEPLOY_LOG"
)

if [[ "$KEPLOY_OBSERVABILITY_ENABLED" == "true" ]]; then
    print_info "Keploy 実行ログを Collector が拾える位置へコピーします。"
    mkdir -p "$ROOT_DIR/observability/logs"
    cp "$KEPLOY_LOG" "$ROOT_DIR/observability/logs/keploy-${RUN_LABEL}.log"
fi

print_info "Keploy 回帰確認が完了しました。"
