# SCC API PoC

## 概要

本リポジトリは、BFF-Backend 間の通信方式として REST と gRPC を比較するためのPJ実装です。

本PJの目的は、一律な優劣を決定することではなく、各システムにおける採用判断の材料を得ることです。

比較対象は以下の通りです。

- REST 形式
  - Spring Boot 想定
  - HTTP/1.1
  - JSON
- gRPC 形式
  - gRPC Java 想定
  - HTTP/2
  - バイナリ通信

## 検証方針

クライアントからの入口となる BFF は共通化し、BFF から Backend への内部通信のみを切り替えることで、通信方式以外の差分を最小化します。

- BFF は共通
- REST backend は Spring Boot ベース
- gRPC backend は gRPC Java ベース
- 業務ロジックは REST / gRPC で揃える
- レスポンス項目は可能な限り共通化する

## 構成

- `bff`
  - クライアント向け API
  - Backend 呼び分け
- `rest-backend`
  - REST API 実装
- `grpc-backend`
  - gRPC API 実装
- `observability`
  - Jaeger / Prometheus のローカル確認用構成
- `k6`
  - 負荷試験シナリオ
- `bruno`
  - 疎通確認用コレクション
- `docs`
  - API 仕様、比較メモ、PoC 文書

##PJの主な観点

- 性能比較
  - p50 / p95 / p99
  - CPU 使用率
  - メモリ使用量
  - ガベージコレクションの傾向
- 互換性
  - フィールド追加 / 削除
  - 型変更
  - enum 追加
  - v1 / v2 混在
- 障害時挙動
  - 再起動
  - 接続切断
  - 遅延
  - エラー伝播
  - リトライ挙動
- 可観測性
  - ログ可読性
  - トレース取得
  - 原因特定容易性
  - curl / CLI による再現性
- 運用・保守
  - 変更手順の明確性
  - CI での互換性検知
  - 将来的な拡張性
  - 運用スキル依存度

## 初期スコープ

PoC 初期フェーズでは、検証対象 API を最小限に絞ります。

- `GET /health`
- `GET /api/users/{id}`
- `POST /api/orders`

最初は DB を使わず、固定値またはインメモリで応答するダミー API とします。

## BFF の切り替え方針

BFF は同一の外部 API を公開し、内部で Backend 呼び出し方式を切り替えます。

例:

- `CALL_MODE=rest`
- `CALL_MODE=grpc`

これにより、Bruno / k6 のシナリオを共通化しやすくし、比較条件を揃えます。

## ツール方針

- 疎通確認
  - Bruno
- 性能比較
  - k6
- メトリクス
  - Prometheus
- 分散トレース
  - OpenTelemetry
  - Jaeger
- API 回帰テスト量産
  - Tusk Drift

## 初期の完成ライン

- BFF が起動する
- REST backend が起動する
- gRPC backend が起動する
- `GET /health` が通る
- `GET /api/users/1` が `CALL_MODE=rest` で返る
- `GET /api/users/1` が `CALL_MODE=grpc` で返る
- Jaeger で BFF→Backend の trace が確認できる
- k6 で BFF に対する最小シナリオが実行できる
