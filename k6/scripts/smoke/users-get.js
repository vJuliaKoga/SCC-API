import http from "k6/http";
import { check, sleep } from "k6";
import { getBaseUrl, getUserId } from "../../lib/config.js";
import { userApiThresholds } from "../../lib/thresholds.js";

/*
    GET /api/users/{id} の最小疎通確認用シナリオ
    失敗時に原因を切り分けやすいよう、ステータスとレスポンス本文を出力する
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

    if (res.status !== 200) {
        console.log(`[users-get] status=${res.status} body=${res.body}`);
    }

    let body = {};
    try {
        body = res.json();
    } catch (error) {
        body = {};
    }

    check(res, {
        "ステータスが200である": (r) => r.status === 200,
        "userId が返る": () => body.userId !== undefined && body.userId !== null && body.userId !== "",
        "name が返る": () => body.name !== undefined && body.name !== null && body.name !== "",
        "status が返る": () => body.status !== undefined && body.status !== null && body.status !== ""
    });

    sleep(1);
}