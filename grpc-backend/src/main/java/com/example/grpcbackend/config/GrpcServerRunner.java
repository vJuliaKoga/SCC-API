package com.example.grpcbackend.config;

import com.example.grpcbackend.service.HealthGrpcService;
import com.example.grpcbackend.service.OrderGrpcService;
import com.example.grpcbackend.service.UserGrpcService;
import io.grpc.Server;
import io.grpc.ServerBuilder;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.IOException;

/*
    gRPC サーバを Spring Boot と一緒に起動するためのコンポーネント
*/
@Component
public class GrpcServerRunner {

    private final int port;
    private final HealthGrpcService healthGrpcService;
    private final UserGrpcService userGrpcService;
    private final OrderGrpcService orderGrpcService;
    private Server server;

    public GrpcServerRunner(
            @Value("${grpc.server.port}") int port,
            HealthGrpcService healthGrpcService,
            UserGrpcService userGrpcService,
            OrderGrpcService orderGrpcService) {
        this.port = port;
        this.healthGrpcService = healthGrpcService;
        this.userGrpcService = userGrpcService;
        this.orderGrpcService = orderGrpcService;
    }

    /*
     * アプリケーション起動後に gRPC サーバを開始する
     */
    @PostConstruct
    public void start() throws IOException {
        this.server = ServerBuilder
                .forPort(port)
                .addService(healthGrpcService)
                .addService(userGrpcService)
                .addService(orderGrpcService)
                .build()
                .start();

        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            if (server != null) {
                server.shutdown();
            }
        }));
    }

    /*
     * アプリケーション終了時に gRPC サーバを停止する
     */
    @PreDestroy
    public void stop() {
        if (server != null) {
            server.shutdown();
        }
    }
}