package com.example.bff.controller;

import com.example.bff.model.CreateOrderRequest;
import com.example.bff.model.CreateOrderResponse;
import com.example.bff.service.BffService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/*
    注文作成用コントローラ
*/
@RestController
public class OrderController {

    private final BffService bffService;

    public OrderController(BffService bffService) {
        this.bffService = bffService;
    }

    @PostMapping("/api/orders")
    @ResponseStatus(HttpStatus.CREATED)
    public CreateOrderResponse createOrder(@RequestBody CreateOrderRequest request) {
        return bffService.createOrder(request);
    }
}