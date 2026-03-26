# k6 ベンチマーク結果

## 前提
- 計測対象: BFF (`http://localhost:19090`)
- 比較方式: `app.call-mode=rest` / `app.call-mode=grpc`
- API:
    - `GET /api/users/{id}`
    - `POST /api/orders`

---

## 1. 単回実行結果

### 1-1. GET /api/users/{id}

| Mode | avg | med | p90 | p95 | p99 | max | error rate | http_reqs | iterations | 備考 |
|------|-----|-----|-----|-----|-----|-----|------------|-----------|------------|------|
| REST | 2.74ms | 2.59ms | 3.87ms | 4.37ms | 5.29ms | 8.04ms | 0.00% | 2113 | 2113 | `rest/users-benchmark.txt` |
| gRPC | 2.91ms | 2.68ms | 4.16ms | 4.65ms | 6.28ms | 17.59ms | 0.00% | 2112 | 2112 | `grpc/users-benchmark.txt` |

### 1-2. POST /api/orders

| Mode | avg | med | p90 | p95 | p99 | max | error rate | http_reqs | iterations | 備考 |
|------|-----|-----|-----|-----|-----|-----|------------|-----------|------------|------|
| REST | 2.97ms | 2.89ms | 3.55ms | 3.78ms | 4.91ms | 37ms | 0.00% | 2112 | 2112 | `rest/orders-benchmark.txt` |
| gRPC | 2.33ms | 2.35ms | 2.84ms | 2.99ms | 3.44ms | 24.08ms | 0.00% | 2114 | 2114 | `grpc/orders-benchmark.txt` |

---

## 2. 所感

### GET /api/users/{id}
- 今回の結果では REST / gRPC ともに error rate は 0.00% だった。
- users API は p95 が REST 4.37ms、gRPC 4.65ms で、REST の方がわずかに低かった。
- p99、max、avg も REST の方が低く、今回の単回結果では REST の方が安定していた。
- users API は今回の単回結果では REST がわずかに低かったが、差は小さく誤差の可能性もある。

### POST /api/orders
- 今回の結果では REST / gRPC ともに error rate は 0.00% だった。
- orders API は p95 が REST 3.78ms、gRPC 2.99ms、p99 が REST 4.91ms、gRPC 3.44ms で、gRPC の方が低かった。
- max と avg も gRPC の方が低く、今回の単回結果では orders API は gRPC が優位だった。

---

## 3. 暫定まとめ
- users API: 今回の単回結果では REST の方が p95、p99、max、avg のいずれもわずかに低かった。
- orders API: 今回の単回結果では gRPC の方が p95、p99、max、avg のいずれも低かった。
- 全体所感: 両モードとも error rate は 0.00% で、API ごとに優位な方式が分かれる結果になった。
- 本結果は単回実行ベースのため、最終判断には複数回実行による再確認が必要。
