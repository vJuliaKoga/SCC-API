#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BFF_DIR="$ROOT_DIR/bff"
REST_BACKEND_DIR="$ROOT_DIR/rest-backend"
GRPC_BACKEND_DIR="$ROOT_DIR/grpc-backend"
K6_DIR="$ROOT_DIR/k6"

RUN_TARGET="${RUN_TARGET:-both}"
SCENARIO_TARGET="${SCENARIO_TARGET:-both}"
K6_VUS="${K6_VUS:-10}"
K6_RAMP_UP="${K6_RAMP_UP:-30s}"
K6_STEADY="${K6_STEADY:-3m}"
K6_RAMP_DOWN="${K6_RAMP_DOWN:-30s}"
REST_READY_TIMEOUT="${REST_READY_TIMEOUT:-180}"
GRPC_READY_TIMEOUT="${GRPC_READY_TIMEOUT:-180}"
BFF_READY_TIMEOUT="${BFF_READY_TIMEOUT:-180}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT_ROOT="$ROOT_DIR/artifacts/ci/k6-benchmark/$TIMESTAMP"

print_info() {
    echo "[k6-ci] $1"
}

print_log_tail() {
    local label="$1"
    local file_path="$2"

    if [[ -f "$file_path" ]]; then
        echo "===== ${label} (tail -n 120) ====="
        tail -n 120 "$file_path"
    fi
}

validate_targets() {
    case "$RUN_TARGET" in
        both|rest|grpc)
            ;;
        *)
            echo "RUN_TARGET は both / rest / grpc のいずれかを指定してください: ${RUN_TARGET}" >&2
            return 1
            ;;
    esac

    case "$SCENARIO_TARGET" in
        both|users|orders)
            ;;
        *)
            echo "SCENARIO_TARGET は both / users / orders のいずれかを指定してください: ${SCENARIO_TARGET}" >&2
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

start_rest_backend() {
    print_info "rest-backend を起動します。"
    (
        cd "$REST_BACKEND_DIR"
        ./gradlew --no-daemon bootRun > "$REST_BACKEND_LOG" 2>&1
    ) &
    REST_PID=$!

    wait_for_http "rest-backend actuator" "http://127.0.0.1:19092/actuator/health" "$REST_READY_TIMEOUT"
}

start_grpc_backend() {
    print_info "grpc-backend を起動します。"
    (
        cd "$GRPC_BACKEND_DIR"
        ./gradlew --no-daemon bootRun > "$GRPC_BACKEND_LOG" 2>&1
    ) &
    GRPC_PID=$!

    wait_for_http "grpc-backend actuator" "http://127.0.0.1:19091/actuator/health" "$GRPC_READY_TIMEOUT"
    wait_for_port "grpc-backend gRPC" "127.0.0.1" "29090" "$GRPC_READY_TIMEOUT"
}

start_bff() {
    local call_mode="$1"

    print_info "bff を起動します: app.call-mode=${call_mode}"
    (
        cd "$BFF_DIR"
        ./gradlew --no-daemon bootRun --args="--app.call-mode=${call_mode}" > "$BFF_LOG" 2>&1
    ) &
    BFF_PID=$!

    wait_for_http "bff actuator" "http://127.0.0.1:19090/actuator/health" "$BFF_READY_TIMEOUT"
}

stop_pid_if_running() {
    local pid="${1:-}"

    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    fi
}

cleanup_mode_processes() {
    stop_pid_if_running "${BFF_PID:-}"
    BFF_PID=""

    stop_pid_if_running "${REST_PID:-}"
    REST_PID=""

    stop_pid_if_running "${GRPC_PID:-}"
    GRPC_PID=""
}

cleanup() {
    local exit_code=$?

    set +e

    cleanup_mode_processes

    if [[ $exit_code -ne 0 ]]; then
        print_log_tail "rest-backend.log" "${REST_BACKEND_LOG:-}"
        print_log_tail "grpc-backend.log" "${GRPC_BACKEND_LOG:-}"
        print_log_tail "bff.log" "${BFF_LOG:-}"
    fi

    exit "$exit_code"
}

trap cleanup EXIT

should_run_mode() {
    local mode="$1"

    if [[ "$RUN_TARGET" == "both" || "$RUN_TARGET" == "$mode" ]]; then
        return 0
    fi

    return 1
}

should_run_scenario() {
    local scenario_name="$1"

    if [[ "$SCENARIO_TARGET" == "both" || "$SCENARIO_TARGET" == "$scenario_name" ]]; then
        return 0
    fi

    return 1
}

extract_metric_value() {
    local summary_file="$1"
    local metric_name="$2"

    awk -v metric_name="$metric_name" '
        index($0, metric_name) == 1 {
            sub(/^[^:]+:[[:space:]]*/, "", $0)
            print
            exit
        }
    ' "$summary_file"
}

write_markdown_summary_header() {
    local summary_file="$1"

    cat > "$summary_file" <<EOF
# k6 CI 比較サマリー

## 前提

- 実行時刻: $(date '+%Y-%m-%d %H:%M:%S %Z')
- 実行対象:
  - mode: ${RUN_TARGET}
  - scenario: ${SCENARIO_TARGET}
- 負荷条件:
  - vus: ${K6_VUS}
  - ramp-up: ${K6_RAMP_UP}
  - steady: ${K6_STEADY}
  - ramp-down: ${K6_RAMP_DOWN}

## 比較結果

| mode | scenario | http_req_duration | http_req_failed | checks | iterations | http_reqs |
|------|----------|-------------------|-----------------|--------|------------|-----------|
EOF
}

append_markdown_summary_row() {
    local markdown_summary_file="$1"
    local mode="$2"
    local scenario_name="$3"
    local result_dir="$4"

    local summary_txt="$result_dir/summary.txt"

    local duration_value
    local failed_value
    local checks_value
    local iterations_value
    local requests_value

    duration_value="$(extract_metric_value "$summary_txt" "http_req_duration")"
    failed_value="$(extract_metric_value "$summary_txt" "http_req_failed")"
    checks_value="$(extract_metric_value "$summary_txt" "checks")"
    iterations_value="$(extract_metric_value "$summary_txt" "iterations")"
    requests_value="$(extract_metric_value "$summary_txt" "http_reqs")"

    echo "| ${mode} | ${scenario_name} | ${duration_value:-N/A} | ${failed_value:-N/A} | ${checks_value:-N/A} | ${iterations_value:-N/A} | ${requests_value:-N/A} |" >> "$markdown_summary_file"
}

run_single_k6() {
    local mode="$1"
    local scenario_name="$2"
    local script_path="$3"

    local result_dir="$OUTPUT_ROOT/$mode/$scenario_name"
    local run_id="${TIMESTAMP}-${mode}-${scenario_name}"
    local summary_export="$result_dir/summary.json"
    local summary_txt="$result_dir/summary.txt"

    mkdir -p "$result_dir"

    print_info "k6 を実行します: mode=${mode}, scenario=${scenario_name}, script=${script_path}"

    (
        cd "$ROOT_DIR"
        BASE_URL="http://127.0.0.1:19090" \
        K6_STAGES_ENABLED="true" \
        K6_VUS="$K6_VUS" \
        K6_RAMP_UP="$K6_RAMP_UP" \
        K6_STEADY="$K6_STEADY" \
        K6_RAMP_DOWN="$K6_RAMP_DOWN" \
        CALL_MODE="$mode" \
        RUN_ID="$run_id" \
        k6 run \
            --summary-export "$summary_export" \
            "$script_path" | tee "$summary_txt"
    )

    append_markdown_summary_row "$MARKDOWN_SUMMARY_FILE" "$mode" "$scenario_name" "$result_dir"
}

run_selected_scenarios() {
    local mode="$1"

    if should_run_scenario "users"; then
        run_single_k6 "$mode" "users" "$K6_DIR/scripts/benchmark/users-get.js"
    fi

    if should_run_scenario "orders"; then
        run_single_k6 "$mode" "orders" "$K6_DIR/scripts/benchmark/orders-post.js"
    fi
}

run_mode() {
    local mode="$1"

    local mode_log_dir="$OUTPUT_ROOT/$mode/logs"
    mkdir -p "$mode_log_dir"

    REST_BACKEND_LOG="$mode_log_dir/rest-backend.log"
    GRPC_BACKEND_LOG="$mode_log_dir/grpc-backend.log"
    BFF_LOG="$mode_log_dir/bff.log"

    : > "$REST_BACKEND_LOG"
    : > "$GRPC_BACKEND_LOG"
    : > "$BFF_LOG"

    if [[ "$mode" == "rest" ]]; then
        start_rest_backend
    else
        start_grpc_backend
    fi

    start_bff "$mode"
    run_selected_scenarios "$mode"
    cleanup_mode_processes
}

validate_targets
mkdir -p "$OUTPUT_ROOT"
chmod +x "$BFF_DIR/gradlew" "$REST_BACKEND_DIR/gradlew" "$GRPC_BACKEND_DIR/gradlew"

MARKDOWN_SUMMARY_FILE="$OUTPUT_ROOT/summary.md"
write_markdown_summary_header "$MARKDOWN_SUMMARY_FILE"

if should_run_mode "rest"; then
    run_mode "rest"
fi

if should_run_mode "grpc"; then
    run_mode "grpc"
fi

print_info "k6 ベンチマークが完了しました。"
print_info "出力先: $OUTPUT_ROOT"