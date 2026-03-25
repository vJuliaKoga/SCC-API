package com.example.bff.model;

/*
    注文作成リクエスト
*/
public record CreateOrderRequest(
    String userId,
    String itemCode,
    int quantity
) {
}