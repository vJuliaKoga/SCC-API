# REST vs gRPC 比較サマリー（暫定版）

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

---

### 2.2 POST /api/orders

- REST:
    - gRPC よりやや高め
    - error rate は 0.00%

- gRPC:
    - p95 / p99 / max が REST より低め
    - error rate は 0.00%

- 所感:
    - 書き込み系 API では gRPC がやや優位
    - 差は見えているが、複数回比較での再確認が必要

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

### 3.4 可観測性の所感

- REST / gRPC ともに trace 自体は問題なくつながっている
- gRPC は service / method 名が span に現れるため、操作単位で追いやすい
- REST は backend 側 route は読みやすいが、BFF outbound span 名は `GET` のみで簡素
- 通常系中央値では gRPC がやや低レイテンシ
- ただし gRPC には外れ値があり、安定性は継続観測が必要

---

## 4. 全体所感

- 両モードとも error rate は 0.00% で安定している
- 読み取り系 API では性能差は小さい
- 書き込み系 API では gRPC がやや低レイテンシ
- 可観測性の観点では、gRPC は method 単位で追いやすく、REST は route 単位で把握しやすい
- `GET /api/users/{id}` では、k6 単回結果では REST がわずかに低レイテンシだった一方、trace 単回観測の中央値では gRPC がやや低かった
- この差は、計測粒度の違いと外れ値の影響を含むため、現時点では「読み取り系は差が小さい」と整理するのが妥当である
- 現時点では、性能は用途次第、可観測性は gRPC がやや優位という傾向が見えている

---

## 5. 現時点の暫定結論

- 性能面では、用途によって優位性が分かれる
    - 読み取り系: 差は小さい
    - 書き込み系: gRPC がやや有利
- 可観測性の面では、gRPC は span 名の明瞭さによりやや優位
- ただし gRPC には外れ値があり、最終判断には複数回実行と追加検証が必要
- 現段階では、内部サービス間通信としての gRPC には前向きな材料が揃いつつあるが、安定性確認のため warm 状態での継続観測を行いたい

## 暫定サマリ

REST / gRPC 比較のためのローカル検証基盤は完成した。BFF による backend 切替、OpenTelemetry による観測、Grafana / Prometheus / Tempo / Loki / OpenTelemetry Collector による可視化、および k6 による負荷試験の統合までを確認済みである。

また、orders-write シナリオ用の k6 スクリプトも修正し、k6 summary 上で正常系チェックが 100% 成功することを確認した。

一方で、k6 を OpenTelemetry Collector 経由で Prometheus に取り込んだ際、一部 run において checks 系メトリクスや condition ラベルの揺れが確認され、Grafana 上で error rate や check success rate を単純計算すると実行実態と一致しないケースがあった。

このため、比較の正式値としては k6 summary の値を採用し、Grafana は raw checks、trace、logs の確認用途に利用する方針とした。

今後は users-read / orders-write の各シナリオについて、REST / gRPC を各 3 回ずつ実行し、p95、req/sec、error rate を比較する。

---

## 6. Next Action

- `POST /api/orders` の trace を REST / gRPC で取得する
- エラー系 trace を取得し、見え方を比較する
- k6 を複数回実行し、中央値ベースで比較する
- warm 状態で `GET /api/users/{id}` の trace を再取得し、外れ値の再現性を確認する
- 必要に応じて Collector 経由構成へ拡張する
