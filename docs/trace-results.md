# trace 結果

## 前提

- 計測対象:
  - OpenTelemetry を有効にした BFF (`http://localhost:19090`) 経由の `GET /api/users/{id}` リクエスト
  - OpenTelemetry を有効にした BFF (`http://localhost:19090`) 経由の `POST /api/orders` リクエスト
- 比較方式: `app.call-mode=rest` / `app.call-mode=grpc`
- 対象 API:
  - `GET /api/users/{id}`
  - `POST /api/orders`
- 取得元:
  - Jaeger / Grafana / Tempo 上の trace
  - `observability/traces/` 配下の保存データ
- 集計条件:
  - BFF の server span を起点に backend 呼び出しまで trace が連結しているものを対象とする
  - `GET /api/users/{id}` は 2026-03-26 時点の単回観測結果を整理した
  - `POST /api/orders` は観測基盤統合後の疎通確認結果と可視化状態を整理した

---

## 1. 単回観測結果

### 1-1. GET /api/users/{id}

| Mode | trace 件数 | 1 trace あたり span 数 | BFF -> backend 連携                                                                                     | span 構造                                                                                                                                   | 正常系ステータス                                                                                              | エラー有無 |
| ---- | ---------- | ---------------------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ---------- |
| REST | 10         | 3                      | 全 10 trace で同一 traceID を維持し、`bff server -> bff client -> rest-backend server` の親子関係を確認 | `bff: GET /api/users/{id}` -> `bff: GET` -> `rest-backend: GET /api/users/{id}`                                                             | 全 span で `http.response.status_code=200`                                                                    | なし       |
| gRPC | 10         | 3                      | 全 10 trace で同一 traceID を維持し、`bff server -> bff client -> grpc-backend server` の親子関係を確認 | `bff: GET /api/users/{id}` -> `bff: sccapi.grpcbackend.v1.UserService/GetUser` -> `grpc-backend: sccapi.grpcbackend.v1.UserService/GetUser` | BFF server span は `http.response.status_code=200`、gRPC client / server span は全件 `rpc.grpc.status_code=0` | なし       |

### 1-2. span duration 代表値

| Mode | BFF server avg | BFF server med | BFF server max | BFF outbound avg | BFF outbound med | BFF outbound max | backend server avg | backend server med | backend server max | 備考                                                                                |
| ---- | -------------- | -------------- | -------------- | ---------------- | ---------------- | ---------------- | ------------------ | ------------------ | ------------------ | ----------------------------------------------------------------------------------- |
| REST | 22.99ms        | 11.44ms        | 132.07ms       | 14.48ms          | 6.70ms           | 86.59ms          | 8.40ms             | 3.80ms             | 50.59ms            | 中央値は 3 区間とも 12ms 未満でまとまるが、132.07ms の高値 1 件で平均値が上振れした |
| gRPC | 180.82ms       | 9.36ms         | 1717.47ms      | 132.98ms         | 5.93ms           | 1269.84ms        | 20.83ms            | 2.34ms             | 182.05ms           | 中央値は REST より低いが、1717.47ms の外れ値 1 件で平均値が大きく押し上げられた     |

### 1-3. 最大 trace

| Mode | traceID                            | BFF server | BFF outbound | backend server | 補足                                                                                    |
| ---- | ---------------------------------- | ---------- | ------------ | -------------- | --------------------------------------------------------------------------------------- |
| REST | `14d38cbdfe01fb931d021c5f32101083` | 132.07ms   | 86.59ms      | 50.59ms        | 他 9 件の BFF server span は 7.45ms - 13.66ms に収まっていた                            |
| gRPC | `0974b23ada65d260a649341c60d23d9e` | 1717.47ms  | 1269.84ms    | 182.05ms       | 他 9 件の BFF server span は 7.65ms - 14.75ms に収まっており、この 1 件だけ乖離が大きい |

---

## 2. 観測基盤統合結果

### 2-1. 構成

- Grafana
- Prometheus
- Tempo
- Loki
- OpenTelemetry Collector
- OpenTelemetry Java Agent
- k6 (`--out opentelemetry`)

### 2-2. 確認できたこと

| 観点         | REST     | gRPC     | 補足                                      |
| ------------ | -------- | -------- | ----------------------------------------- |
| API 疎通     | 確認済み | 確認済み | BFF の `app.call-mode` 切替で両経路を実行 |
| trace 収集   | 確認済み | 確認済み | BFF -> backend の分散トレースを確認       |
| metrics 収集 | 確認済み | 確認済み | Prometheus / Grafana で確認               |
| logs 収集    | 確認済み | 確認済み | Loki で参照可能                           |
| k6 連携      | 確認済み | 確認済み | Collector 経由でメトリクス送信を確認      |

### 2-3. k6 観測結果の扱い

- `POST /api/orders` 用の k6 スクリプト修正後、k6 summary 上では REST / gRPC ともに正常系チェック 100% を確認した
- 一方で、Collector 経由で Prometheus に取り込んだ k6 メトリクスでは、run によって `condition="zero"` / `condition="nonzero"` の混在が見られた
- 特に `local-20260326-orders-rest-03` は、Grafana 上の checks 集計値が k6 summary と一致しない異常 run 候補として確認された
- このため、Grafana 上の rate 系集計は比較の正式値とはせず、k6 summary を正本として扱う方針に切り替えた
- Grafana では raw checks、trace、logs、run ごとのタグ確認を主用途とする

### 2-4. Grafana で安定確認できた raw checks クエリ

```promql
sum by (check, condition, run_id, api, call_mode, scenario) (
    last_over_time(
        k6_checks_total[30d]
    )
)
```

### 2-5. Grafana ダッシュボード見直し結果

- `k6 実行結果 Overview` は、過去 run を見返す用途では `last_over_time(k6_checks_total[1h])` だと時間窓が短く、数日前の実行結果を表示できなかった
- raw checks パネルは `last_over_time(k6_checks_total[30d])` に見直すことで、過去 run を継続参照できることを確認した
- `Spring Services Overview` は、`http_server_requests_seconds_count` を基準にした request rate / request count / error count の表示は成立した
- 一方で、`*_bucket` 系メトリクスおよび `otelcol_exporter_sent_metric_points` は現環境では確認できず、p95 latency パネルおよび Collector sent metric points パネルは成立しなかった
- そのため、Spring Services Overview は現時点で存在確認できたメトリクスに合わせて簡素化し、空パネルを除去した構成を採用する

---

## 3. 所感

### 3-1. GET /api/users/{id}

- REST / gRPC ともに 10 trace すべてで 3 span 構成となっており、BFF の入口 span から backend の server span まで同一 traceID で連携していた。今回の取得範囲では、BFF -> backend の分散トレース伝搬は両方式で確認できた。
- REST の span 構造は HTTP リクエストとして素直に読める一方、BFF 側 outbound span 名は `GET` のみで、span 名だけでは呼び出し先 API を判別しづらい。backend 側は `GET /api/users/{id}` まで出るため、全体構造は追えるが BFF 側の識別力は高くない。
- gRPC は BFF 側 outbound span と backend 側 span のどちらも `sccapi.grpcbackend.v1.UserService/GetUser` が出るため、サービス境界とメソッド名を span 名だけで把握しやすい。trace のつながり方を確認する観点では、REST より gRPC の方が読みやすかった。
- 正常系ステータスの見え方は REST と gRPC で異なる。REST は全 span で `http.response.status_code=200` を確認できた一方、gRPC は BFF の入口 span が HTTP `200`、RPC 区間が `rpc.grpc.status_code=0` で正常終了を示していた。
- 中央値ベースでは gRPC が BFF server 9.36ms、BFF outbound 5.93ms、backend server 2.34ms と、REST の 11.44ms、6.70ms、3.80ms より各区間で低かった。単回観測の範囲では、gRPC がやや低レイテンシな傾向だった。
- 外れ値は gRPC で顕著で、1 trace が BFF server 1717.47ms、BFF outbound 1269.84ms まで伸びて平均値を大きく押し上げていた。REST にも 132.07ms の高値 1 件はあるが、中央値との乖離は gRPC ほど大きくないため、今回の比較は平均値より中央値を主に見るのが妥当と判断できる。

### 3-2. POST /api/orders と観測基盤

- `POST /api/orders` は REST / gRPC ともに API 動作と trace / metrics / logs の可視化を確認できた。
- k6 を OpenTelemetry Collector 経由で統合したことで、アプリケーション観測と負荷試験結果を同一基盤上で参照できる状態になった点は有益である。
- 一方で、k6 メトリクスは run により `condition` 系列やラベル整合性に揺れがあり、Grafana 上で error rate や check success rate を単純算出すると、k6 summary と一致しないケースがあった。
- このため、PoC 段階では「Grafana は観測確認用途」「比較の正式値は k6 summary」という役割分担にするのが妥当である。
- Grafana ダッシュボードは、存在するメトリクス名に合わせて見直すことで安定運用しやすくなった。
- 今後は `POST /api/orders` の trace 取得と、エラー系 trace の比較を追加すると、可観測性比較の解像度をさらに上げられる。

---

## 4. 暫定まとめ

- `GET /api/users/{id}` の trace は REST / gRPC ともに 10 件取得でき、全件で 3 span 構成の BFF -> backend 連携を確認できた。
- span 名の見え方は gRPC の方が明確で、BFF 側 outbound / backend 側ともに RPC メソッド名がそのまま出るため、追跡しやすかった。
- duration は中央値ベースで gRPC が REST より低く、今回の単回観測では gRPC がやや低レイテンシだった。
- ただし gRPC には 1717.47ms の外れ値 1 件があり、平均値だけで評価すると実態を見誤るため、継続比較では中央値ベースの確認を優先したい。
- 観測基盤統合により、trace / metrics / logs / k6 を同一基盤で確認できる状態は整った。
- 一方で、Collector 経由の k6 rate 系集計には run 依存の揺れがあるため、比較値の正本としては k6 summary を使う方が安定している。
- Grafana ダッシュボードは、過去 run の参照期間と現環境で存在するメトリクス名に合わせて調整する必要があることが分かった。

---

## 5. Keploy CI 回帰確認との関係

今回の trace / metrics / logs の整理により、REST / gRPC の内部呼び出し経路と観測の見え方は把握しやすくなった。
一方で、通常 CI で確認したい対象は trace の形そのものではなく、BFF の外部 API 契約が保たれているかどうかである。

そのため、PoC では以下のように役割を分けるのが適切である。

- `trace-results.md`:
  - REST / gRPC の内部挙動
  - span 構造
  - 観測基盤上での見え方
    を整理する資料

- Keploy 通常 CI:
  - REST 基準で整備した HTTP テストケースを使い、gRPC 実装が BFF の外部 API 契約を壊していないかを確認する仕組み

実際に GitHub Actions 上では、`test-set-rest` を基準資産として `rest -> grpc` の順に直列実行する Keploy CI を成立させた。
これにより、trace は「内部の理解と原因調査」、Keploy は「通常 CI の契約回帰確認」という役割分担を明確にできた。

また、Keploy CI は `--mocking=false` を前提としているため、純粋な replay ではなく backend 実起動込みの統合回帰確認として扱うのが適切である。
この点でも、trace による内部観測と Keploy による外部契約確認は、補完関係にある。
