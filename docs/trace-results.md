# trace 結果

## 前提
- 計測対象: OpenTelemetry を有効にした BFF (`http://localhost:19090`) 経由の `GET /api/users/{id}` リクエスト
- 比較方式: `app.call-mode=rest` / `app.call-mode=grpc`
- 対象 API: `GET /api/users/{id}`
- 取得元ファイル: `observability/traces/2026-03-26/traces-1774504141541.json` / `observability/traces/2026-03-26/traces-1774504255472.json`
- 集計条件: BFF の server span が `GET /api/users/{id}` の trace のみを対象とし、JSON の `duration` を ms に換算して比較した

---

## 1. 単回観測結果

### 1-1. GET /api/users/{id}

| Mode | trace 件数 | 1 trace あたり span 数 | BFF -> backend 連携 | span 構造 | 正常系ステータス | エラー有無 |
|------|------------|------------------------|---------------------|-----------|------------------|------------|
| REST | 10 | 3 | 全 10 trace で同一 traceID を維持し、`bff server -> bff client -> rest-backend server` の親子関係を確認 | `bff: GET /api/users/{id}` -> `bff: GET` -> `rest-backend: GET /api/users/{id}` | 全 span で `http.response.status_code=200` | なし |
| gRPC | 10 | 3 | 全 10 trace で同一 traceID を維持し、`bff server -> bff client -> grpc-backend server` の親子関係を確認 | `bff: GET /api/users/{id}` -> `bff: sccapi.grpcbackend.v1.UserService/GetUser` -> `grpc-backend: sccapi.grpcbackend.v1.UserService/GetUser` | BFF server span は `http.response.status_code=200`、gRPC client / server span は全件 `rpc.grpc.status_code=0` | なし |

### 1-2. span duration 代表値

| Mode | BFF server avg | BFF server med | BFF server max | BFF outbound avg | BFF outbound med | BFF outbound max | backend server avg | backend server med | backend server max | 備考 |
|------|----------------|----------------|----------------|------------------|------------------|------------------|--------------------|--------------------|--------------------|------|
| REST | 22.99ms | 11.44ms | 132.07ms | 14.48ms | 6.70ms | 86.59ms | 8.40ms | 3.80ms | 50.59ms | 中央値は 3 区間とも 12ms 未満でまとまるが、132.07ms の高値 1 件で平均値が上振れした |
| gRPC | 180.82ms | 9.36ms | 1717.47ms | 132.98ms | 5.93ms | 1269.84ms | 20.83ms | 2.34ms | 182.05ms | 中央値は REST より低いが、1717.47ms の外れ値 1 件で平均値が大きく押し上がった |

### 1-3. 最大 trace

| Mode | traceID | BFF server | BFF outbound | backend server | 補足 |
|------|---------|------------|--------------|----------------|------|
| REST | `14d38cbdfe01fb931d021c5f32101083` | 132.07ms | 86.59ms | 50.59ms | 他 9 件の BFF server span は 7.45ms - 13.66ms に収まっていた |
| gRPC | `0974b23ada65d260a649341c60d23d9e` | 1717.47ms | 1269.84ms | 182.05ms | 他 9 件の BFF server span は 7.65ms - 14.75ms に収まっており、この 1 件だけ乖離が大きい |

---

## 2. 所感

### GET /api/users/{id}
- REST / gRPC ともに 10 trace すべてで 3 span 構成となっており、BFF の入口 span から backend の server span まで同一 traceID で連携していた。今回の取得範囲では、BFF -> backend の分散トレース伝搬は両方式で確認できた。
- REST の span 構造は HTTP リクエストとして素直に読める一方、BFF 側 outbound span 名は `GET` のみで、span 名だけでは呼び出し先 API を判別しづらい。backend 側は `GET /api/users/{id}` まで出るため、全体構造は追えるが BFF 側の識別力は高くない。
- gRPC は BFF 側 outbound span と backend 側 span のどちらも `sccapi.grpcbackend.v1.UserService/GetUser` が出るため、サービス境界とメソッド名を span 名だけで把握しやすい。trace のつながり方を確認する観点では、REST より gRPC の方が読みやすかった。
- 正常系ステータスの見え方は REST と gRPC で異なる。REST は全 span で `http.response.status_code=200` を確認できた一方、gRPC は BFF の入口 span が HTTP `200`、RPC 区間が `rpc.grpc.status_code=0` で正常終了を示していた。
- 中央値ベースでは gRPC が BFF server 9.36ms、BFF outbound 5.93ms、backend server 2.34ms と、REST の 11.44ms、6.70ms、3.80ms より各区間で低かった。単回観測の範囲では、gRPC がやや低レイテンシな傾向だった。
- 外れ値は gRPC で顕著で、1 trace が BFF server 1717.47ms、BFF outbound 1269.84ms まで伸びて平均値を大きく押し上げていた。REST にも 132.07ms の高値 1 件はあるが、中央値との乖離は gRPC ほど大きくないため、今回の比較は平均値より中央値を主に見るのが妥当と判断できる。
- 今回は `GET /api/users/{id}` の単回観測結果であるため、次は `POST /api/orders` とエラー系 trace でも同様の比較を行う。

---

## 3. 暫定まとめ
- `GET /api/users/{id}` の trace は REST / gRPC ともに 10 件取得でき、全件で 3 span 構成の BFF -> backend 連携を確認できた。
- span 名の見え方は gRPC の方が明確で、BFF 側 outbound / backend 側ともに RPC メソッド名がそのまま出るため、追跡しやすかった。
- duration は中央値ベースで gRPC が REST より低く、今回の単回観測では gRPC がやや低レイテンシだった。
- ただし gRPC には 1717.47ms の外れ値 1 件があり、平均値だけで評価すると実態を見誤るため、継続比較では中央値ベースの確認を優先したい。
