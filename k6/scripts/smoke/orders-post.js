import http from "k6/http";
import { check, sleep } from "k6";
import { getBaseUrl, getOrderPayload } from "../../lib/config.js";
import { orderApiThresholds } from "../../lib/thresholds.js";

/*
    POST /api/orders の最小疎通確認用シナリオ
    失敗時に原因を切り分けやすいよう、ステータスとレスポンス本文を出力する
*/
export const options = {
    vus: 1,
    duration: "30s",
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
                scenario: "smoke-orders-post",
                api: "orders",
                method: "POST"
            }
        }
    );

    if (res.status !== 201) {
        console.log(`[orders-post] status=${res.status} body=${res.body}`);
    }

    let body = {};
    try {
        body = res.json();
    } catch (error) {
        body = {};
    }

    check(res, {
        "ステータスが201である": (r) => r.status === 201,
        "orderId が返る": () => body.orderId !== undefined && body.orderId !== null && body.orderId !== "",
        "result が返る": () => body.result !== undefined && body.result !== null && body.result !== "",
        "message が返る": () => body.message !== undefined && body.message !== null && body.message !== ""
    });

    sleep(1);
}