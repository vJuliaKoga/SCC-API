# gRPC API 仕様書

## 目的

本ドキュメントは、gRPC 形式の比較用ダミー API 仕様を定義するものです。
REST 版とできる限り同じ業務意味を持つように設計します。

## 共通方針

- 通信方式は HTTP/2 + Protocol Buffers
- 認証は PoC 初期では省略可能
- DB は使わず、固定値またはインメモリ応答とする
- メッセージ項目は REST 版と意味を揃える

---

## サービス一覧

- `HealthService`
- `UserService`
- `OrderService`

---

## 1. HealthService

### RPC

`CheckHealth`

### リクエスト

空メッセージ

### レスポンスイメージ

- `status`
- `service`

### レスポンス例イメージ

- `status = "UP"`
- `service = "grpc-backend"`

---

## 2. UserService

### RPC

`GetUser`

### リクエスト項目

- `user_id`
  - string
  - 必須

### レスポンス項目

- `user_id`
- `name`
- `status`

### レスポンス例イメージ

- `user_id = "1"`
- `name = "Taro Yamada"`
- `status = "ACTIVE"`

### エラー

- `NOT_FOUND`
  - 指定したユーザーが存在しない場合

---

## 3. OrderService

### RPC

`CreateOrder`

### リクエスト項目

- `user_id`
- `item_code`
- `quantity`

### バリデーション

- `user_id`: 必須
- `item_code`: 必須
- `quantity`: 1以上

### レスポンス項目

- `order_id`
- `result`
- `message`

### レスポンス例イメージ

- `order_id = "ORD-0001"`
- `result = "ACCEPTED"`
- `message = "注文を受け付けました。"`

### エラー

- `INVALID_ARGUMENT`
  - 入力値が不正な場合

---

## proto 設計方針

- REST と意味を揃える
- ただし命名は proto 慣例に合わせて snake_case を許容する
- enum の追加やフィールド追加を比較観点に含めるため、将来拡張を意識した番号採番を行う
- 予約済み field 番号 / field 名の扱いは比較メモに残す

---

## 比較観点上の注意

gRPC 版では以下を比較時の観点として扱う。

- スキーマの厳密さ
- 型安全性
- フィールド追加時の互換性
- バイナリ通信による性能傾向
- エラー表現の追跡しやすさ
- CLI / テストツールでの扱いやすさ
