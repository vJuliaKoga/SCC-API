## 1. 前提

本結果はローカル環境における PJ ベースの比較である。

- 計測対象: BFF (`http://localhost:19090`)
- 比較方式:
  - REST: `app.call-mode=rest`
  - gRPC: `app.call-mode=grpc`
- API:
  - `GET /api/users/{id}`
  - `POST /api/orders`

本資料は、以下の結果を横断的に整理した暫定サマリーである。

- `docs/benchmark-results.md`
- `docs/trace-results.md`
- k6 実行結果
- Grafana / Prometheus / Tempo / Loki による観測結果

※ 最終判断には、CI 等での複数回実行とエラー系を含む再確認が必要。

---

## 2. 性能比較（k6）

### 2.1 GET /api/users/{id}

- REST:
  - 単回結果ではわずかに低レイテンシ
  - error rate は 0.00%

- gRPC:
  - REST とほぼ同等
  - error rate は 0.00%

- 所感:
  - 読み取り系 API では差は小さい
  - 単回実行のため、環境差や揺らぎの影響を含む可能性がある

#### 2.1.1 比較表テンプレート

| Run | Mode | run_id | avg | med | p90 | p95 | p99 | max | error rate | checks_succeeded | checks_failed | http_reqs | iterations | 判定 | 備考 |
| --- | ---- | ------ | --- | --- | --- | --- | --- | --- | ---------- | ---------------- | ------------- | --------- | ---------- | ---- | ---- |
| 1   | REST |        |     |     |     |     |     |     |            |                  |               |           |            | 採用 |      |
| 2   | REST |        |     |     |     |     |     |     |            |                  |               |           |            | 採用 |      |
| 3   | REST |        |     |     |     |     |     |     |            |                  |               |           |            | 採用 |      |
| 1   | gRPC |        |     |     |     |     |     |     |            |                  |               |           |            | 採用 |      |
| 2   | gRPC |        |     |     |     |     |     |     |            |                  |               |           |            | 採用 |      |
| 3   | gRPC |        |     |     |     |     |     |     |            |                  |               |           |            | 採用 |      |

#### 2.1.2 集計表テンプレート

| Mode | 採用 run 数 | avg 平均 | med 平均 | p90 平均 | p95 平均 | p99 平均 | max 最大 | error rate 平均 | checks_succeeded 平均 | checks_failed 平均 | http_reqs 平均 | iterations 平均 | 備考 |
| ---- | ----------- | -------- | -------- | -------- | -------- | -------- | -------- | --------------- | --------------------- | ------------------ | -------------- | --------------- | ---- |
| REST |             |          |          |          |          |          |          |                 |                       |                    |                |                 |      |
| gRPC |             |          |          |          |          |          |          |                 |                       |                    |                |                 |      |

---

### 2.2 POST /api/orders

- REST:
  - k6 スクリプト修正後、正常系チェック 100% を確認
  - 書き込み系では gRPC よりやや高めとなる傾向を確認
- gRPC:
  - 正常系チェック 100% を確認
  - p95 / p99 / max が REST より低めとなる傾向を確認

- 所感:
  - 書き込み系 API では gRPC がやや優位
  - ただし Grafana 上の rate 系集計は Collector 経由で揺れがあり、正式比較値は k6 summary を採用する
  - 異常系列が混在した run は除外して比較する必要がある

#### 2.2.1 比較表テンプレート

| Run | Mode | run_id | avg | med | p90 | p95 | p99 | max | error rate | checks_succeeded | checks_failed | http_reqs | iterations | 判定 | 備考 |
| --- | ---- | ------ | --- | --- | --- | --- | --- | --- | ---------- | ---------------- | ------------- | --------- | ---------- | ---- | ---- |
| 1   | REST |        |     |     |     |     |     |     |            |                  |               |           |            | 採用 |      |
| 2   | REST |        |     |     |     |     |     |     |            |                  |               |           |            | 採用 |      |
| 3   | REST |        |     |     |     |     |     |     |            |                  |               |           |            | 採用 |      |
| 1   | gRPC |        |     |     |     |     |     |     |            |                  |               |           |            | 採用 |      |
| 2   | gRPC |        |     |     |     |     |     |     |            |                  |               |           |            | 採用 |      |
| 3   | gRPC |        |     |     |     |     |     |     |            |                  |               |           |            | 採用 |      |

#### 2.2.2 集計表テンプレート

| Mode | 採用 run 数 | avg 平均 | med 平均 | p90 平均 | p95 平均 | p99 平均 | max 最大 | error rate 平均 | checks_succeeded 平均 | checks_failed 平均 | http_reqs 平均 | iterations 平均 | 備考 |
| ---- | ----------- | -------- | -------- | -------- | -------- | -------- | -------- | --------------- | --------------------- | ------------------ | -------------- | --------------- | ---- |
| REST |             |          |          |          |          |          |          |                 |                       |                    |                |                 |      |
| gRPC |             |          |          |          |          |          |          |                 |                       |                    |                |                 |      |

---

## 3. 可観測性比較（OpenTelemetry / Jaeger）

### 3.1 GET /api/users/{id} の trace 観測結果

- REST / gRPC ともに、`GET /api/users/{id}` について 10 trace を取得
- いずれも 1 trace あたり 3 span
- BFF -> backend の分散トレース連携を確認

### 3.2 REST の見え方

- span 構造:
  - `bff: GET /api/users/{id}`
  - `bff: GET`
  - `rest-backend: GET /api/users/{id}`
- 正常系ステータスは全件 `200`
- duration 中央値:
  - BFF server span: 11.44ms
  - BFF outbound span: 6.70ms
  - backend server span: 3.80ms

### 3.3 gRPC の見え方

- span 構造:
  - `bff: GET /api/users/{id}`
  - `bff: sccapi.grpcbackend.v1.UserService/GetUser`
  - `grpc-backend: sccapi.grpcbackend.v1.UserService/GetUser`
- 正常系ステータスは全件 `status_code=0`
- duration 中央値:
  - BFF server span: 9.36ms
  - BFF outbound span: 5.93ms
  - backend server span: 2.34ms
- 大きめの外れ値が 1 件あり、最大 trace は以下
  - BFF server span: 1.717s
  - BFF outbound span: 1.270s
  - backend server span: 182ms

### 3.4 k6 / Collector 経由メトリクスの見え方

- k6 の結果を `--out opentelemetry` で Collector に送信し、Prometheus / Grafana から参照可能にした
- trace / logs / metrics を同一基盤上で確認できる状態を構築した
- 一方で、k6 の checks 系メトリクスは run により `condition="zero"` と `condition="nonzero"` が混在するケースがあった
- そのため、Grafana 上で error rate や check success rate を単純算出すると、k6 summary と一致しない場合があった
- 現時点で安定確認できたのは、raw checks をそのまま表示するクエリである

### 3.5 可観測性の所感

- REST / gRPC ともに trace 自体は問題なくつながっている
- gRPC は service / method 名が span に現れるため、操作単位で追いやすい
- REST は backend 側 route は読みやすいが、BFF outbound span 名は `GET` のみで簡素
- k6 の観測統合により、負荷試験結果とアプリ観測を同じ基盤で見られるようになった点は有益
- 一方で、PJ 段階では k6 メトリクスの rate 系集計は不安定であり、Grafana は観測確認用途に寄せるのが妥当

---

## 4. 全体所感

- 両モードとも、k6 summary ベースでは正常系チェックは通過している
- 読み取り系 API では性能差は小さい
- 書き込み系 API では gRPC がやや低レイテンシ
- 可観測性の観点では、gRPC は method 単位で追いやすく、REST は route 単位で把握しやすい
- 観測基盤の統合により、trace / logs / metrics / k6 を横断して確認できる状態になった
- ただし Collector 経由の k6 メトリクスは一部 run で揺れがあり、比較値の正本としては k6 summary を使う方が妥当である

---

## 5. 現時点の暫定結論

- 性能面では、用途によって優位性が分かれる
  - 読み取り系: 差は小さい
  - 書き込み系: gRPC がやや有利
- 可観測性の面では、gRPC は span 名の明瞭さによりやや優位
- 観測基盤統合そのものは成立しており、PJ の目的は達成できている
- 一方で、k6 メトリクスの Collector 経由集計は一部 run で不安定さがあるため、比較の正式値は k6 summary を採用する
- 現段階では、内部サービス間通信としての gRPC には前向きな材料が揃いつつあるが、安定性確認のため複数回実行を継続したい

---

## 6. Next Action

- `POST /api/orders` について REST / gRPC の複数回実行結果を整理する
- users-read / orders-write をそれぞれ 3 回ずつ実行し、比較表を完成させる
- 異常系列が混在した run を除外し、再実行分で補完する
- エラー系 trace を取得し、見え方を比較する
- warm 状態での再計測を行い、外れ値の再現性を確認する
