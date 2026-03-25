import http from "k6/http";
import { check, sleep } from "k6";
import { getBaseUrl, getOrderPayload } from "../../lib/config.js";
import { orderApiThresholds } from "../../lib/thresholds.js";

/*
    POST /api/orders の比較用ベンチマーク
    作成系 API のため、正常終了率とレイテンシの両方を見る
*/
export const options = {
    stages: [
        { duration: "30s", target: 10 },
        { duration: "3m", target: 10 },
        { duration: "30s", target: 0 }
    ],
    thresholds: orderApiThresholds
};

export default function () {
    const baseUrl = getBaseUrl();
    const payload = getOrderPayload();

    const res = http.post(
        `${baseUrl}/api/orders`,
        JSON.stringify(payload),
        {
            headers: {
                "Content-Type": "application/json"
            },
            tags: {
                scenario: "benchmark-orders-post",
                api: "orders",
                method: "POST"
            }
        }
    );

    check(res, {
        "ステータスが201である": (r) => r.status === 201
    });

    sleep(1);
}