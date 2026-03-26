# observability

このディレクトリは、REST vs gRPC PoC の統合観測基盤を管理する。

## 役割

- Grafana: 画面
- Tempo: trace 保存先
- Loki: log 保存先
- Prometheus: metrics 保存先
- OpenTelemetry Collector: trace / metrics / logs の入口

## 起動

```powershell
cd observability
docker compose up -d
```

## 主な確認先
- Grafana: http://localhost:3000
- Prometheus: http://localhost:19093
- Tempo health: http://localhost:3200/ready
- Loki health: http://localhost:3100/ready
- Collector health: http://localhost:13133


## ログ連携の前提

Collector は ./logs/*.log を読む設定にしている。
後続で BFF / rest-backend / grpc-backend がこのディレクトリへログを書けば、Loki へ取り込める。

## メトリクス連携の前提
- Spring Boot アプリは /actuator/prometheus を Prometheus が scrape する
- 将来的に k6 は OpenTelemetry 出力で Collector へ送る
- Collector は受け取った OpenTelemetry metrics を :9464 で再公開し、Prometheus が scrape する