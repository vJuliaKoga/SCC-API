import http from "k6/http";
import { check, sleep } from "k6";
import { getBaseUrl, getOrderPayload } from "../../lib/config.js";
import { orderApiThresholds } from "../../lib/thresholds.js";

/*
    POST /api/orders の最小疎通確認用シナリオ
    作成系 API のため、201 とレスポンス項目を確認する
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

    check(res, {
        "ステータスが201である": (r) => r.status === 201,
        "orderId が返る": (r) => {
            const body = r.json();
            return body.orderId !== undefined && body.orderId !== null && body.orderId !== "";
        },
        "result が返る": (r) => {
            const body = r.json();
            return body.result !== undefined && body.result !== null && body.result !== "";
        },
        "message が返る": (r) => {
            const body = r.json();
            return body.message !== undefined && body.message !== null && body.message !== "";
        }
    });

    sleep(1);
}