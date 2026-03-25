import http from "k6/http";
import { check, sleep } from "k6";
import { getBaseUrl, getUserId } from "../../lib/config.js";
import { userApiThresholds } from "../../lib/thresholds.js";

/*
    GET /api/users/{id} の比較用ベンチマーク
    REST / gRPC を同条件で比較するため、BFF のエンドポイントだけを叩く
*/
export const options = {
    stages: [
        { duration: "30s", target: 10 },
        { duration: "3m", target: 10 },
        { duration: "30s", target: 0 }
    ],
    thresholds: userApiThresholds
};

export default function () {
    const baseUrl = getBaseUrl();
    const userId = getUserId();

    const res = http.get(`${baseUrl}/api/users/${userId}`, {
        tags: {
            scenario: "benchmark-users-get",
            api: "users",
            method: "GET"
        }
    });

    check(res, {
        "ステータスが200である": (r) => r.status === 200
    });

    sleep(1);
}