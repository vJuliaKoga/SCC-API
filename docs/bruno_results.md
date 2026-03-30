# Bruno 確認メモ雛形

## 0. 実施前提

- 実施日:
- 実施者:
- Bruno Collection:
  - `SCC-API`
- 対象 BFF:
  - `http://localhost:19090`
- 比較対象:
  - `app.call-mode=rest`
  - `app.call-mode=grpc`
- 比較対象 API:
  - `GET /api/users/{id}`
  - `POST /api/orders`

---

## 1. 実施ルール

- Bruno 側の request 定義は固定する
- 切り替えるのは BFF の `app.call-mode` のみとする
- REST / gRPC で同一 request を送る
- 確認結果は「確認できたこと」と「未確認事項」を分けて記録する
- 推測では埋めない

---

## 2. 事前確認

### 2-1. 起動状態

- REST backend:
  - [ ] 起動確認
- gRPC backend:
  - [ ] 起動確認
- BFF:
  - [ ] 起動確認
- Bruno:
  - [ ] 起動確認

### 2-2. Bruno 準備

- Collection:
  - [ ] `SCC-API`
- Request:
  - [ ] `GET users`
  - [ ] `POST order`

---

## 3. GET /api/users/{id}

### 3-1. request 定義

- Request 名:
  - `GET users`
- Method:
  - `GET`
- URL:
  - `http://localhost:19090/api/users/1`

### 3-2. REST モード実行結果

- ステータスコード:
  - `200 OK`
- レスポンス時間:
  - `9ms`
- レスポンスサイズ:
  - `49B`
- レスポンスボディ:

```json
{
  "userId": "1",
  "name": "Sam Ple",
  "status": "ACTIVE"
}
```

- 備考:
  - 正常応答を確認
  - 応答はかなり速く、手動確認では待ち時間はほぼ気にならない

### 3-3. gRPC モード実行結果

- ステータスコード:
  - `200 OK`

- レスポンス時間:
  - `480ms`

- レスポンスサイズ:
  - `53B`

- レスポンスボディ:

```json
{
  "userId": "1",
  "name": "Taro Yamada",
  "status": "ACTIVE"
}
```

- 備考:
  - 正常応答を確認
  - REST と比べると体感でも遅さを認識しやすい差がある

### 3-4. 差分整理

- ステータスコード差分:
  - 差分なし
  - REST / gRPC ともに `200 OK`

- レスポンスボディ差分:
  - `userId` は一致
  - `status` は一致
  - `name` が不一致
    - REST: `Sam Ple`
    - gRPC: `Taro Yamada`

- レスポンスサイズ差分:
  - REST: `49B`
  - gRPC: `53B`
  - name の値の違いに伴う差分の可能性が高い

- レスポンス時間差分:
  - REST: `9ms`
  - gRPC: `480ms`
  - 今回の単発結果では gRPC が大きく遅い

- 利用者視点の差分有無:
  - あり
  - 同じ `GET /api/users/1` に対して `name` が異なるため、外部 API としては同等結果に見えない

- 所感:
  - 正常系としては両方成功しているが、同一 request に対する返却データが一致していない点は重要
  - 今回の PoC 前提では、BFF の外部 API は共通で Backend 通信方式のみを比較する構成なので、利用者視点で返却値が変わるのは比較条件として好ましくない
  - まずは性能比較より先に、REST backend と gRPC backend で `userId=1` の返却データを揃える必要がある
  - 480ms は単発結果のため、この1回だけで性能傾向を断定しない方がよい
  - ただし Bruno による手動確認の段階で差分を発見できた点は有益

### 3-5. 確認できたこと

- Bruno で `GET /api/users/1` を REST / gRPC 両モードで実行できた
- 両モードとも HTTP ステータスは `200 OK` だった
- 同一 request に対して `name` の返却値が一致しなかった
- 今回の単発実行では、レスポンス時間に大きな差が見えた

### 3-6. 未確認事項

- `name` 不一致が固定データ差なのか、実装差なのか
- 他の userId でも同様の差が出るか
- gRPC 側 480ms が初回ウォームアップ影響なのか、継続的傾向なのか
- エラー時の見え方

## 4. POST /api/orders

### 4-1. request 定義

- Request 名:
  - `POST order`
- Method:
  - `POST`
- URL:
  - `http://localhost:19090/api/orders`
- Header:
  - `Content-Type: application/json`
- Body:

```json id="9ztgpk"
{
  "userId": "1",
  "itemCode": "ITEM-001",
  "quantity": 1
}
```

### 4-2. REST モード実行結果

- ステータスコード:
  - `201 Created`
- レスポンス時間:
  - `368ms`
- レスポンスサイズ:
  - `88B`
- レスポンスボディ:

```json
{
  "orderId": "ORD-0001",
  "result": "ACCEPTED",
  "message": "注文を受け付けました。"
}
```

- 備考:
  - 正常に作成成功を確認
  - 手動確認ではやや待ち時間はあるが、内容確認には支障なし

### 4-3. gRPC モード実行結果

- ステータスコード:
  - `201 Created`

- レスポンス時間:
  - `144ms`

- レスポンスサイズ:
  - `88B`

- レスポンスボディ:

```json id="yhm13v"
{
  "orderId": "ORD-0001",
  "result": "ACCEPTED",
  "message": "注文を受け付けました。"
}
```

- 備考:
  - 正常に作成成功を確認
  - 今回の単発結果では REST より速い

### 4-4. 差分整理

- ステータスコード差分:
  - 差分なし
  - REST / gRPC ともに `201 Created`

- レスポンスボディ差分:
  - 差分なし
  - `orderId`、`result`、`message` は一致

- レスポンスサイズ差分:
  - 差分なし
  - 両方 `88B`

- レスポンス時間差分:
  - REST: `368ms`
  - gRPC: `144ms`
  - 今回の単発実行では gRPC の方が速い

- 利用者視点の差分有無:
  - なし
  - 外部 API としては同一の結果に見える

- 所感:
  - `POST /api/orders` については、今回の Bruno 手動確認では REST / gRPC で返却内容が揃っている
  - 利用者視点では、通信方式切替による外部仕様差分は見えない
  - 単発の手動確認でも gRPC の方が速かったが、性能の正式比較は引き続き k6 summary を正本とするのが妥当
  - 手動確認用途としては、Bruno で十分に比較・再現しやすい

### 4-5. 確認できたこと

- Bruno で `POST /api/orders` を REST / gRPC 両モードで実行できた
- 両モードとも HTTP ステータスは `201 Created` だった
- レスポンスボディは一致した
- 今回の単発実行では gRPC の方が短い応答時間だった

### 4-6. 未確認事項

- 別 payload でも同様に一致するか
- バリデーションエラー時の見え方
- backend 停止時のエラー伝播
- 単発結果以外でも同じ傾向が続くか

## 5. エラー系確認

### 5-1. GET /api/users/{id}

### ケース: 存在しない ID (`/api/users/999`)

#### REST モード

- リクエスト:
  - `GET /api/users/999`
- ステータスコード:
  - `200 OK`
- レスポンス時間:
  - `14ms`
- レスポンスサイズ:
  - `41B`
- レスポンスボディ:

```json
{
  "userId": null,
  "name": null,
  "status": null
}
```

- 備考:
  - ユーザー未存在と分かるメッセージは返っていない
  - HTTP ステータスは成功系のため、利用者視点では正常応答に見える可能性がある

#### gRPC モード

- リクエスト:
  - `GET /api/users/999`

- ステータスコード:
  - `404 Not Found`

- レスポンス時間:
  - `21ms`

- レスポンスサイズ:
  - `86B`

- レスポンスボディ:

```json id="ef6l4g"
{
  "code": "USER_NOT_FOUND",
  "message": "指定したユーザーは存在しません。"
}
```

- 備考:
  - HTTP ステータスと本文の意味が一致している
  - 利用者が原因を理解しやすい

#### 差分整理

- ステータスコード差分:
  - あり
  - REST は `200 OK`
  - gRPC は `404 Not Found`

- レスポンスボディ差分:
  - あり
  - REST は全項目 `null`
  - gRPC は `code` と `message` を持つ明示的なエラー形式

- 利用者視点の差分有無:
  - あり
  - REST では「空データの正常応答」に見え、gRPC では「ユーザー未存在のエラー」に見える

- 所感:
  - 外部 API としては不整合が大きい
  - 利用者やテストコードは、REST 側では未存在を見落としやすい

### ケース: 不正な ID (`/api/users/abc`)

#### REST モード

- リクエスト:
  - `GET /api/users/abc`

- ステータスコード:
  - `200 OK`

- レスポンス時間:
  - `9ms`

- レスポンスサイズ:
  - `41B`

- レスポンスボディ:

```json id="alkp03"
{
  "userId": null,
  "name": null,
  "status": null
}
```

- 備考:
  - 不正な ID であっても、未存在ケースと同じ見え方になっている
  - 入力不正なのか、データ未存在なのかを区別できない

#### gRPC モード

- リクエスト:
  - `GET /api/users/abc`

- ステータスコード:
  - `404 Not Found`

- レスポンス時間:
  - `8ms`

- レスポンスサイズ:
  - `86B`

- レスポンスボディ:

```json id="i5v683"
{
  "code": "USER_NOT_FOUND",
  "message": "指定したユーザーは存在しません。"
}
```

- 備考:
  - REST よりは分かりやすいが、入力値不正と未存在が同じ扱いになっている可能性がある

#### 差分整理

- ステータスコード差分:
  - あり
  - REST は `200 OK`
  - gRPC は `404 Not Found`

- レスポンスボディ差分:
  - あり
  - REST は null 埋め応答
  - gRPC は `USER_NOT_FOUND`

- 利用者視点の差分有無:
  - あり

- 所感:
  - REST 側は入力不正を成功系として扱っており、エラー検知しづらい
  - gRPC 側は少なくとも HTTP エラーとして扱っているが、`abc` を未存在扱いしている点は別途確認余地がある

### 参考: パス不足 (`GET /api/users/`)

#### REST モード

- リクエスト:
  - `GET /api/users/`

- ステータスコード:
  - `404 Not Found`

- レスポンス時間:
  - `38ms`

- レスポンスサイズ:
  - `99B`

- レスポンスボディ:

```json id="gi7g7b"
{
  "timestamp": "2026-03-30T02:29:42.623+00:00",
  "status": 404,
  "error": "Not Found",
  "path": "/api/users/"
}
```

#### gRPC モード

- リクエスト:
  - `GET /api/users/`

- ステータスコード:
  - `404 Not Found`

- レスポンス時間:
  - `39ms`

- レスポンスサイズ:
  - `99B`

- レスポンスボディ:

```json id="jjtz1p"
{
  "timestamp": "2026-03-30T02:30:42.011+00:00",
  "status": 404,
  "error": "Not Found",
  "path": "/api/users/"
}
```

#### 差分整理

- ステータスコード差分:
  - 差分なし

- レスポンスボディ差分:
  - 差分なし

- 利用者視点の差分有無:
  - なし

- 所感:
  - ルーティング未一致レベルでは REST / gRPC 差分は見られない

### GET /api/users/{id} エラー系の全体所感

- REST 側は、存在しない ID や不正な ID に対しても `200 OK` を返し、本文は全項目 `null` だった
- gRPC 側は、同条件で `404 Not Found` と明示的なエラー本文を返した
- ルーティング未一致の `/api/users/` では REST / gRPC ともに同じ `404 Not Found` だった
- そのため、`GET /api/users/{id}` のエラー系差分は、ルーティングよりも業務ハンドリングの層で発生している可能性が高い
- 利用者視点では、REST は未存在や入力不正を見落としやすく、gRPC の方が原因を把握しやすい
- 一方で、`abc` が gRPC 側でも `USER_NOT_FOUND` 扱いになっているため、入力値バリデーションと未存在判定が分離されているかは未確認

### 確認できたこと

- `GET /api/users/999` では、REST は `200 OK` + null 応答、gRPC は `404 Not Found` + 明示的エラーだった
- `GET /api/users/abc` でも、REST は `200 OK` + null 応答、gRPC は `404 Not Found` + 明示的エラーだった
- `/api/users/` のようなパス不足では、REST / gRPC ともに同じ `404 Not Found` だった
- `GET /api/users/{id}` でも、エラー時の外部仕様は REST / gRPC で揃っていない

### 未確認事項

- REST 側で null 応答を返す設計意図
- gRPC 側で `abc` を `USER_NOT_FOUND` と扱う理由
- BFF で `GET /api/users/{id}` のエラー形式を統一できるか
- 他の userId パターンでも同様の傾向が続くか

### 5-2. POST /api/orders

### ケース: quantity=0

#### REST モード

- リクエストボディ:

```json
{
  "userId": "1",
  "itemCode": "ITEM-001",
  "quantity": 0
}
```

- ステータスコード:
  - `201 Created`

- レスポンス時間:
  - `24ms`

- レスポンスサイズ:
  - `89B`

- レスポンスボディ:

```json id="st2dn6"
{
  "orderId": null,
  "result": null,
  "message": "数量は1以上で指定してください。"
}
```

- 備考:
  - バリデーションエラー相当のメッセージだが HTTP ステータスは成功系になっている

#### gRPC モード

- リクエストボディ:

```json
{
  "userId": "1",
  "itemCode": "ITEM-001",
  "quantity": 0
}
```

- ステータスコード:
  - `400 Bad Request`

- レスポンス時間:
  - `14ms`

- レスポンスサイズ:
  - `86B`

- レスポンスボディ:

```json id="r7v9fr"
{
  "code": "VALIDATION_ERROR",
  "message": "数量は1以上で指定してください。"
}
```

- 備考:
  - HTTP ステータスと本文の意味が一致している

#### 差分整理

- ステータスコード差分:
  - あり
  - REST は `201 Created`
  - gRPC は `400 Bad Request`

- レスポンスボディ差分:
  - あり
  - REST は `orderId` / `result` を `null` で返しつつ `message` でエラーを表現
  - gRPC は `code=VALIDATION_ERROR` と `message` を返す

- 利用者視点の差分有無:
  - あり
  - 同じ不正入力でも、REST では成功に見え、gRPC では入力エラーに見える

- 所感:
  - 外部 API としては差分が大きい
  - 特に REST 側の `201 Created` は利用者やテスト観点で誤解を招きやすい

### ケース: quantity=-1

#### REST モード

- リクエストボディ:

```json
{
  "userId": "1",
  "itemCode": "ITEM-001",
  "quantity": -1
}
```

- ステータスコード:
  - `201 Created`

- レスポンス時間:
  - `11ms`

- レスポンスサイズ:
  - `89B`

- レスポンスボディ:

```json id="r6sjq3"
{
  "orderId": null,
  "result": null,
  "message": "数量は1以上で指定してください。"
}
```

#### gRPC モード

- リクエストボディ:

```json
{
  "userId": "1",
  "itemCode": "ITEM-001",
  "quantity": -1
}
```

- ステータスコード:
  - `400 Bad Request`

- レスポンス時間:
  - `16ms`

- レスポンスサイズ:
  - `86B`

- レスポンスボディ:

```json id="tr1amk"
{
  "code": "VALIDATION_ERROR",
  "message": "数量は1以上で指定してください。"
}
```

#### 差分整理

- ステータスコード差分:
  - あり
  - REST は `201 Created`
  - gRPC は `400 Bad Request`

- レスポンスボディ差分:
  - あり
  - REST は null を含む成功系に近い形
  - gRPC は明示的なバリデーションエラー形式

- 利用者視点の差分有無:
  - あり

- 所感:
  - `quantity=0` と同じ構図で、REST / gRPC の外部仕様が揃っていない

#### ケース: `itemCode` 欠落

#### REST モード

- リクエストボディ:

```json
{
  "userId": "1",
  "quantity": 1
}
```

- ステータスコード:
  - `201 Created`

- レスポンス時間:
  - `20ms`

- レスポンスサイズ:
  - `76B`

- レスポンスボディ:

```json id="wkc2rn"
{
  "orderId": null,
  "result": null,
  "message": "商品コードは必須です。"
}
```

#### gRPC モード

- リクエストボディ:

```json
{
  "userId": "1",
  "quantity": 1
}
```

- ステータスコード:
  - `500 Internal Server Error`

- レスポンス時間:
  - `44ms`

- レスポンスサイズ:
  - `111B`

- レスポンスボディ:

```json id="s6wzgx"
{
  "timestamp": "2026-03-30T02:18:20.324+00:00",
  "status": 500,
  "error": "Internal Server Error",
  "path": "/api/orders"
}
```

#### 差分整理

- ステータスコード差分:
  - あり
  - REST は `201 Created`
  - gRPC は `500 Internal Server Error`

- レスポンスボディ差分:
  - あり
  - REST は業務メッセージを返す
  - gRPC は汎用 500 エラーで、入力不備の理由が本文から分からない

- 利用者視点の差分有無:
  - あり
  - REST では入力ミスに見えるが、gRPC ではサーバ障害に見える

- 所感:
  - 外部 API としてかなり不整合
  - gRPC 側は BFF での例外変換または入力値マッピングに課題がある可能性が高い

#### ケース: `userId` 欠落

#### REST モード

- リクエストボディ:

```json
{
  "itemCode": "ITEM-001",
  "quantity": 1
}
```

- ステータスコード:
  - `201 Created`

- レスポンス時間:
  - `20ms`

- レスポンスサイズ:
  - `75B`

- レスポンスボディ:

```json id="vli96m"
{
  "orderId": null,
  "result": null,
  "message": "ユーザーIDは必須です。"
}
```

#### gRPC モード

- リクエストボディ:

```json
{
  "itemCode": "ITEM-001",
  "quantity": 1
}
```

- ステータスコード:
  - `500 Internal Server Error`

- レスポンス時間:
  - `7ms`

- レスポンスサイズ:
  - `111B`

- レスポンスボディ:

```json id="19d7tm"
{
  "timestamp": "2026-03-30T02:18:47.472+00:00",
  "status": 500,
  "error": "Internal Server Error",
  "path": "/api/orders"
}
```

#### 差分整理

- ステータスコード差分:
  - あり
  - REST は `201 Created`
  - gRPC は `500 Internal Server Error`

- レスポンスボディ差分:
  - あり
  - REST は必須項目不足を業務メッセージで返す
  - gRPC は汎用 500 エラー

- 利用者視点の差分有無:
  - あり

- 所感:
  - 必須項目不足という同種の入力不備に対して、REST と gRPC で見え方が大きく異なる
  - 利用者視点では同一 API として扱いにくい状態

### POST /api/ordersエラー系の全体所感

- `POST /api/orders` の正常系は REST / gRPC で揃っていた
- 一方、エラー系は REST / gRPC で外部仕様が大きく異なる
- REST 側は業務メッセージを返しているが、HTTP ステータスが常に `201 Created` のため、成功と失敗の判定がしづらい
- gRPC 側は `quantity` 系では `400 Bad Request` を返せているが、必須項目不足では `500 Internal Server Error` になっており、入力不備と内部障害の区別が利用者から見えにくい
- Bruno による手動確認の段階で、正常系よりもエラー系の方が REST / gRPC 差分を発見しやすいことが分かった

### 確認できたこと

- `POST /api/orders` のエラー系では、REST / gRPC の外部仕様差分が明確に存在する
- `quantity` の不正値では、gRPC は `400` を返すが、REST は `201` を返す
- 必須項目不足では、gRPC は `500` を返し、REST は `201` を返す
- 同一 API を利用者視点で見たとき、現状はエラー時の整合性が取れていない

### 未確認事項

- `GET /api/users/{id}` のエラー系
- gRPC 側 500 の原因となっている内部ログ・例外内容
- REST 側が `201 Created` を返す設計意図
- BFF 側でエラー形式を統一できるか

### 5-3. エラー系の差分整理

- `GET /api/users/{id}` では、REST は未存在や不正値でも `200 OK` と null 応答を返し、gRPC は `404 Not Found` と明示的なエラー本文を返した
- `POST /api/orders` では、正常系は揃っていたが、エラー系では REST は `201 Created` を返し、gRPC は `400 Bad Request` または `500 Internal Server Error` を返した
- そのため、エラー時の外部 API 仕様は REST / gRPC で整合していない
- 利用者視点では、REST は成功系ステータスで失敗を返すケースがあり、gRPC は入力不備の一部を 500 として返すケースがあるため、どちらも改善余地がある
- Bruno による手動確認では、正常系よりもエラー系の方が REST / gRPC 差分を見つけやすかった

### 5-4. 確認できたこと

- `GET /api/users/{id}` と `POST /api/orders` の両方で、エラー時の見え方に REST / gRPC 差分があることを確認できた
- `GET /api/users/{id}` では、REST は null 応答、gRPC は明示的エラー応答だった
- `POST /api/orders` では、REST は業務メッセージを返すが HTTP ステータスは成功系、gRPC は条件により `400` または `500` を返した
- ルーティング未一致のような Spring MVC レベルの 404 は REST / gRPC で同じ見え方だった
- 差分は主に BFF から backend 呼び出し後の業務エラー変換やレスポンス整形の層で発生している可能性が高い

### 5-5. 未確認事項

- `GET /api/users/{id}` の name 不一致が固定データ差なのか、意図した仕様差なのか
- `GET /api/users/abc` を gRPC 側で `USER_NOT_FOUND` 扱いにしている理由
- `POST /api/orders` で必須項目欠落時に gRPC 側が `500` になる原因
- REST 側でエラー時にも成功系ステータスを返す設計意図
- BFF で REST / gRPC のエラー形式と HTTP ステータスを統一できるか

## 6. 手動デバッグ観点メモ

### 6-1. Bruno で確認しやすかった点

- BFF の URL を固定したまま、`app.call-mode` の切替だけで REST / gRPC の比較ができた
- ステータスコード、レスポンス時間、レスポンスサイズ、レスポンスボディをその場で確認できた
- 正常系とエラー系を同じ request からすぐに試せた
- エラー時の外部 API 差分を手動で発見しやすかった

### 6-2. Bruno で確認しづらかった点

- 単発実行では性能傾向を断定しづらい
- backend 側の内部例外原因までは Bruno だけでは分からない
- REST / gRPC のどの層で差分が出たかは、ログや trace を併用しないと断定しづらい

### 6-3. REST がやりやすいと感じた点

- HTTP レベルの見え方は単純で追いやすい
- 正常系ではレスポンス確認が分かりやすい
- ただし今回の結果では、エラー系で成功系ステータスを返しており、手動確認のしやすさを一部損ねている

### 6-4. gRPC 切替時でも利用者視点で差が出なかった点

- `POST /api/orders` の正常系は REST / gRPC で同じレスポンスを返した
- URL、HTTP method、request body は Bruno 側で共通のまま確認できた
- BFF により、少なくとも正常系の一部は backend 通信方式の差分を吸収できていた

### 6-5. 補足メモ

- Bruno は性能比較の正本取得ではなく、外部 API の見え方と手動再現性の確認に向いている
- 今回の PoC では、正常系だけを見ると差が小さい API もあるが、エラー系では差分が明確に出た
- comparison 系 docs へ転記する際は、正常系とエラー系を分けて整理した方が分かりやすい

## 7. 最後に比較用へ転記するための要点

### 7-1. GET /api/users/{id}

- 結論:
  - 現状、REST / gRPC で外部仕様が揃っていない
- 主要差分:
  - 正常系で `name` が不一致
  - エラー系で REST は `200 OK` + null 応答、gRPC は `404 Not Found` + 明示的エラー
- 利用者視点の差:
  - あり
  - 同一 API としては解釈しづらい
- 手動確認上の所感:
  - Bruno で差分を発見しやすかった
  - まずは返却データとエラー形式の整合を優先したい

### 7-2. POST /api/orders

- 結論:
  - 正常系は揃っているが、エラー系は揃っていない
- 主要差分:
  - 正常系は REST / gRPC で同じレスポンス
  - エラー系は REST が `201`、gRPC が `400` または `500`
- 利用者視点の差:
  - 正常系では差が小さい
  - エラー系では大きい
- 手動確認上の所感:
  - Bruno で payload を少し変えるだけで差分を再現できた
  - 利用者視点ではエラー時のステータス整合性が重要

### 7-3. 全体まとめ用メモ

- Bruno による再現性:
  - 高い
  - BFF の URL を固定したまま比較できた
- ステータスコード整合性:
  - 正常系の一部は揃うが、エラー系は揃っていない
- レスポンスボディ整合性:
  - `POST /api/orders` 正常系は揃っている
  - `GET /api/users/{id}` 正常系と各 API のエラー系は揃っていない
- エラー時の見え方:
  - REST / gRPC で差分が大きい
- REST が向くと感じた条件:
  - HTTP レベルの手動確認を素直に追いたい場合
  - ただし今回の実装ではエラー時ステータスの改善が必要
- gRPC が向くと感じた条件:
  - 正常系の内部通信を BFF 背後で吸収したい場合
  - エラーを明示的に扱える設計に寄せられる場合
- 未確認のまま残した事項:
  - `GET /api/users/1` の name 不一致の意図
  - gRPC 側 500 の原因
  - BFF でのエラー形式統一可否

## 8. 修正後の観測結果

### 8-1. GET /api/users/{id}

#### 正常系 (`GET /api/users/1`)

##### REST モード

- ステータスコード:
  - `200 OK`
- レスポンス時間:
  - `14ms`
- レスポンスサイズ:
  - `49B`
- レスポンスボディ:

```json
{
  "userId": "1",
  "name": "Sam Ple",
  "status": "ACTIVE"
}
```

##### gRPC モード

- ステータスコード:
  - `200 OK`

- レスポンス時間:
  - `34ms`

- レスポンスサイズ:
  - `49B`

- レスポンスボディ:

```json id="rd3pbc"
{
  "userId": "1",
  "name": "Sam Ple",
  "status": "ACTIVE"
}
```

##### 修正後の差分整理

- ステータスコード差分:
  - 差分なし

- レスポンスボディ差分:
  - 差分なし

- 利用者視点の差分有無:
  - なし

- 所感:
  - 初回確認で見つかった `name` 不一致は解消され、正常系の外部仕様を REST / gRPC で揃えられた

#### エラー系 (`GET /api/users/999`, `GET /api/users/abc`)

##### REST / gRPC 共通結果

- `GET /api/users/999`
  - `404 Not Found`
  - `{"code":"USER_NOT_FOUND","message":"指定したユーザーは存在しません。"}`

- `GET /api/users/abc`
  - `404 Not Found`
  - `{"code":"USER_NOT_FOUND","message":"指定したユーザーは存在しません。"}`

##### 修正後の差分整理

- ステータスコード差分:
  - 差分なし

- レスポンスボディ差分:
  - 差分なし

- 利用者視点の差分有無:
  - なし

- 所感:
  - 初回確認で見つかった `200 OK + null` と `404 + 明示的エラー` の差分は解消され、主要エラー系の外部仕様を REST / gRPC で揃えられた

---

### 8-2. POST /api/orders

#### 正常系 (`POST /api/orders`)

##### REST モード

- ステータスコード:
  - `201 Created`

- レスポンス時間:
  - `452ms`

- レスポンスサイズ:
  - `88B`

- レスポンスボディ:

```json id="wxuh24"
{
  "orderId": "ORD-0001",
  "result": "ACCEPTED",
  "message": "注文を受け付けました。"
}
```

##### gRPC モード

- ステータスコード:
  - `201 Created`

- レスポンス時間:
  - `466ms`

- レスポンスサイズ:
  - `88B`

- レスポンスボディ:

```json id="6n43ki"
{
  "orderId": "ORD-0001",
  "result": "ACCEPTED",
  "message": "注文を受け付けました。"
}
```

##### 修正後の差分整理

- ステータスコード差分:
  - 差分なし

- レスポンスボディ差分:
  - 差分なし

- 利用者視点の差分有無:
  - なし

- 所感:
  - 正常系は引き続き REST / gRPC で一致している

#### 主要バリデーションエラー系

確認したケース:

- `quantity=0`
- `quantity=-1`
- `itemCode` 欠落
- `userId` 欠落

##### REST / gRPC 共通結果

- すべて `400 Bad Request`
- エラー本文は `{"code":"VALIDATION_ERROR","message":"..."}` 形式
- 各ケースの message は以下で一致
  - `quantity=0` / `quantity=-1`
    - `数量は1以上で指定してください。`

  - `itemCode` 欠落
    - `商品コードは必須です。`

  - `userId` 欠落
    - `ユーザーIDは必須です。`

##### 修正後の差分整理

- ステータスコード差分:
  - 差分なし

- レスポンスボディ差分:
  - 差分なし

- 利用者視点の差分有無:
  - なし

- 所感:
  - 初回確認で見つかった `201 Created` や `500 Internal Server Error` の差分は解消され、主要入力エラー系の外部仕様を REST / gRPC で揃えられた

---

## 9. 修正後の全体所感

- `GET /api/users/{id}` と `POST /api/orders` の正常系について、REST / gRPC の外部仕様を揃えられた
- `GET /api/users/{id}` の主要エラー系と `POST /api/orders` の主要バリデーションエラー系についても、REST / gRPC の外部仕様を揃えられた
- 初回確認で見つかった差分は、Bruno を使うことで利用者視点の問題として把握しやすかった
- Bruno による手動確認は、性能比較の正本取得よりも、BFF の外部 API 整合性確認に有効だった
- 修正後は、比較対象 API の正常系および主要入力エラー系について、回帰確認や Tusk Drift の基準として扱いやすい状態になった

## 10. 修正後に確認できたこと

- `GET /api/users/1` は REST / gRPC ともに `200 OK` かつ同一レスポンス本文だった
- `GET /api/users/999` および `GET /api/users/abc` は REST / gRPC ともに `404 Not Found` + `USER_NOT_FOUND` のエラー本文だった
- `POST /api/orders` の正常系は REST / gRPC ともに `201 Created` + 同一レスポンス本文だった
- `POST /api/orders` の主要バリデーションエラー
  - `quantity=0`
  - `quantity=-1`
  - `itemCode` 欠落
  - `userId` 欠落
    は REST / gRPC ともに `400 Bad Request` + `VALIDATION_ERROR` のエラー本文だった

- 比較対象 API の正常系と主要入力エラー系について、REST / gRPC の外部仕様を揃えられた

## 11. 修正後の未確認事項

- backend 停止時や接続断時のエラー伝播
- 遅延注入時の見え方
- 主要ケース以外の境界値入力
- Bruno で揃えた外部仕様が Tusk Drift の record / replay でも安定して扱えるか
- 単発確認以外でもレスポンス時間傾向が継続するか
