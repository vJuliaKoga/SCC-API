package com.example.restbackend.service;

import com.example.restbackend.model.CreateOrderRequest;
import com.example.restbackend.model.CreateOrderResponse;
import org.springframework.stereotype.Service;

/*
    注文作成の業務ロジック
*/
@Service
public class OrderService {

    public CreateOrderResponse createOrder(CreateOrderRequest request) {
        if (request == null) {
            throw new IllegalArgumentException("リクエストは必須です。");
        }

        if (request.userId() == null || request.userId().isBlank()) {
            throw new IllegalArgumentException("ユーザーIDは必須です。");
        }

        if (request.itemCode() == null || request.itemCode().isBlank()) {
            throw new IllegalArgumentException("商品コードは必須です。");
        }

        if (request.quantity() < 1) {
            throw new IllegalArgumentException("数量は1以上で指定してください。");
        }

        return new CreateOrderResponse(
            "ORD-0001",
            "ACCEPTED",
            "注文を受け付けました。"
        );
    }
}