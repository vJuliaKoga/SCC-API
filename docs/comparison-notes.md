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

### 6. Bruno による手動確認

確認目的:

- BFF の `app.call-mode=rest` / `app.call-mode=grpc` 切替時に、利用者から見た外部 API の見え方に差が出るかを確認する
- 比較対象 API は `GET /api/users/{id}` と `POST /api/orders` とする
- Bruno 側の request 定義は固定し、BFF の起動モードのみ切り替える

確認方法:

- Bruno Collection `SCC-API` を作成し、以下 2 request を用意した
  - `GET users`
  - `POST order`
- 接続先は BFF の `http://localhost:19090` に固定した
- Bruno 側の URL / method / body は変えず、BFF の `app.call-mode` のみを `rest` / `grpc` で切り替えて比較した

確認結果:

#### 6.1 GET /api/users/{id}

正常系 (`GET /api/users/1`) では、REST / gRPC ともに `200 OK` を返した。
ただし、返却データの `name` が一致しなかった。

- REST:
  - `200 OK`
  - `{"userId":"1","name":"Sam Ple","status":"ACTIVE"}`
- gRPC:
  - `200 OK`
  - `{"userId":"1","name":"Taro Yamada","status":"ACTIVE"}`

このため、現時点では `GET /api/users/{id}` の正常系について、REST / gRPC の外部仕様は揃っていない。
Bruno による単発確認では、gRPC 側の応答時間が大きく見えたが、単発実行のため性能差としては断定しない。

エラー系では、存在しない ID (`/api/users/999`) および不正な ID (`/api/users/abc`) に対して、REST / gRPC で見え方が大きく異なった。

- REST:
  - `200 OK`
  - `{"userId":null,"name":null,"status":null}`
- gRPC:
  - `404 Not Found`
  - `{"code":"USER_NOT_FOUND","message":"指定したユーザーは存在しません。"}`
- 参考:
  - パス不足 (`/api/users/`) では REST / gRPC ともに `404 Not Found` だった

所感:

- `GET /api/users/{id}` は、正常系でも返却値差分があり、エラー系でも HTTP ステータスと本文形式が揃っていない
- 特に REST 側は、未存在や不正値でも `200 OK` と null 応答になるため、利用者視点では見落としやすい
- 一方で gRPC 側は、少なくとも HTTP エラーと明示的なメッセージを返しており、原因を把握しやすい
- ただし、`/api/users/abc` が gRPC 側でも `USER_NOT_FOUND` 扱いになっている理由は未確認である

#### 6.2 POST /api/orders

正常系 (`POST /api/orders`) では、REST / gRPC ともに `201 Created` を返し、レスポンスボディも一致した。

- REST:
  - `201 Created`
  - `{"orderId":"ORD-0001","result":"ACCEPTED","message":"注文を受け付けました。"}`
- gRPC:
  - `201 Created`
  - `{"orderId":"ORD-0001","result":"ACCEPTED","message":"注文を受け付けました。"}`
- Bruno の単発確認では、gRPC 側の方が短い応答時間だった

このため、`POST /api/orders` の正常系については、利用者視点では REST / gRPC の差は小さい。

一方、エラー系では REST / gRPC の見え方が大きく異なった。

確認したケース:

- `quantity=0`
- `quantity=-1`
- `itemCode` 欠落
- `userId` 欠落

確認結果の傾向:

- REST:
  - 業務メッセージを返す
  - ただし HTTP ステータスは `201 Created` のまま
- gRPC:
  - `quantity` 系は `400 Bad Request`
  - 必須項目欠落は `500 Internal Server Error`

所感:

- `POST /api/orders` は正常系では揃っているが、エラー系では外部仕様が揃っていない
- REST 側は、エラー内容自体は分かるが、成功系ステータスを返すため利用者やテストで誤解を招きやすい
- gRPC 側は、`quantity` 系では入力エラーとして扱えている一方、必須項目欠落では `500` になっており、入力不備と内部障害の区別が利用者から見えにくい
- Bruno による手動確認では、正常系よりもエラー系の方が REST / gRPC 差分を見つけやすかった

#### 6.3 Bruno 確認から得られた整理

確認できたこと:

- Bruno を使った手動疎通確認フローは成立した
- BFF の URL を固定したまま、`app.call-mode` 切替だけで REST / gRPC の比較ができた
- `POST /api/orders` の正常系は、利用者視点では REST / gRPC の差が小さい
- `GET /api/users/{id}` は、正常系でも返却値差分がある
- 両 API とも、エラー系では REST / gRPC の外部仕様差分が目立つ

未確認事項:

- `GET /api/users/1` の `name` 不一致が固定データ差なのか、意図した仕様差なのか
- `GET /api/users/abc` を gRPC 側で `USER_NOT_FOUND` 扱いにしている理由
- `POST /api/orders` の必須項目欠落で gRPC 側が `500` になる原因
- REST 側でエラー時にも成功系ステータスを返す設計意図
- BFF で REST / gRPC のエラー形式と HTTP ステータスを統一できるか

暫定的な扱い:

- Bruno は、性能比較の正本取得ではなく、外部 API の見え方と手動再現性の確認に向く
- 現時点では、`POST /api/orders` 正常系のように差が小さいケースもあるが、全体としてはエラー時の整合性に課題がある
- comparison 系 docs へ転記する際は、正常系とエラー系を分けて整理するのが適切である

### 6.4 修正優先順位メモ

Bruno による手動確認の結果、BFF の外部 API は一部正常系およびエラー系で REST / gRPC の見え方が揃っていないことを確認した。
comparison-notes には差分を発見した事実を保持しつつ、実装としては外部 API の整合性を優先して修正する。

優先順位は以下の通りとする。

#### 1. `GET /api/users/{id}` 正常系の返却値統一

最優先は、`GET /api/users/{id}` 正常系の返却値を REST / gRPC で揃えることである。

確認結果では、`GET /api/users/1` に対して以下の差分があった。

- REST:
  - `name = "Sam Ple"`
- gRPC:
  - `name = "Taro Yamada"`

BFF は外部 API を共通化し、Backend 通信方式のみを比較対象とする前提であるため、同一 request に対する返却値差分は優先的に解消する。
返却値は REST 側に合わせ、`name` は `Sam Ple` に統一する。

#### 2. `GET /api/users/{id}` エラー時の HTTP ステータスと本文形式の統一

次に、`GET /api/users/{id}` の未存在 / 不正入力時の外部仕様を揃える。

確認結果では、REST 側は `200 OK` と null 応答、gRPC 側は `404 Not Found` と明示的エラー応答を返していた。
この状態では、利用者視点で未存在や不正入力を見落としやすく、API 回帰テストの正解も定めにくい。

方針としては、少なくとも以下を固定したい。

- 未存在ユーザー:
  - エラー系 HTTP ステータスを返す
  - 本文は利用者が意味を理解できる形式にする
- 不正な ID:
  - 未存在と同一扱いにするか、入力不正として別扱いにするかを明確にする
  - どちらにせよ REST / gRPC で揃える

#### 3. `POST /api/orders` エラー時の HTTP ステータス統一

`POST /api/orders` の正常系は REST / gRPC で揃っているため、次はエラー系を揃える。

確認結果では、REST 側は業務メッセージを返しつつ `201 Created` を返していた。
一方 gRPC 側は、`quantity` 系で `400 Bad Request`、必須項目欠落で `500 Internal Server Error` となっていた。

このため、まず以下を揃える。

- バリデーションエラーは成功系ステータスにしない
- 必須項目欠落を `500` にしない
- 利用者が原因を理解できる本文を返す

#### 4. BFF のエラー変換ルールの固定

個別 API の修正に加え、BFF で REST backend / gRPC backend の差分をどのように吸収するかを明確にする。

特に以下を固定対象とする。

- HTTP ステータスの割り当て
- エラー本文の基本形式
- 未存在、入力不正、内部障害の切り分け

これにより、Backend 通信方式を切り替えても、利用者視点の外部 API が変わらない状態を目指す。

#### 5. Bruno 再確認後に Tusk Drift へ進む

今回確認した差分は、comparison-notes にはそのまま残す。
ただし、Tusk Drift による record / replay や API 回帰テストへ進む前には、外部 API の正解を一意に定められる状態にしておく方がよい。

そのため、実装修正後は以下の順で進める。

1. Bruno で正常系と主要エラー系を再確認する
2. REST / gRPC の外部仕様が揃ったことを確認する
3. その状態を正として Tusk Drift の record / replay に進む

#### 暫定結論

- 差分を発見した事実は comparison-notes に保持する
- 実装としては差分を修正する
- 修正後の揃った外部 API を、今後の回帰確認や Tusk Drift の基準にする

### 修正後

修正後の Bruno 再確認では、`GET /api/users/{id}` と `POST /api/orders` の正常系および主要エラー系について、REST / gRPC の外部仕様を揃えられた。

確認できたこと:

- `GET /api/users/1` は REST / gRPC ともに `200 OK` で、`name` を含むレスポンス本文が一致した
- `GET /api/users/999` および `GET /api/users/abc` は REST / gRPC ともに `404 Not Found` で、`USER_NOT_FOUND` のエラー本文に一致した
- `POST /api/orders` の正常系は REST / gRPC ともに `201 Created` で、レスポンス本文が一致した
- `POST /api/orders` の主要バリデーションエラー
  - `quantity=0`
  - `quantity=-1`
  - `itemCode` 欠落
  - `userId` 欠落
    について、REST / gRPC ともに `400 Bad Request` と `VALIDATION_ERROR` のエラー本文に一致した

所感:

- Bruno による再確認ベースでは、比較対象 API の正常系と主要入力エラー系について、BFF の外部 API を REST / gRPC で揃えられた
- これにより、Backend 通信方式の違いを利用者視点で意識しにくい状態へ近づけることができた
- 今後 Tusk Drift による record / replay や API 回帰確認へ進める前提として、外部 API の正解を一意に定めやすくなった

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

### 2026-03-30

### 2026-03-30

- 実施内容:
  - Bruno を導入し、Collection `SCC-API` を作成した
  - BFF (`http://localhost:19090`) に対する確認 request として `GET users` / `POST order` を作成した
  - BFF の `app.call-mode=rest` / `app.call-mode=grpc` を切り替え、Bruno 側の request 定義を固定したまま比較した
  - `GET /api/users/{id}` と `POST /api/orders` について、正常系および主要エラー系の見え方を確認した
  - Bruno 確認で見つかった外部仕様差分をもとに、REST / gRPC の返却値とエラー仕様の整合を進めた
  - 修正後、Bruno で再確認し、比較対象 API の正常系および主要バリデーションエラー系について外部仕様が揃ったことを確認した

- 対象 API:
  - `GET /api/users/{id}`
  - `POST /api/orders`

- 使用ツール:
  - Bruno
  - BFF
  - REST backend
  - gRPC backend

- 結果概要:
  - Bruno を用いた手動疎通確認フローが成立した
  - 初回確認では、`GET /api/users/{id}` の正常系で REST / gRPC 間の返却値差分、および両 API のエラー時の HTTP ステータス / レスポンス本文差分を確認した
  - 修正後の再確認では、`GET /api/users/{id}` の正常系は REST / gRPC ともに `200 OK` かつ `name = "Sam Ple"` に一致した
  - `GET /api/users/999` および `GET /api/users/abc` は REST / gRPC ともに `404 Not Found` + `USER_NOT_FOUND` のエラー本文に一致した
  - `POST /api/orders` の正常系は REST / gRPC ともに `201 Created` かつ同一レスポンス本文を確認した
  - `POST /api/orders` の主要バリデーションエラー
    - `quantity=0`
    - `quantity=-1`
    - `itemCode` 欠落
    - `userId` 欠落
      について、REST / gRPC ともに `400 Bad Request` + `VALIDATION_ERROR` のエラー本文に一致した

- 気づき:
  - Bruno は BFF の URL を固定したまま `app.call-mode` 切替だけで比較でき、手動確認の再現性が高い
  - 差分は正常系よりもエラー系で見つかりやすく、外部 API の整合性確認に有効だった
  - Bruno 確認で差分を先に見つけてから実装を揃える進め方は、BFF の外部 API を比較可能な状態に整える上で有効だった
  - 修正後は、比較対象 API の正常系と主要入力エラー系について外部 API の正解を一意に定めやすくなり、今後の Tusk Drift や回帰確認へ進めやすい状態になった

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
- Bruno による再確認では、`GET /api/users/{id}` と `POST /api/orders` の正常系および主要バリデーションエラーについて、REST / gRPC の外部仕様を揃えられた
- このため、BFF の外部 API は比較対象として扱いやすくなり、以後は性能・可観測性・回帰確認を中心に比較を進めやすい状態になった
