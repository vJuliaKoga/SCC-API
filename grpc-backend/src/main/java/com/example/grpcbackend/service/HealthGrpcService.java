package com.example.grpcbackend.service;

import com.example.grpcbackend.proto.HealthCheckRequest;
import com.example.grpcbackend.proto.HealthCheckResponse;
import com.example.grpcbackend.proto.HealthServiceGrpc;
import io.grpc.stub.StreamObserver;
import org.springframework.stereotype.Service;

/*
    ヘルスチェック用の gRPC サービス実装
*/
@Service
public class HealthGrpcService extends HealthServiceGrpc.HealthServiceImplBase {

    @Override
    public void checkHealth(
            HealthCheckRequest request,
            StreamObserver<HealthCheckResponse> responseObserver) {
        HealthCheckResponse response = HealthCheckResponse.newBuilder()
                .setStatus("UP")
                .setService("grpc-backend")
                .build();

        responseObserver.onNext(response);
        responseObserver.onCompleted();
    }
}