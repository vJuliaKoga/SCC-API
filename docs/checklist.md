# チェックリスト

## 現在地

- PoC 基盤構築: 完了
- REST / gRPC 疎通確認: 完了
- k6 による単回性能比較: 完了
- OpenTelemetry / Jaeger による trace 確認: 完了
- trace 結果のドキュメント化: 進行中
- Tusk Drift による record / replay: 未着手

## フェーズ別チェック

### 1. 基本疎通

- [x] Bruno で API を 2〜3 本叩ける
- [x] BFF 経由で REST backend を呼び出せる
- [x] BFF 経由で gRPC backend を呼び出せる

### 2. 性能比較

- [x] k6 で smoke テストを 1 本回せる
- [x] k6 で benchmark 結果を REST / gRPC で比較できる
- [ ] benchmark を複数回実行する
- [ ] 中央値ベースで比較する
- [ ] CI での定期実行方針を決める

### 3. 可観測性

- [x] BFF に OpenTelemetry Java Agent を導入する
- [x] rest-backend に OpenTelemetry Java Agent を導入する
- [x] grpc-backend に OpenTelemetry Java Agent を導入する
- [x] Jaeger を起動し、BFF の trace を確認する
- [x] BFF -> rest-backend の trace 連携を確認する
- [x] BFF -> grpc-backend の trace 連携を確認する
- [x] `GET /api/users/{id}` の trace を REST / gRPC で 10 件ずつ取得する
- [ ] `POST /api/orders` の trace を REST / gRPC で取得する
- [ ] エラー系の trace を REST / gRPC で比較する
- [ ] Collector 経由構成にするかを判断する

### 4. 回帰・差分確認

- [ ] Tusk Drift で record / replay を 1 ケース試す
- [ ] REST / gRPC の差分検出観点を整理する

### 5. ドキュメント整理

- [x] `docs/benchmark-results.md` を作成する
- [ ] `docs/trace-results.md` を作成する
- [ ] `docs/comparison-notes.md` に可観測性の結果を反映する
- [ ] `docs/comparison-summary.md` に暫定結論を反映する

## 確認 URL

- Jaeger: http://localhost:16686
- Prometheus: http://localhost:9090

## Next Action

1. `docs/trace-results.md` を作成する
2. `POST /api/orders` の trace を取得して比較する
3. エラー系の trace を取得して比較する
4. k6 を複数回実行し、中央値ベースで比較する