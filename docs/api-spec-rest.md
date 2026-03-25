# REST API 仕様書

## 目的

本ドキュメントは、REST 形式の比較用ダミー API 仕様を定義するものです。
gRPC 版とできる限り同じ業務意味を持つように設計します。

## 共通方針

- 通信方式は HTTP/1.1 + JSON
- 認証はPJ初期では省略可能
- DB は使わず、固定値またはインメモリ応答とする
- レスポンス項目は gRPC 版と意味を揃える

---

## 1. ヘルスチェック

### エンドポイント

`GET /health`

### 説明

サービスの生存確認用 API。

### リクエスト

なし

### レスポンス例

```json
{
  "status": "UP",
  "service": "rest-backend"
}
```

### ステータスコード

- 200 OK

## 2. ユーザー取得

### エンドポイント

`GET /api/users/{id}`

### 説明

指定したユーザー ID の情報を返す。

### パスパラメータ

- id
  - 型: string
  - 必須
  - 例: 1

### レスポンス例

```JSON
{
    "userId": "1",
    "name": "Taro Yamada",
    "status": "ACTIVE"
}
```

### ステータスコード

- 200 OK
- 404 Not Found

### 404 レスポンス例

```json
{
  "code": "USER_NOT_FOUND",
  "message": "指定したユーザーは存在しません。"
}
```

# 3. 注文作成

### エンドポイント

`POST /api/orders`

### 説明

注文を新規作成する。

### リクエスト例

```json
{
  "userId": "1",
  "itemCode": "ITEM-001",
  "quantity": 2
}
```

### バリデーション

- userId: 必須
- itemCode: 必須
- quantity: 必須、1以上

### レスポンス例

```json
{
  "orderId": "ORD-0001",
  "result": "ACCEPTED",
  "message": "注文を受け付けました。"
}
```

### ステータスコード

- 201 Created
- 400 Bad Request

### 400 レスポンス例

```json
{
  "code": "VALIDATION_ERROR",
  "message": "入力値が不正です。"
}
```

### エラーレスポンス方針

本PJでは、REST 版のエラー表現は以下の共通形式とする。

```json
{
  "code": "ERROR_CODE",
  "message": "エラー内容"
}
```

### 比較観点上の注意

REST 版では以下を比較時の観点として扱う。

- curl / Bruno による再現のしやすさ
- JSON 可読性
- フィールド追加時の扱いやすさ
- バージョニングの整理しやすさ
- ログ確認時の読みやすさ
