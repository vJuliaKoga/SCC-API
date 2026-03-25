/*
    API ごとのしきい値を共通化する
    最初は PoC 用にやや緩めの値で開始し、実測に応じて後で調整する
*/
export const commonThresholds = {
    http_req_failed: ["rate<0.01"]
};

export const userApiThresholds = {
    ...commonThresholds,
    http_req_duration: ["p(95)<300", "p(99)<500"]
};

export const orderApiThresholds = {
    ...commonThresholds,
    http_req_duration: ["p(95)<500", "p(99)<800"]
};