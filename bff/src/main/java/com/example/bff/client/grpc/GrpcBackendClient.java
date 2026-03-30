package com.example.bff.client.grpc;

import com.example.bff.model.CreateOrderRequest;
import com.example.bff.model.CreateOrderResponse;
import com.example.bff.model.UserResponse;
import com.example.bff.proto.GetUserRequest;
import com.example.bff.proto.GetUserResponse;
import com.example.bff.proto.OrderServiceGrpc;
import com.example.bff.proto.UserServiceGrpc;
import io.grpc.Status;
import io.grpc.StatusRuntimeException;
import org.springframework.stereotype.Component;

/*
    gRPC backend 呼び出しをまとめるクライアント
*/
@Component
public class GrpcBackendClient {

    private final UserServiceGrpc.UserServiceBlockingStub userServiceBlockingStub;
    private final OrderServiceGrpc.OrderServiceBlockingStub orderServiceBlockingStub;

    public GrpcBackendClient(
        UserServiceGrpc.UserServiceBlockingStub userServiceBlockingStub,
        OrderServiceGrpc.OrderServiceBlockingStub orderServiceBlockingStub
    ) {
        this.userServiceBlockingStub = userServiceBlockingStub;
        this.orderServiceBlockingStub = orderServiceBlockingStub;
    }

    public UserResponse getUser(String userId) {
        try {
            GetUserResponse response = userServiceBlockingStub.getUser(
                GetUserRequest.newBuilder()
                    .setUserId(userId)
                    .build()
            );

            return new UserResponse(
                response.getUserId(),
                response.getName(),
                response.getStatus().name().replace("USER_STATUS_", "")
            );
        } catch (StatusRuntimeException ex) {
            throw convertGrpcError(ex);
        }
    }

    public CreateOrderResponse createOrder(CreateOrderRequest request) {
        validateCreateOrderRequest(request);

        try {
            com.example.bff.proto.CreateOrderResponse response = orderServiceBlockingStub.createOrder(
                com.example.bff.proto.CreateOrderRequest.newBuilder()
                    .setUserId(request.userId())
                    .setItemCode(request.itemCode())
                    .setQuantity(request.quantity())
                    .build()
            );

            return new CreateOrderResponse(
                response.getOrderId(),
                response.getResult().name().replace("ORDER_RESULT_", ""),
                response.getMessage()
            );
        } catch (StatusRuntimeException ex) {
            throw convertGrpcError(ex);
        }
    }

    private RuntimeException convertGrpcError(StatusRuntimeException ex) {
        Status.Code code = ex.getStatus().getCode();
        String description = ex.getStatus().getDescription();

        if (code == Status.Code.INVALID_ARGUMENT) {
            return new IllegalArgumentException(
                description == null || description.isBlank()
                    ? "入力値が不正です。"
                    : description
            );
        }

        if (code == Status.Code.NOT_FOUND) {
            return new IllegalStateException(
                description == null || description.isBlank()
                    ? "指定したユーザーは存在しません。"
                    : description
            );
        }

        return new IllegalStateException("gRPC backend 呼び出しに失敗しました。");
    }

    private void validateCreateOrderRequest(CreateOrderRequest request) {
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
    }
}
