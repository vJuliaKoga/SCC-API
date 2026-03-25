import http from "k6/http";
import { check, sleep } from "k6";
import { getBaseUrl, getUserId } from "../../lib/config.js";
import { userApiThresholds } from "../../lib/thresholds.js";

/*
    GET /api/users/{id} の最小疎通確認用シナリオ
    まずは REST / gRPC 両モードで正常応答するかを見る
*/
export const options = {
    vus: 1,
    duration: "30s",
    thresholds: userApiThresholds
};

export default function () {
    const baseUrl = getBaseUrl();
    const userId = getUserId();

    const res = http.get(`${baseUrl}/api/users/${userId}`, {
        tags: {
            scenario: "smoke-users-get",
            api: "users",
            method: "GET"
        }
    });

    check(res, {
        "ステータスが200である": (r) => r.status === 200,
        "userId が返る": (r) => {
            const body = r.json();
            return body.userId !== undefined && body.userId !== null && body.userId !== "";
        },
        "name が返る": (r) => {
            const body = r.json();
            return body.name !== undefined && body.name !== null && body.name !== "";
        },
        "status が返る": (r) => {
            const body = r.json();
            return body.status !== undefined && body.status !== null && body.status !== "";
        }
    });

    sleep(1);
}