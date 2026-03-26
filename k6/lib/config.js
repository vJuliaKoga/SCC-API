/*
    k6 用の共通設定
    BFF を計測対象にするため、デフォルトの BASE_URL は 19090 を向ける

    注意:
    現在の backend 実装では userId は "1" のみ正常系として扱われるため、
    デフォルト値もそれに合わせる
*/
export function getBaseUrl() {
    return __ENV.BASE_URL || "http://localhost:19090";
}

export function getUserId() {
    return __ENV.USER_ID || "1";
}

export function getOrderPayload() {
    return {
        userId: __ENV.ORDER_USER_ID || "1",
        itemCode: __ENV.ITEM_CODE || "BOOK-001",
        quantity: Number(__ENV.QUANTITY || 1)
    };
}