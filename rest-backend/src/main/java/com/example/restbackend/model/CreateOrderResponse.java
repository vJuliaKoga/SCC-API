package com.example.restbackend.model;

/*
    注文作成レスポンス
*/
public record CreateOrderResponse(
    String orderId,
    String result,
    String message
) {
}