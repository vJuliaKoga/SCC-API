## 1. 前提

本結果はローカル環境における PoC ベースの比較である。

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
- Keploy による通常 CI と Grafana 観測確認結果

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
  - benchmark workflow の追加により、今後は GitHub Actions 上でも同条件の再実行と artifact 比較を継続しやすくなった

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
  - 通常の k6 benchmark workflow では summary.json / summary.txt / summary.md を artifact として回収する構成にし、比較値の正本を明確にした

---

## 3. 可観測性比較（OpenTelemetry / Jaeger / Grafana）

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
- そのため、k6 は「比較値の正本は artifact」「Grafana は観測確認」という整理にした

### 3.5 Keploy / Grafana 観測の見え方

- Keploy observability workflow を追加し、observability stack を起動したうえで Keploy を実行できるようにした
- Keploy の実行ログを Loki に取り込み、Grafana dashboard `Keploy 回帰確認 Overview` で確認できるようにした
- dashboard では以下を 1 画面で確認できる
  - complete runs
  - passed testcase lines
  - failed testcase lines
  - BFF requests
  - BFF request count
  - backend request count
  - Keploy logs
  - Keploy rest / grpc run headers
  - BFF / REST backend / gRPC backend logs
- Grafana 上の確認では、complete runs は 4、passed testcase lines は 32、failed testcase lines は 0 だった
- selected range の request count では、`GET /api/users/{id}` の 200 / 404、`POST /api/orders` の 201 / 400 を確認できた
- 一方で Prometheus scrape による `GET /actuator/prometheus` が多く含まれるため、API 本体だけを見たい場合は除外条件を別途検討した方がよい

### 3.6 可観測性の所感

- REST / gRPC ともに trace 自体は問題なくつながっている
- gRPC は service / method 名が span に現れるため、操作単位で追いやすい
- REST は backend 側 route は読みやすいが、BFF outbound span 名は `GET` のみで簡素
- k6 の観測統合により、負荷試験結果とアプリ観測を同じ基盤で見られるようになった点は有益
- Keploy についても、実行ログとアプリログ、request count を Grafana で横断確認できるようになり、失敗時の切り分けがしやすくなった
- 一方で、PoC 段階では比較や回帰判定の正本はそれぞれ別に持つ方が安全である
  - k6:
    - 正本は summary artifact
  - Keploy:
    - 正本は workflow / Keploy report
  - Grafana:
    - 観測確認と失敗原因分析

---

## 4. 回帰確認比較（Keploy）

### 4.1 通常 CI の位置づけ

- `bff/keploy/test-set-rest` を正本として、gRPC 実装が BFF の外部 API 契約を壊していないかを確認する
- `--mocking=false` 前提で backend 実起動込みの統合回帰確認として扱う
- 通常運用では `rest -> grpc` を直列実行する

### 4.2 成立したこと

- GitHub Actions 上で `rest` / `grpc` の直列実行に成功した
- `test-set-rest` を用いた Keploy 実行で 8 件 PASS を確認した
- `app.call-mode=rest` と `app.call-mode=grpc` の両方で同一 test-set を基準に確認できた

### 4.3 Grafana 観測確認まで含めた整理

- 通常 CI:
  - 回帰判定の正本
- Keploy observability workflow:
  - Grafana 上でログと request count を横断確認する補助用途
- この分離により、「契約を壊したか」と「なぜそうなったか」を分けて扱えるようになった

---

## 5. 全体所感

- 両モードとも、k6 summary ベースでは正常系チェックは通過している
- 読み取り系 API では性能差は小さい
- 書き込み系 API では gRPC がやや低レイテンシ
- 可観測性の観点では、gRPC は method 単位で追いやすく、REST は route 単位で把握しやすい
- 観測基盤の統合により、trace / logs / metrics / k6 / Keploy を横断して確認できる状態になった
- ただし Collector 経由の k6 メトリクスは一部 run で揺れがあり、比較値の正本としては k6 summary を使う方が妥当である
- Keploy についても、Grafana は失敗原因分析に有効だが、回帰判定の正本は workflow / report に置くのが妥当である

---

## 6. 現時点の暫定結論

- 性能面では、用途によって優位性が分かれる
  - 読み取り系: 差は小さい
  - 書き込み系: gRPC がやや有利
- 可観測性の面では、gRPC は span 名の明瞭さによりやや優位
- 観測基盤統合そのものは成立しており、PoC の目的は達成できている
- 一方で、k6 メトリクスの Collector 経由集計は一部 run で不安定さがあるため、比較の正式値は k6 summary を採用する
- Keploy については、通常 CI による契約回帰確認に加え、Grafana 上で実行ログと request count を観測できる補助導線まで整備できた
- 現段階では、内部サービス間通信としての gRPC には前向きな材料が揃いつつあるが、安定性確認のため複数回実行を継続したい

---

## 7. Next Action

- k6 benchmark を users / orders それぞれ複数回実行し、artifact ベースで比較表を拡充する
- `GET /actuator/prometheus` を除外した request count クエリを dashboard に追加し、API 本体の挙動を見やすくする
- Keploy dashboard に run label や workflow run 単位の絞り込みを追加できるか検討する
- エラー系 trace を取得し、REST / gRPC の見え方を比較する
- warm 状態での再計測を行い、外れ値の再現性を確認する
