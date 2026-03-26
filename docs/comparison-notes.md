# REST / gRPC 比較メモ

## 目的

本メモは、PJ 実施中に REST と gRPC の差分を記録するための作業メモである。
最終的には差分分析結果レポートの元資料とする。

## 比較対象

- BFF → REST backend
- BFF → gRPC backend

BFF 自体は共通とし、Backend 通信方式のみを比較対象とする。

## 比較観点

### 1. 性能

確認項目:

- p50
- p95
- p99
- エラー率
- CPU 使用率
- メモリ使用量
- GC の傾向

メモ:

- REST:
    - users API は単回結果でわずかに低レイテンシ
    - orders API は gRPC よりやや高め
    - error rate は 0.00%

- gRPC:
    - users API は REST とほぼ同等
    - orders API は p95 / p99 / max が REST より低め
    - error rate は 0.00%

- 所感:
    - 今回の単回結果では、読み取り系は差が小さい
    - 書き込み系では gRPC がやや優位
    - `GET /api/users/{id}` では、k6 単回結果では REST がわずかに低レイテンシだった一方、trace 単回観測の中央値では gRPC がやや低かった
    - これは計測粒度の違いと外れ値の影響を含むため、数値を直接同列比較せず、複数回実行で再確認する
    - 詳細な数値は `docs/benchmark-results.md` および `docs/trace-results.md` を参照

### 2. 互換性

確認項目:

- フィールド追加
- フィールド削除
- 型変更
- enum 追加
- v1 / v2 混在時の扱い

メモ:

- REST:
    - 未検証
    - OpenAPI ベースの差分確認を後続検討
- gRPC:
    - 未検証
    - proto の後方互換ルール確認を後続検討
- 所感:
    - 現時点では未着手
    - 実運用観点では schema 変更時の検知方法を整理する必要がある

### 3. 障害時挙動

確認項目:

- Backend 再起動時
- 接続切断時
- 遅延注入時
- エラー伝播
- リトライ挙動

メモ:

- REST:
    - 未検証
- gRPC:
    - 未検証
- 所感:
    - 現時点では正常系中心の確認のみ実施
    - エラー系 trace を取得して比較する必要がある

### 4. 可観測性

確認項目:

- ログ可読性
- トレース取得の容易性
- 原因特定までの時間
- curl / CLI での再現性

メモ:

- REST:
    - OpenTelemetry Java Agent により BFF -> rest-backend の分散トレース連携を確認
    - 対象 API は `GET /api/users/{id}`
    - 取得 trace は 10 件、各 trace は 3 span
    - span 構造は以下の通り
        - `bff: GET /api/users/{id}`
        - `bff: GET`
        - `rest-backend: GET /api/users/{id}`
    - 正常系ステータスは全件 `200`
    - duration 中央値は以下
        - BFF server span: 11.44ms
        - BFF outbound span: 6.70ms
        - backend server span: 3.80ms

- gRPC:
    - OpenTelemetry Java Agent により BFF -> grpc-backend の分散トレース連携を確認
    - 対象 API は `GET /api/users/{id}`
    - 取得 trace は 10 件、各 trace は 3 span
    - span 構造は以下の通り
        - `bff: GET /api/users/{id}`
        - `bff: sccapi.grpcbackend.v1.UserService/GetUser`
        - `grpc-backend: sccapi.grpcbackend.v1.UserService/GetUser`
    - 正常系ステータスは全件 `status_code=0`
    - duration 中央値は以下
        - BFF server span: 9.36ms
        - BFF outbound span: 5.93ms
        - backend server span: 2.34ms
    - 大きめの外れ値が 1 件あり、最大 trace は以下
        - BFF server span: 1.717s
        - BFF outbound span: 1.270s
        - backend server span: 182ms

- 所感:
    - REST / gRPC ともに BFF -> backend の分散トレース連携は成立している
    - gRPC は service / method 名が span に出るため、Jaeger 上で操作単位の追跡がしやすい
    - REST は backend 側 route は読みやすいが、BFF 側 outbound span 名は `GET` のみで識別性がやや低い
    - 通常系中央値では gRPC がやや低レイテンシ
    - ただし gRPC に外れ値があるため、warm 状態での複数回比較が必要
    - 詳細は `docs/trace-results.md` および `observability/traces/` 配下の生 JSON を参照
    - 今回は `GET /api/users/{id}` の正常系のみを対象としており、次は `POST /api/orders` とエラー系 trace でも同様の比較を行う

### 5. 運用・保守

確認項目:

- 変更手順の明確性
- CI での互換性検知
- 将来的な拡張性
- チーム内の習熟しやすさ

メモ:

- REST:
    - HTTP ベースで手元再現しやすい
    - Bruno / curl での確認がしやすい
- gRPC:
    - proto / codegen を含むため変更手順はやや増える
    - 一方で interface が明示される利点がある
- 所感:
    - PoC 段階では REST のほうが手動確認はしやすい
    - 内部サービス間通信としては gRPC の一貫性とトレースの読みやすさに利点がある
    - 本観点は今後の変更検証や CI 導入も踏まえて再評価が必要

## 実施履歴

### 2026-03-26

- 実施内容:
    - OpenTelemetry Java Agent を BFF / rest-backend / grpc-backend に導入
    - Jaeger を起動し、REST / gRPC 両経路の trace を確認
    - `GET /api/users/{id}` について REST / gRPC で 10 trace ずつ取得して比較
- 対象 API:
    - `GET /api/users/{id}`
- 使用ツール:
    - OpenTelemetry Java Agent
    - Jaeger
    - PowerShell
- 結果概要:
    - REST / gRPC ともに BFF -> backend の分散トレース連携を確認
    - 通常系中央値では gRPC がやや低レイテンシ
    - gRPC は span 名が明瞭で追跡しやすい
- 気づき:
    - REST は backend 側 route は見やすいが、BFF outbound span 名が粗い
    - gRPC は外れ値が 1 件あり、安定性確認には追加観測が必要
    - ポート競合や PowerShell の環境変数設定など、ローカル実行では起動順とセッション管理が重要

## 最終まとめ欄

### REST が向いている条件

- 手動確認や HTTP レベルのデバッグを重視する場合
- Bruno / curl / ブラウザでの再現性を重視する場合
- API 利用者にとって URL / method ベースの理解しやすさを優先する場合

### gRPC が向いている条件

- 内部サービス間通信として method 単位の明確な interface を持ちたい場合
- Jaeger 上で service / method 単位に追跡したい場合
- 書き込み系や内部 RPC のレイテンシ最適化を重視する場合

### 今回の対象システムに対する暫定見解

- 現時点の PoC 範囲では、性能面の差は API 特性によって分かれる
- 可観測性の観点では、gRPC は span 名の分かりやすさでやや優位
- ただし gRPC には外れ値があり、最終判断には複数回実行とエラー系検証が必要