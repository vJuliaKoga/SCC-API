import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
    vus: 1,
    iterations: 10,
};

/*
    注文作成 API の確認用スクリプト

    失敗の主因は、API 仕様と送信 payload の項目名がずれていたこと。
    - 誤: itemId
    - 正: itemCode

    あわせて、既存の users-read.js に合わせて userId も "1" を使う。
*/
export default function () {
    const baseUrl = __ENV.BASE_URL || 'http://localhost:19090';

    const payload = JSON.stringify({
        userId: '1',
        itemCode: 'ITEM-001',
        quantity: 1,
    });

    const params = {
        headers: {
            'Content-Type': 'application/json',
        },
        tags: {
            endpoint: '/api/orders',
            api: 'orders-create',
        },
    };

    const response = http.post(`${baseUrl}/api/orders`, payload, params);

    /*
        レスポンス本文の JSON 解析に失敗しても、
        チェックやログ出力でスクリプトが落ちないようにする
    */
    let body = {};
    try {
        body = response.json();
    } catch (error) {
        body = {};
    }

    /*
        失敗時に原因をすぐ切り分けられるよう、
        ステータスと本文を出力しておく
    */
    if (response.status !== 201) {
        console.error(
            `注文作成 API 失敗: status=${response.status}, body=${response.body}`
        );
    }

    check(response, {
        '正常系ステータスである': (r) => r.status === 201,
        'status が 201': (r) => r.status === 201,
        'orderId が返る': () =>
            typeof body.orderId === 'string' && body.orderId.length > 0,
        'result が返る': () =>
            typeof body.result === 'string' && body.result.length > 0,
        'message が返る': () =>
            typeof body.message === 'string' && body.message.length > 0,
    });

    sleep(1);
}