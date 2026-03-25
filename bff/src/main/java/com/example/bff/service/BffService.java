package com.example.bff.service;

import com.example.bff.client.grpc.GrpcBackendClient;
import com.example.bff.client.rest.RestBackendClient;
import com.example.bff.config.AppProperties;
import com.example.bff.model.CreateOrderRequest;
import com.example.bff.model.CreateOrderResponse;
import com.example.bff.model.UserResponse;
import org.springframework.stereotype.Service;

/*
    設定に応じて REST / gRPC の呼び先を切り替える
*/
@Service
public class BffService {

    private final AppProperties appProperties;
    private final RestBackendClient restBackendClient;
    private final GrpcBackendClient grpcBackendClient;

    public BffService(
        AppProperties appProperties,
        RestBackendClient restBackendClient,
        GrpcBackendClient grpcBackendClient
    ) {
        this.appProperties = appProperties;
        this.restBackendClient = restBackendClient;
        this.grpcBackendClient = grpcBackendClient;
    }

    public UserResponse getUser(String userId) {
        if (isGrpcMode()) {
            return grpcBackendClient.getUser(userId);
        }

        return restBackendClient.getUser(userId);
    }

    public CreateOrderResponse createOrder(CreateOrderRequest request) {
        if (isGrpcMode()) {
            return grpcBackendClient.createOrder(request);
        }

        return restBackendClient.createOrder(request);
    }

    private boolean isGrpcMode() {
        return "grpc".equalsIgnoreCase(appProperties.getCallMode());
    }
}