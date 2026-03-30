# runbook

## 前提

- Docker Desktop が起動していること
- Java / Gradle が利用可能であること
- Node.js / npm が利用可能であること
- k6 が利用可能であること
- ローカルで以下のポートが空いていること
  - `13000` (Grafana)
  - `19090` (BFF)
  - `19091` (gRPC backend)
  - `19092` (REST backend)
  - `19093` (Prometheus)
  - `29090` (gRPC backend HTTP)

---

## 1. 観測基盤の起動

### 1-1. 起動

```bash
cd observability
docker compose up -d
```

### 1-2. 確認ポイント

- Grafana:
  - `http://localhost:13000`

- Prometheus:
  - `http://localhost:19093`

- Collector Health:
  - `http://localhost:13133`

### 1-3. 補足

- 初回起動時はコンテナ起動完了まで少し待つ
- Collector / Tempo / Loki も同時に起動する
- ポート競合がある場合は既存プロセスを停止してから再実行する

---

## 2. アプリケーションの起動

### 2-1. REST backend

```bash
./gradlew :rest-backend:bootRun
```

- 待受ポート:
  - `19092`

### 2-2. gRPC backend

```bash
./gradlew :grpc-backend:bootRun
```

- 待受ポート:
  - gRPC: `19091`
  - HTTP: `29090`

### 2-3. BFF

#### REST モード

```bash
APP_CALL_MODE=rest ./gradlew :bff:bootRun
```

#### gRPC モード

```bash
APP_CALL_MODE=grpc ./gradlew :bff:bootRun
```

- 待受ポート:
  - `19090`

### 2-4. 補足

- BFF は比較ごとに `app.call-mode` を切り替えて起動する
- REST / gRPC backend は両方起動したままでよい
- PowerShell で環境変数を一時設定する場合は以下を使う

```powershell
$env:APP_CALL_MODE = "rest"
./gradlew :bff:bootRun
```

```powershell
$env:APP_CALL_MODE = "grpc"
./gradlew :bff:bootRun
```

---

## 3. 動作確認

### 3-1. users API

```bash
curl http://localhost:19090/api/users/1
```

### 3-2. orders API

```bash
curl -X POST http://localhost:19090/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId":"1","itemCode":"ITEM-001","quantity":1}'
```

### 3-3. 確認内容

- BFF 経由で応答が返ること
- `app.call-mode` を切り替えても疎通できること
- アプリケーションログに例外が出ていないこと

---

## 4. k6 実行

### 4-1. 共通ルール

- `run_id` は毎回ユニークにする
- 同じ `run_id` を再利用しない
- 比較に使う正式値は Grafana ではなく k6 summary を採用する
- Grafana は raw checks / trace / logs の確認用途とする

### 4-2. 共通環境変数

#### bash

```bash
export BASE_URL=http://localhost:19090
export GIT_SHA=$(git rev-parse --short HEAD)
```

#### PowerShell

```powershell
$env:BASE_URL = "http://localhost:19090"
$env:GIT_SHA = (git rev-parse --short HEAD)
```

### 4-3. users-read（REST）

#### bash

```bash
RUN_ID=local-$(date +%Y%m%d-%H%M%S)-users-read-rest

k6 run \
  --tag run_id=$RUN_ID \
  --tag git_sha=$GIT_SHA \
  --tag scenario=users-read \
  --tag call_mode=rest \
  --tag api=users-read \
  --out opentelemetry \
  k6/users-read.js
```

#### PowerShell

```powershell
$env:RUN_ID = "local-$(Get-Date -Format yyyyMMdd-HHmmss)-users-read-rest"

k6 run `
  --tag run_id=$env:RUN_ID `
  --tag git_sha=$env:GIT_SHA `
  --tag scenario=users-read `
  --tag call_mode=rest `
  --tag api=users-read `
  --out opentelemetry `
  k6/users-read.js
```

### 4-4. users-read（gRPC）

#### bash

```bash
RUN_ID=local-$(date +%Y%m%d-%H%M%S)-users-read-grpc

k6 run \
  --tag run_id=$RUN_ID \
  --tag git_sha=$GIT_SHA \
  --tag scenario=users-read \
  --tag call_mode=grpc \
  --tag api=users-read \
  --out opentelemetry \
  k6/users-read.js
```

#### PowerShell

```powershell
$env:RUN_ID = "local-$(Get-Date -Format yyyyMMdd-HHmmss)-users-read-grpc"

k6 run `
  --tag run_id=$env:RUN_ID `
  --tag git_sha=$env:GIT_SHA `
  --tag scenario=users-read `
  --tag call_mode=grpc `
  --tag api=users-read `
  --out opentelemetry `
  k6/users-read.js
```

### 4-5. orders-write（REST）

#### bash

```bash
RUN_ID=local-$(date +%Y%m%d-%H%M%S)-orders-rest

k6 run \
  --tag run_id=$RUN_ID \
  --tag git_sha=$GIT_SHA \
  --tag scenario=orders-write \
  --tag call_mode=rest \
  --tag api=create-order \
  --out opentelemetry \
  k6/orders-create.js
```

#### PowerShell

```powershell
$env:RUN_ID = "local-$(Get-Date -Format yyyyMMdd-HHmmss)-orders-rest"

k6 run `
  --tag run_id=$env:RUN_ID `
  --tag git_sha=$env:GIT_SHA `
  --tag scenario=orders-write `
  --tag call_mode=rest `
  --tag api=create-order `
  --out opentelemetry `
  k6/orders-create.js
```

### 4-6. orders-write（gRPC）

#### bash

```bash
RUN_ID=local-$(date +%Y%m%d-%H%M%S)-orders-grpc

k6 run \
  --tag run_id=$RUN_ID \
  --tag git_sha=$GIT_SHA \
  --tag scenario=orders-write \
  --tag call_mode=grpc \
  --tag api=create-order \
  --out opentelemetry \
  k6/orders-create.js
```

#### PowerShell

```powershell
$env:RUN_ID = "local-$(Get-Date -Format yyyyMMdd-HHmmss)-orders-grpc"

k6 run `
  --tag run_id=$env:RUN_ID `
  --tag git_sha=$env:GIT_SHA `
  --tag scenario=orders-write `
  --tag call_mode=grpc `
  --tag api=create-order `
  --out opentelemetry `
  k6/orders-create.js
```

---

## 5. k6 summary の記録

### 5-1. 記録対象

各 run ごとに以下を比較表へ転記する。

- `http_req_duration` の `avg`
- `http_req_duration` の `med`
- `http_req_duration` の `p(90)`
- `http_req_duration` の `p(95)`
- `http_req_duration` の `p(99)`
- `http_req_duration` の `max`
- `http_reqs`
- `iterations`
- `http_req_failed`
- `checks_succeeded`
- `checks_failed`

### 5-2. 例

```text
http_req_duration........: avg=9.81ms med=8.74ms p(90)=11.20ms p(95)=12.30ms p(99)=15.42ms max=21.08ms
http_reqs................: 10
iterations...............: 10
http_req_failed..........: 0.00%
checks_succeeded.........: 100%
checks_failed............: 0%
```

### 5-3. 補足

- 比較の正式値はこの k6 summary を採用する
- Collector 経由の Grafana rate 系集計は、PoC 段階では run により揺れがあるため参考値扱いとする

---

## 6. Grafana での確認

### 6-1. 主用途

- run ごとの raw checks 確認
- trace 確認
- logs 確認
- `run_id / api / call_mode / scenario` のタグ確認

### 6-2. k6 実行結果 Overview で安定確認できたクエリ

```promql
sum by (check, condition, run_id, api, call_mode, scenario) (
  last_over_time(
    k6_checks_total[30d]
  )
)
```

### 6-3. 見方

- `condition="nonzero"`:
  - 正常系の確認用

- `condition="zero"`:
  - 異常系列の混入確認用

### 6-4. 判断

- `k6 summary` が 100% 成功でも、Grafana 上で `condition="zero"` が混ざる run があった
- そのため、Grafana の checks は raw データ確認に用途を限定する
- 異常 run は比較対象から除外する

### 6-5. Spring Services Overview の扱い

- `HTTP request rate (recent)` は直近の流量確認に用いる
- `HTTP request count (selected range)` は選択時間範囲の件数確認に用いる
- `HTTP error count (selected range)` は選択時間範囲の 4xx / 5xx 件数確認に用いる
- `*_bucket` 系メトリクスが現環境で確認できないため、p95 latency パネルは採用しない
- `otelcol_exporter_sent_metric_points` が現環境で確認できないため、Collector sent metric points パネルは採用しない

---

## 7. 比較実施手順

### 7-1. users-read

- REST を 3 回実行
- gRPC を 3 回実行

### 7-2. orders-write

- REST を 3 回実行
- gRPC を 3 回実行

### 7-3. 比較表に記録する項目

- `run_id`
- `scenario`
- `call_mode`
- `avg`
- `med`
- `p90`
- `p95`
- `p99`
- `max`
- `http_reqs`
- `iterations`
- `error rate`
- `checks_succeeded`
- `checks_failed`
- 備考

### 7-4. 異常 run の扱い

- `condition="zero"` 混在など、実行実態と合わない run は除外する
- 例:
  - `local-20260326-orders-rest-03`

- 除外した場合は、新しい `run_id` で再実行して補完する

---

## 8. トラブルシュート

### 8-1. k6 の checks は 100% なのに Grafana で値が合わない

原因:

- Collector 経由の checks メトリクスで `condition="zero"` が混在している可能性がある

対応:

- 比較値は k6 summary を採用する
- Grafana では raw checks のみ確認する
- 異常 run は除外する

### 8-2. k6 実行結果 Overview が No data になる

原因:

- `last_over_time(k6_checks_total[1h])` のように時間窓が短く、過去 run を拾えていない
- 参照時間範囲とクエリ内の range vector が噛み合っていない

対応:

- `last_over_time(k6_checks_total[30d])` を使う
- 右上の時間範囲を十分広く取る
- 自動 refresh は必要時のみ有効化する

### 8-3. Spring Services Overview の一部パネルが空になる

原因:

- 現環境に存在しないメトリクス名を参照している可能性がある
- `*_bucket` 系メトリクスや Collector 系メトリクスが存在しない可能性がある

対応:

- まず `http_server_requests_seconds_count` の存在を確認する
- 存在するメトリクスに合わせてダッシュボードを簡素化する
- p95 latency や Collector sent metric points は、メトリクスが確認できるまで採用しない

### 8-4. Grafana が No data になる

原因:

- 変数フィルタの掛けすぎ
- ラベル整合性の揺れ
- 参照時間範囲の不足

対応:

- まず raw クエリで全体を見る
- 変数依存を増やしすぎない
- 必要に応じて time range を広げる

### 8-5. `POST /api/orders` が失敗する

確認ポイント:

- BFF の `app.call-mode`
- backend の起動状態
- payload の項目名
  - `userId`
  - `itemCode`
  - `quantity`

### 8-6. run が混ざる

原因:

- 同じ `run_id` を再利用している

対応:

- `run_id` は毎回ユニークにする
- 再実行時は必ず新しい `run_id` を採番する

### 8-7. ポート競合で起動できない

確認ポイント:

- 既存の Java プロセス
- 既存の Docker コンテナ
- Grafana / Prometheus / backend のポート使用状況

---

## 9. Keploy による通常 CI 回帰確認

### 9-1. 位置づけ

- 通常 CI の目的は、REST 基準で生成した Keploy テストケースを使って、gRPC 実装が BFF の外部 API 契約を壊していないかを確認することである
- 通常 CI では、`bff/keploy/test-set-rest` を基準資産として使う
- `bff/keploy/test-set-grpc` は補助的な比較資産であり、現時点では通常 CI の正本にはしない
- REST backend の再 record は通常 CI に含めない
- Bruno / k6 / Grafana も通常 CI の workflow には含めない

### 9-2. 実行ファイル

- workflow:
  - `.github/workflows/keploy-grpc-regression.yml`
- 実行スクリプト:
  - `.github/scripts/run-keploy-grpc-regression.sh`

### 9-3. workflow の実行概要

1. GitHub Actions の `ubuntu-latest` ランナーで checkout する
2. Java 21 をセットアップし、Gradle キャッシュを有効化する
3. Keploy CLI を Linux native 方式でインストールする
4. `grpc-backend` を実起動し、`19091/actuator/health` と `29090` の待受を確認する
5. BFF は Keploy から `app.call-mode=grpc` で起動し、`test-set-rest` を使って `keploy test` を実行する
6. 実行後に Keploy レポートとログを artifact として回収する

現在の workflow では、Keploy 実行時に以下の方針を取っている。

- `--path keploy`
- `--test-sets test-set-rest`
- `--mocking=false`
- BFF は `--app.call-mode=grpc` で起動する

### 9-4. `--mocking=false` を採用している意味

- この workflow は、record 済み mock に閉じた純粋 replay を目的としていない
- gRPC backend を実起動した状態で、REST 基準ケースに対して BFF の外部 API 契約が維持されているかを確認する
- そのため、Keploy を使ってはいるが、位置づけとしては「REST 基準ケースを使った gRPC 実装の回帰確認」に近い
- REST backend を起動しないのは、通常 CI で確認したい対象が「gRPC 実装が REST 基準の外部 API を壊していないか」であるためである

### 9-5. 注意点

- `test-set-rest` の更新は通常 CI では行わない
- 基準ケースの更新が必要な場合は、Bruno による手動確認で外部 API の見え方を確認したうえで、Keploy YAML を手動で見直す
- `test-set-grpc` は通常 CI の正本ではないため、運用判断なしに workflow の基準資産へ切り替えない
- `--mocking=false` のため、失敗要因には Keploy の比較差分だけでなく、gRPC backend の起動不良や BFF の起動不良も含まれる
- workflow は追加済みだが、この環境では GitHub Actions 上での実行確認までは未実施である

### 9-6. 役割分担の整理

- Bruno:
  - 手動確認用
  - 外部 API の見え方の確認用
- Keploy:
  - 通常 CI の回帰確認用
  - REST 基準ケースを使った gRPC 実装の契約確認用
- k6:
  - 性能比較の正本
- Grafana:
  - 観測確認用

---

## 10. 補足メモ

- PoC 段階では「ダッシュボードで全部の比較値を完結させる」よりも、「k6 summary を正本として比較表を固める」方が安定して進めやすい
- Grafana は trace / logs / raw checks の確認基盤としては十分有効
- k6 実行結果 Overview は、過去 run を参照する用途では広めの range vector を使う方が安定する
- Spring Services Overview は、現環境で存在するメトリクス名に合わせて維持する方が安全

```

確認に使った元情報は、実行メモ :contentReference[oaicite:0]{index=0}、Observability 環境利用ガイド :contentReference[oaicite:1]{index=1}、現在の `docs/trace-results.md` です。
```
