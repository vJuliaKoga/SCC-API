package com.example.bff.client.rest;

import com.example.bff.model.CreateOrderRequest;
import com.example.bff.model.CreateOrderResponse;
import com.example.bff.model.UserResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

/*
    REST backend 呼び出しをまとめるクライアント
*/
@Component
public class RestBackendClient {

    private final RestClient restClient;

    public RestBackendClient(RestClient restClient) {
        this.restClient = restClient;
    }

    public UserResponse getUser(String userId) {
        try {
            return restClient.get()
                .uri("/api/users/{id}", userId)
                .retrieve()
                .body(UserResponse.class);
        } catch (RestClientResponseException ex) {
            throw convertRestError(ex);
        }
    }

    public CreateOrderResponse createOrder(CreateOrderRequest request) {
        try {
            return restClient.post()
                .uri("/api/orders")
                .body(request)
                .retrieve()
                .body(CreateOrderResponse.class);
        } catch (RestClientResponseException ex) {
            throw convertRestError(ex);
        }
    }

    private RuntimeException convertRestError(RestClientResponseException ex) {
        String responseBody = ex.getResponseBodyAsString();

        if (ex.getStatusCode().value() == 400) {
            return new IllegalArgumentException(extractMessage(responseBody, "入力値が不正です。"));
        }

        if (ex.getStatusCode().value() == 404) {
            return new IllegalStateException(extractMessage(responseBody, "指定したユーザーは存在しません。"));
        }

        return new IllegalStateException("REST backend 呼び出しに失敗しました。");
    }

    /*
        最小 PoC のため簡易的にメッセージだけ取り出す
    */
    private String extractMessage(String body, String defaultMessage) {
        if (body == null || body.isBlank()) {
            return defaultMessage;
        }

        if (body.contains("message")) {
            int messageIndex = body.indexOf("message");
            int colonIndex = body.indexOf(':', messageIndex);
            int firstQuote = body.indexOf('"', colonIndex);
            int secondQuote = body.indexOf('"', firstQuote + 1);

            if (firstQuote >= 0 && secondQuote > firstQuote) {
                return body.substring(firstQuote + 1, secondQuote);
            }
        }

        return defaultMessage;
    }
}
