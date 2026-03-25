# k6 実行メモ

## 前提

この PoC では、**BFF の外向け API を k6 で叩き、内部の `app.call-mode` を `rest` / `grpc` に切り替えて比較**。

計測対象:

- `GET /api/users/{id}`
- `POST /api/orders`

BFF:

- `http://localhost:19090`

---

## ディレクトリ前提

```text
k6/
├─ scripts/
│  ├─ smoke/
│  │  ├─ users-get.js
│  │  └─ orders-post.js
│  └─ benchmark/
│     ├─ users-get.js
│     └─ orders-post.js
├─ lib/
│  ├─ config.js
│  └─ thresholds.js
├─ results/
│  ├─ rest/
│  └─ grpc/
└─ run-examples.md
```

## 事前起動

### REST 比較時

起動しておくもの:

- rest-backend
- bff（app.call-mode=rest）

### gRPC 比較時

起動しておくもの:

- grpc-backend
- bff（app.call-mode=grpc）

## 最初にやる確認

まずは smoke から始めます。

### 確認順

1. backend 起動
2. BFF 起動
3. smoke 実行
4. benchmark 実行

いきなり benchmark から始めず、先に smoke で正常疎通を確認。

## smoke 実行例

### users API

```shell
k6 run k6/scripts/smoke/users-get.js
```

### orders API

```shell
k6 run k6/scripts/smoke/orders-post.js
```

## benchmark 実行例

### users API

```shell
k6 run k6/scripts/benchmark/users-get.js
```

### orders API

```shell
k6 run k6/scripts/benchmark/orders-post.js
```

## BASE_URL を明示する場合

デフォルトでは http://localhost:19090 を利用。
変更したい場合は環境変数で上書きできる。

```shell
k6 run -e BASE_URL=http://localhost:19091 k6/scripts/smoke/users-get.js
```

## userId を変える場合

### GET /api/users/{id} の対象 ID を変えたい場合

```shell
k6 run -e USER_ID=u001 k6/scripts/smoke/users-get.js
```

## order payload を変える場合

POST /api/orders の payload は環境変数で上書きできる。

```shell
k6 run -e ORDER_USER_ID=u001 -e ITEM_CODE=BOOK-001 -e QUANTITY=1 k6/scripts/smoke/orders-post.js
```

## 結果をファイル保存する例

REST: users benchmark

```shell
k6 run k6/scripts/benchmark/users-get.js > k6/results/rest/users-benchmark.txt
```

REST: orders benchmark

```shell
k6 run k6/scripts/benchmark/orders-post.js > k6/results/rest/orders-benchmark.txt
```

gRPC: users benchmark

```shell
k6 run k6/scripts/benchmark/users-get.js > k6/results/grpc/users-benchmark.txt
```

gRPC: orders benchmark

```shell
k6 run k6/scripts/benchmark/orders-post.js > k6/results/grpc/orders-benchmark.txt
```

## 実施のおすすめ順序

1. REST モード

- rest-backend 起動
- bff を call-mode=rest で起動
- users-get smoke
- orders-post smoke
- users-get benchmark
- orders-post benchmark

2. gRPC モード

- grpc-backend 起動
- bff を call-mode=grpc で起動
- users-get smoke
- orders-post smoke
- users-get benchmark
- orders-post benchmark

## 比較時の注意点

比較を成立させるため、以下は揃える。

- 同じ BFF エンドポイントを叩く
- 同じ payload を使う
- 同じ k6 スクリプトを使う
- 同じマシン条件で実行する
- 変更するのは call-mode だけにする

## 最初に見る指標

k6 実行結果では、まず以下を見る。

- http_req_duration
- http_req_failed
- p(95)
- p(99)
- iteration_duration

### 最低限の値

- p50
- p95
- p99
- error rate
