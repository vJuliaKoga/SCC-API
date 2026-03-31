# trace 確認結果メモ

## 目的

本メモは、OpenTelemetry / Jaeger / Grafana を用いた trace および関連観測結果の確認内容を記録する。
最終的には comparison-summary に転記するための元メモとする。

## 対象

- BFF
- REST backend
- gRPC backend
- k6 実行時の metrics / logs / traces
- Keploy 実行時の logs / request count / 関連 logs

## 1. GET /api/users/{id} の trace 確認

### 1.1 REST (`app.call-mode=rest`)

確認方法:

- BFF を `app.call-mode=rest` で起動
- `GET /api/users/1` を複数回実行
- Jaeger で BFF の trace を確認

確認結果:

- trace 数:
  - 10
- 1 trace あたり span 数:
  - 3
- span 構造:
  - `bff: GET /api/users/{id}`
  - `bff: GET`
  - `rest-backend: GET /api/users/{id}`
- 正常系ステータス:
  - 全件 `200`
- duration 中央値:
  - BFF server span: 11.44ms
  - BFF outbound span: 6.70ms
  - backend server span: 3.80ms

所感:

- REST は route 名がそのまま見えるため、backend 側の span は分かりやすい
- BFF outbound span は `GET` のみで、どの downstream に出たかの文脈は span 名だけでは弱い

### 1.2 gRPC (`app.call-mode=grpc`)

確認方法:

- BFF を `app.call-mode=grpc` で起動
- `GET /api/users/1` を複数回実行
- Jaeger で BFF の trace を確認

確認結果:

- trace 数:
  - 10
- 1 trace あたり span 数:
  - 3
- span 構造:
  - `bff: GET /api/users/{id}`
  - `bff: sccapi.grpcbackend.v1.UserService/GetUser`
  - `grpc-backend: sccapi.grpcbackend.v1.UserService/GetUser`
- 正常系ステータス:
  - 全件 `status_code=0`
- duration 中央値:
  - BFF server span: 9.36ms
  - BFF outbound span: 5.93ms
  - backend server span: 2.34ms
- 外れ値:
  - 最大 trace で BFF server span 1.717s
  - BFF outbound span 1.270s
  - backend server span 182ms

所感:

- gRPC は service / method 名が span に現れるため、どの RPC を通ったかが分かりやすい
- 一方で、外れ値があったため、単純な印象比較より複数回確認が必要

## 2. k6 メトリクス観測

### 2.1 構成

- k6 を `--out opentelemetry` で OpenTelemetry Collector に送信
- Collector から Prometheus / Grafana に渡して確認
- dashboard では raw checks を中心に確認

### 2.2 確認できたこと

- REST / gRPC ともに k6 のタグ付きメトリクスを送信できた
- `run_id` / `api` / `call_mode` / `scenario` 単位で raw checks を確認できた
- k6 summary 上では正常系 100% を確認できた

### 2.3 気づき

- Collector 経由の k6 メトリクスでは、`condition="zero"` と `condition="nonzero"` が run により混在した
- Grafana 上で error rate や check success rate を単純算出すると、k6 summary と一致しない run があった
- そのため、比較の正式値は Grafana ではなく k6 summary とするのが安全である
- GitHub Actions の benchmark workflow では Grafana 連携を必須にせず、summary artifact を正本として保存する方針とした

## 3. Keploy 観測

### 3.1 目的

Keploy の通常 CI は回帰判定そのものを目的とするが、失敗時や挙動確認時には、Keploy 実行ログと BFF / backend 側の request / logs を横断的に見たい。
そのため、通常 CI とは別に、observability stack を起動したうえで Keploy を実行し、Grafana 上で確認する workflow を追加した。

### 3.2 構成

- observability stack:
  - Grafana
  - Prometheus
  - Tempo
  - Loki
  - OpenTelemetry Collector
- Keploy 実行ログ:
  - `keploy-rest.log`
  - `keploy-grpc.log`
- Collector:
  - filelog receiver で Keploy 実行ログを Loki に送信
- Prometheus:
  - BFF / REST backend / gRPC backend の `http_server_requests_seconds_count` を scrape
- Grafana dashboard:
  - `Keploy 回帰確認 Overview`

### 3.3 dashboard で確認した項目

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

### 3.4 確認結果

- Keploy complete runs:
  - 4
- Passed testcase lines:
  - 32
- Failed testcase lines:
  - 0

- BFF request count の selected range では、主に以下を確認できた
  - `GET /actuator/prometheus`
  - `POST /api/orders` `201`
  - `POST /api/orders` `400`
  - `GET /api/users/{id}` `200`
  - `GET /api/users/{id}` `404`

- Backend request count の selected range では、主に以下を確認できた
  - `GET /actuator/prometheus`
  - `POST /api/orders` `201`
  - `POST /api/orders` `400`
  - `GET /api/users/{id}` `200`
  - `GET /api/users/{id}` `404`

- Keploy logs では、test run summary と testcase ごとの pass 状態を確認できた
- rest / grpc run headers では、Keploy がどの `app.call-mode` で BFF を起動したかをログから切り分けて見られた
- BFF / backend logs では、Keploy 実行時の周辺ログを同一画面で確認できた

### 3.5 所感

- Keploy 自体をメトリクス化するよりも、実行ログを Loki に送って logs / stat panel で集計する形の方が、既存の observability 構成に自然に乗せやすかった
- request count を並べることで、「Keploy は何を叩き、そのとき BFF / backend では何が起きていたか」を見やすくできた
- 一方で `GET /actuator/prometheus` の scrape が件数上大きく見えるため、API 本体の動きだけを見たいときはノイズになる
- 今後は dashboard 側で scrape 系 endpoint を除外する panel を追加した方が、障害切り分けには有効である

## 4. 暫定まとめ

- trace の見え方では、gRPC は service / method 名が明示される点で追いやすい
- k6 については、Grafana は観測確認に有効だが、比較値の正本は summary artifact とするのが妥当である
- Keploy については、回帰判定の正本は通常 CI / report としつつ、Grafana で実行ログと request count を並べて観測する導線まで整備できた
- これにより、PoC 全体として
  - Bruno:
    - 手動確認
  - Keploy:
    - 契約回帰確認
  - k6:
    - 性能比較
  - Grafana:
    - trace / logs / metrics / 実行ログの観測確認
      という役割分担をより明確にできた
