# runbook

## 前提

- Docker Desktop が起動していること
- Java / Gradle が利用可能であること
- Node.js / npm が利用可能であること
- k6 が利用可能であること
- ローカルで以下のポートが空いていること
  - `13000` (Grafana)
  - `19090` (BFF)
  - `19091` (gRPC backend HTTP)
  - `19092` (REST backend)
  - `19093` (Prometheus)
  - `29090` (gRPC backend gRPC)

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
  - HTTP:
    - `19091`

  - gRPC:
    - `29090`

### 2-3. BFF

#### REST モード

```bash
./gradlew :bff:bootRun --args="--app.call-mode=rest"
```

#### gRPC モード

```bash
./gradlew :bff:bootRun --args="--app.call-mode=grpc"
```

- 待受ポート:
  - `19090`

### 2-4. 補足

- BFF は比較ごとに `app.call-mode` を切り替えて起動する
- REST / gRPC backend は比較対象に応じて必要な方を起動する
- PowerShell で実行する場合も `--args` 方式でそろえる

```powershell
./gradlew :bff:bootRun --args="--app.call-mode=rest"
```

```powershell
./gradlew :bff:bootRun --args="--app.call-mode=grpc"
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

### 4-1. 位置づけ

- k6 は REST / gRPC の性能比較に使う
- 比較に使う正式値は Grafana ではなく k6 summary artifact を採用する
- Grafana は raw checks / trace / logs の観測確認に使う

### 4-2. ローカル手動実行

#### 共通ルール

- `run_id` は毎回ユニークにする
- 同じ `run_id` を再利用しない
- Grafana 上の値は観測確認用とし、比較の正式値には使わない

#### 共通環境変数

##### bash

```bash
export BASE_URL=http://localhost:19090
export GIT_SHA=$(git rev-parse --short HEAD)
```

##### PowerShell

```powershell
$env:BASE_URL = "http://localhost:19090"
$env:GIT_SHA = (git rev-parse --short HEAD)
```

#### users-read（REST）

##### bash

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

##### PowerShell

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

#### users-read（gRPC）

##### bash

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

##### PowerShell

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

#### orders-write（REST）

##### bash

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

##### PowerShell

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

#### orders-write（gRPC）

##### bash

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

##### PowerShell

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

### 4-3. GitHub Actions での benchmark 実行

- workflow:
  - `.github/workflows/k6-benchmark.yml`

- 位置づけ:
  - 手動実行で REST / gRPC を同条件で直列比較する
  - 通常 CI ではなく `workflow_dispatch` で使う
  - 比較の正本は artifact に保存した summary とログとする

- 入力:
  - `run_target`
    - `both` / `rest` / `grpc`

  - `scenario_target`
    - `both` / `users` / `orders`

  - `vus`
  - `ramp_up`
  - `steady`
  - `ramp_down`

- 実行概要:
  1. checkout
  2. Java 21 をセットアップ
  3. k6 をセットアップ
  4. REST / gRPC を必要に応じて直列実行
  5. artifact を回収

- 保存される artifact:
  - `artifacts/ci/k6-benchmark/<timestamp>/rest/users/summary.json`
  - `artifacts/ci/k6-benchmark/<timestamp>/rest/users/summary.txt`
  - `artifacts/ci/k6-benchmark/<timestamp>/rest/orders/summary.json`
  - `artifacts/ci/k6-benchmark/<timestamp>/rest/orders/summary.txt`
  - `artifacts/ci/k6-benchmark/<timestamp>/grpc/users/summary.json`
  - `artifacts/ci/k6-benchmark/<timestamp>/grpc/users/summary.txt`
  - `artifacts/ci/k6-benchmark/<timestamp>/grpc/orders/summary.json`
  - `artifacts/ci/k6-benchmark/<timestamp>/grpc/orders/summary.txt`
  - `artifacts/ci/k6-benchmark/<timestamp>/summary.md`
  - mode ごとの BFF / backend logs

### 4-4. k6 summary の記録

#### 記録対象

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

#### 例

```text
http_req_duration........: avg=9.81ms med=8.74ms p(90)=11.20ms p(95)=12.30ms p(99)=15.42ms max=21.08ms
http_reqs................: 10
iterations...............: 10
http_req_failed..........: 0.00%
checks_succeeded.........: 100%
checks_failed............: 0%
```

#### 補足

- 比較の正式値はこの k6 summary を採用する
- Collector 経由の Grafana rate 系集計は、PoC 段階では run により揺れがあるため参考値扱いとする

---

## 5. Grafana での確認

### 5-1. k6 の確認

#### 主用途

- run ごとの raw checks 確認
- trace 確認
- logs 確認
- `run_id / api / call_mode / scenario` のタグ確認

#### k6 実行結果 Overview で安定確認できたクエリ

```promql
sum by (check, condition, run_id, api, call_mode, scenario) (
  last_over_time(
    k6_checks_total[30d]
  )
)
```

#### 見方

- `condition="nonzero"`:
  - 正常系の確認用

- `condition="zero"`:
  - 異常系列の混入確認用

#### 判断

- `k6 summary` が 100% 成功でも、Grafana 上で `condition="zero"` が混ざる run があった
- そのため、Grafana の checks は raw データ確認に用途を限定する
- 異常 run は比較対象から除外する

### 5-2. Spring Services Overview の扱い

- `HTTP request rate (recent)` は直近の流量確認に用いる
- `HTTP request count (selected range)` は選択時間範囲の件数確認に用いる
- `HTTP error count (selected range)` は選択時間範囲の 4xx / 5xx 件数確認に用いる
- `*_bucket` 系メトリクスが現環境で確認できないため、p95 latency パネルは採用しない
- `otelcol_exporter_sent_metric_points` が現環境で確認できないため、Collector sent metric points パネルは採用しない

### 5-3. Keploy 回帰確認 Overview の扱い

- dashboard:
  - `Keploy 回帰確認 Overview`

- 主用途:
  - Keploy 実行ログの確認
  - BFF / backend の request count 確認
  - Keploy 実行時の BFF / backend logs 確認
  - `rest` / `grpc` の run header 切り分け確認

- 主な panel:
  - `Keploy complete runs`
  - `Passed testcase lines`
  - `Failed testcase lines`
  - `BFF requests (selected range)`
  - `BFF request count (selected range)`
  - `Backend request count (selected range)`
  - `Keploy logs`
  - `Keploy rest run headers`
  - `Keploy grpc run headers`
  - `BFF logs`
  - `REST backend logs`
  - `gRPC backend logs`

- 観測上の注意:
  - `GET /actuator/prometheus` の scrape が request count に多く含まれる
  - API 本体だけを見たい場合は、将来的に scrape 系 endpoint を除外した panel を追加した方が見やすい
  - 回帰判定の正本は Grafana ではなく workflow / Keploy report とする

---

## 6. 比較実施手順

### 6-1. users-read

- REST を 3 回実行
- gRPC を 3 回実行

### 6-2. orders-write

- REST を 3 回実行
- gRPC を 3 回実行

### 6-3. 比較表に記録する項目

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

### 6-4. 異常 run の扱い

- `condition="zero"` 混在など、実行実態と合わない run は除外する
- 例:
  - `local-20260326-orders-rest-03`

- 除外した場合は、新しい `run_id` で再実行して補完する

---

## 7. Keploy による通常 CI 回帰確認

### 7-1. 位置づけ

- 通常 CI の目的は、REST 基準で生成した Keploy テストケースを使って、gRPC 実装が BFF の外部 API 契約を壊していないかを確認することである
- 通常 CI では、`bff/keploy/test-set-rest` を基準資産として使う
- `bff/keploy/test-set-grpc` は補助的な比較資産であり、現時点では通常 CI の正本にはしない
- REST backend の再 record は通常 CI に含めない
- Bruno / k6 / Grafana も通常 CI の workflow には含めない

### 7-2. 実行ファイル

- workflow:
  - `.github/workflows/keploy-grpc-regression.yml`

- 実行スクリプト:
  - `.github/scripts/run-keploy-grpc-regression.sh`

### 7-3. workflow の実行概要

1. GitHub Actions の `ubuntu-latest` ランナーで checkout する
2. Java 21 をセットアップし、Gradle キャッシュを有効化する
3. Keploy CLI を Linux native 方式でインストールする
4. `run_target` に応じて `rest` / `grpc` を選択し、通常運用では `rest -> grpc` の順に直列実行する
5. `rest` 実行時は `rest-backend` を起動し、`19092/actuator/health` を確認する
6. `grpc` 実行時は `grpc-backend` を起動し、`19091/actuator/health` と `29090` の待受を確認する
7. BFF は Keploy から `--app.call-mode=rest` または `--app.call-mode=grpc` で起動し、`test-set-rest` を使って `keploy test` を実行する
8. 実行後に Keploy レポートとログを artifact として回収する

現在の workflow では、Keploy 実行時に以下の方針を取っている。

- `--path <bff project root>`
- `--test-sets test-set-rest`
- `--mocking=false`

### 7-4. `--mocking=false` を採用している意味

- この workflow は、record 済み mock に閉じた純粋 replay を目的としていない
- backend を実起動した状態で、REST 基準ケースに対して BFF の外部 API 契約が維持されているかを確認する
- そのため、Keploy を使ってはいるが、位置づけとしては「REST 基準ケースを使った backend 実起動込みの統合回帰確認」に近い

### 7-5. 注意点

- `test-set-rest` の更新は通常 CI では行わない
- 基準ケースの更新が必要な場合は、Bruno による手動確認で外部 API の見え方を確認したうえで、Keploy YAML を手動で見直す
- `test-set-grpc` は通常 CI の正本ではないため、運用判断なしに workflow の基準資産へ切り替えない
- `--mocking=false` のため、失敗要因には Keploy の比較差分だけでなく、backend の起動不良や BFF の起動不良も含まれる
- 通常の回帰判定は workflow の success / failure と Keploy report を正本にする

---

## 8. Keploy の Grafana 観測確認

### 8-1. 位置づけ

- Keploy の通常 CI は回帰判定の正本
- それとは別に、Grafana 上で Keploy 実行中のログと request count を観測する手動 workflow を用意する
- 目的は「失敗原因の切り分け」と「Keploy 実行時に何が起きたかの把握」である

### 8-2. 実行ファイル

- workflow:
  - `.github/workflows/keploy-grafana-observability.yml`

- dashboard:
  - `observability/grafana/dashboards/keploy-regression-overview.json`

### 8-3. workflow の実行概要

1. observability stack を起動する
2. Grafana / Prometheus / Collector Health を待つ
3. Keploy CLI をインストールする
4. `run_target` に応じて `rest` / `grpc` / `both` を実行する
5. Keploy 実行ログを `observability/logs/keploy-rest.log` / `keploy-grpc.log` として Collector が拾える位置に配置する
6. Grafana health、Prometheus metric names、docker compose ps / logs を snapshot artifact として回収する
7. 実行後に observability stack を停止する

### 8-4. 役割分担

- Keploy workflow / report:
  - 回帰判定の正本

- Grafana:
  - 失敗原因分析
  - 周辺 request の確認
  - BFF / backend / Keploy logs の横断確認

---

## 9. トラブルシュート

### 9-1. k6 の checks は 100% なのに Grafana で値が合わない

原因:

- Collector 経由の checks メトリクスで `condition="zero"` が混在している可能性がある

対応:

- 比較値は k6 summary を採用する
- Grafana では raw checks のみ確認する
- 異常 run は除外する

### 9-2. k6 実行結果 Overview が No data になる

原因:

- `last_over_time(k6_checks_total[1h])` のように時間窓が短く、過去 run を拾えていない
- 参照時間範囲とクエリ内の range vector が噛み合っていない

対応:

- `last_over_time(k6_checks_total[30d])` を使う
- 右上の時間範囲を十分広く取る
- 自動 refresh は必要時のみ有効化する

### 9-3. Spring Services Overview の一部パネルが空になる

原因:

- 現環境に存在しないメトリクス名を参照している可能性がある
- `*_bucket` 系メトリクスや Collector 系メトリクスが存在しない可能性がある

対応:

- まず `http_server_requests_seconds_count` の存在を確認する
- 存在するメトリクスに合わせてダッシュボードを簡素化する
- p95 latency や Collector sent metric points は、メトリクスが確認できるまで採用しない

### 9-4. Grafana が No data になる

原因:

- 変数フィルタの掛けすぎ
- ラベル整合性の揺れ
- 参照時間範囲の不足

対応:

- まず raw クエリで全体を見る
- 変数依存を増やしすぎない
- 必要に応じて time range を広げる

### 9-5. `POST /api/orders` が失敗する

確認ポイント:

- BFF の `app.call-mode`
- backend の起動状態
- payload の項目名
  - `userId`
  - `itemCode`
  - `quantity`

### 9-6. run が混ざる

原因:

- 同じ `run_id` を再利用している

対応:

- `run_id` は毎回ユニークにする
- 再実行時は必ず新しい `run_id` を採番する

### 9-7. ポート競合で起動できない

確認ポイント:

- 既存の Java プロセス
- 既存の Docker コンテナ
- Grafana / Prometheus / backend のポート使用状況

### 9-8. Keploy dashboard では pass しているのに CI が失敗する

原因:

- Grafana は観測確認用であり、workflow の exit code と完全一致する判定系ではない
- backend 起動不良や BFF 起動不良で workflow が落ちている可能性がある

対応:

- まず GitHub Actions の job 結果を確認する
- 次に Keploy report と artifact を確認する
- その後、Grafana の logs / request count で周辺状況を確認する

---

## 10. 補足メモ

- PoC 段階では「ダッシュボードで全部の比較値を完結させる」よりも、「artifact と report を正本として比較表を固める」方が安定して進めやすい
- Grafana は trace / logs / raw checks / request count の確認基盤として十分有効
- k6 実行結果 Overview は、過去 run を参照する用途では広めの range vector を使う方が安定する
- Keploy 回帰確認 Overview は、PoC 段階のトラブルシュートに有効である
- PoC 検証完了時点の役割分担は以下の通りとする
  - Bruno:
    - 外部 API の手動確認と正解決め

  - Keploy:
    - REST 基準ケースを使った通常 CI の契約回帰確認

  - k6:
    - REST / gRPC の性能比較

  - Grafana:
    - k6 / Keploy 実行時の観測確認と失敗原因の補助分析

```

```
