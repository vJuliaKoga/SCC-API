import http from "k6/http";
import { check, sleep } from "k6";

/*
    最小の疎通・応答確認用シナリオ
    使い方:
    BASE_URL=http://localhost:19090 k6 run k6/smoke.js
*/
export const options = {
    vus: 1,
    duration: "30s",
    thresholds: {
        http_req_failed: ["rate<0.01"],
        http_req_duration: ["p(95)<1000"]
    }
};

const BASE_URL = __ENV.BASE_URL || "http://localhost:19090";

export default function () {
    const res = http.get(`${BASE_URL}/health`);

    check(res, {
        "ステータスが200である": (r) => r.status === 200
    });

    sleep(1);
}
