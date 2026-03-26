# REST vs gRPC 比較サマリー（単体実行版）

## 1. 前提

本結果はローカル環境における単体実行ベースの比較である。

- 計測対象: BFF (`http://localhost:19090`)
- 比較方式:
    - REST: `app.call-mode=rest`
    - gRPC: `app.call-mode=grpc`
- API:
    - `GET /api/users/{id}`
    - `POST /api/orders`

※ 本結果は単回実行ベースのため、最終判断には CI 等での複数回実行による再確認が必要。

---

## 2. 性能比較（k6）

### 2.1 GET /api/users/{id}

- REST:
    - p95:
    - p99:
    - error rate:

- gRPC:
    - p95:
    - p99:
    - error rate:

- 所感:
    - 今回の単回結果では REST がわずかに低レイテンシ
    - ただし差は小さく、誤差の可能性あり

---

### 2.2 POST /api/orders

- REST:
    - p95:
    - p99:
    - error rate:

- gRPC:
    - p95:
    - p99:
    - error rate:

- 所感:
    - gRPC の方が p95 / p99 / max が低く、やや優位
    - 書き込み系 API では差が見えやすい傾向

---

## 3. 全体所感

- 両モードとも error rate は 0.00% で安定している
- 読み取り系 API では REST / gRPC の差は小さい
- 書き込み系 API では gRPC がやや低レイテンシ
- 今回の結果は単体実行のため、環境差・揺らぎの影響を含む可能性あり

---

## 4. 現時点の暫定結論

- 性能面では、用途によって優位性が分かれる
    - 読み取り系: 差は小さい
    - 書き込み系: gRPC がやや有利
- ただし決定的な差とは言えず、追加検証が必要

---

## 5. Next Action

- k6 を CI 上で定期実行
- 複数回実行による中央値比較
- OpenTelemetry による trace 分析
- REST / gRPC の内部処理時間の分解