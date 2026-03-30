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
  - `POST /api/orders` の k6 スクリプトを修正し、正常系チェックが通る状態にした
  - 修正後の k6 summary では `checks_succeeded=100%`、`checks_failed=0%` を確認
  - 複数 run のうち `local-20260326-orders-rest-03` では、Grafana 上の checks 集計値が実行結果と一致しない事象を確認
- gRPC:
  - `POST /api/orders` について REST と同一条件で比較可能な状態にした
  - gRPC 側も k6 summary ベースでは正常系 100% を確認
- 所感:
  - `POST /api/orders` の機能動作自体は REST / gRPC ともに確認済み
  - 一方で、Collector 経由で Prometheus に取り込んだ k6 メトリクスは run により揺れがあり、Grafana の rate 系集計をそのまま比較値として使うのは危険
  - そのため、性能比較の正式値は Grafana ではなく k6 summary を採用する方針に切り替えた
  - 比較対象の run は、異常系列が混在したものを除外して整理する

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
  - 既存の trace 確認に加え、k6 の実行結果を OpenTelemetry Collector 経由で Grafana / Prometheus に取り込める状態にした
  - `k6_checks_total` は raw 表示で確認可能
  - `local-20260326-orders-rest-03` では `condition="zero"` と `condition="nonzero"` の混在を確認
- gRPC:
  - gRPC 側も同様に k6 のタグ付きメトリクス送信を確認
  - run_id / api / call_mode 単位で raw checks を確認可能
- 所感:
  - アプリケーション側の trace / logs / metrics の可視化は成立している
  - 一方で、k6 メトリクスは Collector 経由のラベル整合性に揺れがあり、Grafana 側で error rate や check success rate を単純算出すると実行結果と一致しない場合がある
  - このため、Grafana は観測確認用途に寄せ、比較値の正本は k6 summary とするのが妥当
  - 現時点で Grafana 上で安定確認できたクエリは以下の raw checks である

```promql
sum by (check, condition, run_id, api, call_mode, scenario) (
    last_over_time(
        k6_checks_total[1h]
    )
)
```

### 5. 運用・保守

確認項目:

- 変更手順の明確性
- CI での互換性検知
- 将来的な拡張性
- チーム内の習熟しやすさ

メモ:

- REST:
  - POST /api/orders の k6 スクリプト修正により、検証用シナリオを安定実行できるようになった
  - ただし比較に使う run 管理は厳密に行う必要がある

- gRPC:
  - gRPC 側も同一 runbook で比較可能
  - Collector 経由の可視化は補助用途として扱うのが安全

- 所感:
  - run_id の再利用は避け、毎回ユニークな値を付与する運用が必須
  - 比較値は k6 summary、Grafana は raw checks / trace / logs 確認用という役割分担にすると運用が安定する
  - PJ 段階では「完全なダッシュボード化」よりも「再現可能な実行手順と比較ルールの固定化」の優先度が高い

## 実施履歴

### 2026-03-26

- 実施内容:
  - OpenTelemetry Collector / Grafana / Prometheus / Tempo / Loki を用いたローカル観測基盤を整備
  - k6 を --out opentelemetry で Collector に送信し、Grafana 上で確認できる状態にした
  - k6/orders-create.js を修正し、POST /api/orders の正常系チェックを通過させた
  - Grafana 上で k6 の rate 系集計を検証し、run によって値が不安定になることを確認した
  - raw checks 表示に絞ったシンプルな確認パネルへ切り替えた

- 対象 API:
  - GET /api/users/{id}
  - POST /api/orders

- 使用ツール:
  - OpenTelemetry Java Agent
  - OpenTelemetry Collector
  - Grafana
  - Prometheus
  - Tempo
  - Loki
  - k6

- 結果概要:
  - REST / gRPC ともに API 呼び出し、trace、logs、metrics の可視化を確認
  - POST /api/orders は k6 summary 上で正常系 100% を確認
  - Grafana 上では raw checks は安定して確認可能

- 気づき:
  - Collector 経由の k6 メトリクスは、run により condition 系列やラベル整合性に揺れがある
  - 比較用の正式値は k6 summary を採用し、Grafana は観測確認用途に寄せる方が実務上安全
  - local-20260326-orders-rest-03 は異常 run 候補として除外して扱うのが妥当

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

- 現時点の PJ 範囲では、性能面の差は API 特性によって分かれる
- 可観測性の観点では、gRPC は span 名の分かりやすさでやや優位
- ただし gRPC には外れ値があり、最終判断には複数回実行とエラー系検証が必要
