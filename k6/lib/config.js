/*
    k6 用の共通設定
    BFF を計測対象にするため、デフォルトの BASE_URL は 19090 を向ける
*/
export function getBaseUrl() {
    return __ENV.BASE_URL || "http://localhost:19090";
}

export function getUserId() {
    return __ENV.USER_ID || "u001";
}

export function getOrderPayload() {
    return {
        userId: __ENV.ORDER_USER_ID || "u001",
        itemCode: __ENV.ITEM_CODE || "BOOK-001",
        quantity: Number(__ENV.QUANTITY || 1)
    };
}