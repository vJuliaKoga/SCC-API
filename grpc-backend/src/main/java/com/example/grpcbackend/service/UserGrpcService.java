package com.example.grpcbackend.service;

import com.example.grpcbackend.proto.GetUserRequest;
import com.example.grpcbackend.proto.GetUserResponse;
import com.example.grpcbackend.proto.UserServiceGrpc;
import com.example.grpcbackend.proto.UserStatus;
import io.grpc.Status;
import io.grpc.stub.StreamObserver;
import org.springframework.stereotype.Service;

/*
    ユーザー取得用の gRPC サービス実装
*/
@Service
public class UserGrpcService extends UserServiceGrpc.UserServiceImplBase {

    @Override
    public void getUser(
            GetUserRequest request,
            StreamObserver<GetUserResponse> responseObserver) {
        String userId = request.getUserId();

        if (userId == null || userId.isBlank()) {
            responseObserver.onError(
                    Status.INVALID_ARGUMENT
                            .withDescription("ユーザーIDは必須です。")
                            .asRuntimeException());
            return;
        }

        if (!"1".equals(userId)) {
            responseObserver.onError(
                    Status.NOT_FOUND
                            .withDescription("指定したユーザーは存在しません。")
                            .asRuntimeException());
            return;
        }

        GetUserResponse response = GetUserResponse.newBuilder()
                .setUserId("1")
                .setName("Sam Ple")
                .setStatus(UserStatus.USER_STATUS_ACTIVE)
                .build();

        responseObserver.onNext(response);
        responseObserver.onCompleted();
    }
}
