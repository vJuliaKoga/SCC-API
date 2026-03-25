package com.example.grpcbackend.service;

import com.example.grpcbackend.proto.CreateOrderRequest;
import com.example.grpcbackend.proto.CreateOrderResponse;
import com.example.grpcbackend.proto.OrderResult;
import com.example.grpcbackend.proto.OrderServiceGrpc;
import io.grpc.Status;
import io.grpc.stub.StreamObserver;
import org.springframework.stereotype.Service;

/*
    注文作成用の gRPC サービス実装
*/
@Service
public class OrderGrpcService extends OrderServiceGrpc.OrderServiceImplBase {

    @Override
    public void createOrder(
            CreateOrderRequest request,
            StreamObserver<CreateOrderResponse> responseObserver) {
        if (request.getUserId().isBlank()) {
            responseObserver.onError(
                    Status.INVALID_ARGUMENT
                            .withDescription("ユーザーIDは必須です。")
                            .asRuntimeException());
            return;
        }

        if (request.getItemCode().isBlank()) {
            responseObserver.onError(
                    Status.INVALID_ARGUMENT
                            .withDescription("商品コードは必須です。")
                            .asRuntimeException());
            return;
        }

        if (request.getQuantity() < 1) {
            responseObserver.onError(
                    Status.INVALID_ARGUMENT
                            .withDescription("数量は1以上で指定してください。")
                            .asRuntimeException());
            return;
        }

        CreateOrderResponse response = CreateOrderResponse.newBuilder()
                .setOrderId("ORD-0001")
                .setResult(OrderResult.ORDER_RESULT_ACCEPTED)
                .setMessage("注文を受け付けました。")
                .build();

        responseObserver.onNext(response);
        responseObserver.onCompleted();
    }
}