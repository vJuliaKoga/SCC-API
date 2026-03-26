# チェックリスト

## 目標

- Bruno で API を 2〜3 本叩ける
- Jaeger で trace を 1 本確認できる
- k6 で smoke テストを 1 本回せる
- k6 で benchmark 結果を REST / gRPC で比較できる
- Tusk Drift で record / replay を 1 ケース試せる

## 手順

1. observability を起動する
2. BFF の /health を Bruno で確認する
3. k6 で /health を叩く
4. BFF に OpenTelemetry を入れる
5. Jaeger UI で trace を確認する
6. Tusk Drift を 1 endpoint で試す

## 確認URL

- Jaeger: http://localhost:16686
- Prometheus: http://localhost:9090
