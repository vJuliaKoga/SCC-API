# Keploy CI 改善メモ

## 概要

本メモは、2026-03-30 時点の SCC-API における Keploy CI PoC の問題点と、実施した改善内容を整理したものである。

対象は BFF -> REST backend / gRPC backend 比較 PoC であり、通常 CI の目的は以下とする。

- REST 基準で整備した Keploy HTTP テストケースを使って、gRPC 実装が BFF の外部 API 契約を壊していないかを確認する
- 必要に応じて、同じ基準資産で `app.call-mode=rest` / `app.call-mode=grpc` を直列比較できるようにする

## 今回の問題点

### 1. `keploy test` が `No test-sets found` で失敗していた

GitHub Actions 上では backend の起動自体は成功していたが、`keploy test` 実行時に以下で停止していた。

- `No test-sets found. Please record testcases using keploy record command`

この時点では BFF がまだ起動しておらず、backend 側の疎通ではなく、Keploy が test-set を読めていないことが本質的な問題だった。

### 2. `test-set-rest` が CI replay 用 asset として汚れていた

`bff/keploy/test-set-rest/tests/*.yaml` は HTTP test case として大きな問題はなかった一方、`bff/keploy/test-set-rest/mocks.yaml` には本来不要な記録が混入していた。

- `kind: Generic`
- Gradle daemon 通信
- BFF 起動ログ
- 想定外ポートの痕跡
- JSON parse error の記録

この状態では、`test-set-rest` を「REST 基準の CI 用正本」として扱いにくかった。

### 3. Keploy の `path` 指定が project root 前提とずれていた

Keploy 実行時に test asset の配置場所だけを見て `bff/keploy` を渡す構成では安定せず、Keploy が期待する project root と実際の指定がずれていた。

結果として、test-set の存在確認が手元のファイル配置と一致していても、CLI 実行時には test-set 未検出になる状況が起きていた。

### 4. 通常 CI の実行意図が workflow 上で十分に固定されていなかった

最初の段階では、gRPC 実装の回帰確認を成立させることを優先していたため、workflow と script は smoke 的な回避策を含む構成になっていた。

そのため、通常 CI の正本が `test-set-rest` であること、汚れた asset は明示的に失敗させること、という運用ルールを script 側で強く表現できていなかった。

## 実施した改善方法

### 1. Keploy HTTP テストケース YAML を CI 向けに安定化した

既存の Keploy YAML を別形式へ変換せず、そのまま最小変更で安定化した。

- `Request-Start-Time` を削除
- `header.Date` を noise 化
- 必要なケースで `header.Connection` / `header.Keep-Alive` を noise 化
- `POST /api/orders` 正常系では `body.orderId` を noise 化
- `name:` を読みやすい識別子へ整理

これにより、CI で毎回揺れる値だけを抑えつつ、契約比較に必要な本文やステータスは残した。

### 2. `test-set-rest/mocks.yaml` を clean 化した

`bff/keploy/test-set-rest/mocks.yaml` から、CI 用正本に不要な `Generic` 記録を除去し、HTTP mock だけの構成へ戻した。

実施後の `test-set-rest/mocks.yaml` は以下の状態になった。

- `kind: Http` のみで構成
- `kind: Generic` が存在しない
- Gradle 起動ログや daemon 通信が含まれない

これにより、`test-set-rest` を通常 CI の正本として再利用しやすくなった。

### 3. Keploy 実行 script を修正した

`.github/scripts/run-keploy-regression.sh` を見直し、Keploy の前提に合うように調整した。

- `--path` は `bff/keploy` ではなく project root の `bff` を渡すように修正
- `test-set-rest` の layout を事前チェック
- `mocks.yaml` に `kind: Generic` が混入していたら即失敗するように修正
- backend の起動待ちを health check / port check で確認
- Keploy 実行ログと backend ログを artifact として回収しやすいよう整理

この修正により、通常 CI の失敗が「test-set 未検出」ではなく、より意味のあるメッセージで見えるようになった。

### 4. GitHub Actions workflow を通常 CI 向けに整理した

`.github/workflows/keploy-regression.yml` を追加・改善し、Linux runner 上で Keploy を回せるようにした。

- `ubuntu-latest` 上で Java 21 をセットアップ
- Gradle キャッシュを有効化
- Keploy CLI をインストール
- BFF の Keploy 回帰確認を workflow から実行
- `rest-backend` / `grpc-backend` の変更でも workflow が走るように trigger を調整

### 5. `rest` / `grpc` を CI 内で直列実行できるようにした

workflow と script を拡張し、`app.call-mode=rest` と `app.call-mode=grpc` を同じ job 内で順番に実行できるようにした。

- 通常 CI は `rest -> grpc` の順で直列実行
- `workflow_dispatch` では `both` / `rest` / `grpc` を選択可能
- `BFF_CALL_MODE` に応じて起動する backend を切り替え
- ログ出力先を `artifacts/ci/keploy-regression/rest` と `artifacts/ci/keploy-regression/grpc` に分離

この構成は、Keploy の比較だけでなく、後続の k6 比較運用でも「同じ job の中で REST と gRPC を順に回す」考え方に寄せやすい。

## 改善後の状態

### 確認できたこと

- `test-set-rest` を使った Keploy 実行で 8 件すべて PASS
- BFF を `app.call-mode=grpc` で起動した通常 CI の回帰確認が成立
- `test-set-rest` を通常 CI の正本として扱う構成へ戻せた

### 現在の運用前提

- 通常 CI の基準資産は `bff/keploy/test-set-rest`
- 通常 CI では REST の再 record は行わない
- Keploy は `--mocking=false` で実行し、backend 実起動込みの回帰確認として扱う
- Bruno は手動確認、Keploy は契約回帰確認、k6 は性能比較、Grafana は観測確認という役割分担を維持する

## 注意点

### 1. この CI は純粋な mock replay ではない

`--mocking=false` を前提としているため、record 済み mock だけに閉じた replay ではなく、backend 実起動込みの回帰確認である。

### 2. `test-set-rest` に再び `Generic` が混入した場合は CI を止める

通常 CI の正本を守るため、`mocks.yaml` に `kind: Generic` が混入した場合は script が明示的に失敗する。

### 3. `test-set-grpc` は現時点で通常 CI の正本ではない

`test-set-grpc` は比較補助には使えるが、通常 CI の基準資産としては `test-set-rest` を優先する。

## 今後の候補

- `test-set-rest-ci-smoke` を補助 asset として残すか削除するかを決める
- workflow 上で `rest -> grpc` の両方を実際に通し、直列実行の安定性を確認する
- 必要に応じて runbook / comparison-notes 側へ今回の改善内容を要約反映する
